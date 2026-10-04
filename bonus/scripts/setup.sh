#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

# Configuration

CLUSTER="iot-bonus"
ARGOCD_VERSION="v3.5.3"
GITLAB_VERSION="10.4.1"

CHART_DIR="$HOME/.cache/iot/gitlab-$GITLAB_VERSION"


# Install required tools

bash scripts/install.sh


# Local hostnames

grep -q "gitlab.iot.local" /etc/hosts ||
    echo "127.0.0.1 gitlab.iot.local" | sudo tee -a /etc/hosts

grep -q "argocd.iot.local" /etc/hosts ||
    echo "127.0.0.1 argocd.iot.local" | sudo tee -a /etc/hosts

grep -q "app.iot.local" /etc/hosts ||
    echo "127.0.0.1 app.iot.local" | sudo tee -a /etc/hosts


# Create fresh k3d cluster

echo
echo "Creating fresh k3d cluster..."


k3d cluster create "$CLUSTER"  -p "80:80@loadbalancer"

k3d kubeconfig merge "$CLUSTER" --kubeconfig-switch-context

kubectl wait --for=condition=Ready nodes --all --timeout=180s



# Create namespaces


kubectl create namespace dev
kubectl create namespace argocd
kubectl create namespace gitlab



# Install Argo CD


echo
echo "Installing Argo CD..."

kubectl apply \
    --server-side \
    -n argocd \
    -f "https://raw.githubusercontent.com/argoproj/argo-cd/$ARGOCD_VERSION/manifests/install.yaml"


kubectl wait --for=condition=Available deployment/argocd-server -n argocd --timeout=10m



# Configure Argo CD

# Allow Argo CD HTTP behind Traefik

kubectl patch configmap argocd-cmd-params-cm -n argocd --type merge -p '{"data":{"server.insecure":"true"}}'

kubectl rollout restart deployment/argocd-server -n argocd

kubectl rollout status deployment/argocd-server -n argocd --timeout=5m


# Argo CD application
kubectl apply -f confs/app.yaml

# Argo CD ingress
kubectl apply -f confs/argocd-ingress.yaml

echo "Argo CD ready."



# Prepare GitLab

helm repo add gitlab https://charts.gitlab.io/ --force-update


# Download GitLab chart source only once
if [ ! -d "$CHART_DIR" ]; then
    echo
    echo "Downloading GitLab helper files..."

    git clone \
        --depth 1 \
        --branch "v$GITLAB_VERSION" \
        https://gitlab.com/gitlab-org/charts/gitlab.git \
        "$CHART_DIR"
fi



# Enable Garage storage


sed -i \
    's/--set persistence.enabled=false/--set persistence.enabled=true --set persistence.data.size=1Gi/' \
    "$CHART_DIR/scripts/ci/lib/garage.sh"



install_gitlab_dependencies() 
{
    (
        cd "$CHART_DIR"

        NAMESPACE=gitlab \
        VALKEY_CHART_VERSION="0.12.0" \
        CNPG_CHART_VERSION="0.29.0" \
        CNPG_POSTGRESQL_TAG="17" \
        GARAGE_APP_VERSION="2.2.0" \
        bash scripts/dev_dependencies.sh setup
    )
}


# Install GitLab dependencies
echo
echo "Installing GitLab dependencies..."

if ! install_gitlab_dependencies; then
    echo "Waiting for PostgreSQL..."

    kubectl wait \
        --for=condition=Ready \
        cluster/dev-cluster \
        -n gitlab \
        --timeout=15m

    echo "Retrying GitLab dependencies..."

    install_gitlab_dependencies
fi


echo
echo "Checking Garage..."

kubectl get secret dev-garage-gitlab-object-storage \
    -n gitlab >/dev/null

kubectl get secret dev-garage-gitlab-object-storage-s3cmd \
    -n gitlab >/dev/null

echo "Garage ready."


# Install GitLab

echo
echo "Installing GitLab..."

helm upgrade --install gitlab \
    gitlab/gitlab \
    --version "$GITLAB_VERSION" \
    -n gitlab \
    --timeout 30m \
    --wait \
    --wait-for-jobs \
    -f "$CHART_DIR/.values/dev-external.values.yaml" \
    -f confs/gitlab-values.yaml



# Get credentials

ARGOCD_PASSWORD=$(
    kubectl get secret \
        argocd-initial-admin-secret \
        -n argocd \
        -o jsonpath='{.data.password}' |
        base64 -d
)

GITLAB_PASSWORD=$(
    kubectl get secret \
        gitlab-gitlab-initial-root-password \
        -n gitlab \
        -o jsonpath='{.data.password}' |
        base64 -d
)


# Results


echo
echo "========================================"
echo "                 GITLAB"
echo "========================================"
echo "URL:      http://gitlab.iot.local"
echo "Username: root"
echo "Password: $GITLAB_PASSWORD"


echo
echo "========================================"
echo "                ARGO CD"
echo "========================================"
echo "URL:      http://argocd.iot.local"
echo "Username: admin"
echo "Password: $ARGOCD_PASSWORD"


echo
echo "========================================"
echo "               ALL READY"
echo "========================================"
