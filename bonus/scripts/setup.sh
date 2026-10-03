#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

# ==================================================
# Install required tools
# ==================================================

bash scripts/install.sh


# ==================================================
# Configuration
# ==================================================

CLUSTER="iot"
ARGOCD_VERSION="v3.5.3"
GITLAB_VERSION="10.4.1"

CHART_DIR="$HOME/.cache/iot/gitlab-$GITLAB_VERSION"

# ==================================================
# Local hostnames
# ==================================================

if ! grep -q "gitlab.iot.local" /etc/hosts; then
    echo "127.0.0.1 gitlab.iot.local" | sudo tee -a /etc/hosts
fi

if ! grep -q "argocd.iot.local" /etc/hosts; then
    echo "127.0.0.1 argocd.iot.local" | sudo tee -a /etc/hosts
fi


if ! grep -q "app.iot.local" /etc/hosts; then
    echo "127.0.0.1 app.iot.local" | sudo tee -a /etc/hosts
fi


# ==================================================
# Create k3d cluster
# ==================================================

if ! k3d cluster list | grep -q "$CLUSTER"; then
    k3d cluster create "$CLUSTER" \
        -p "80:80@loadbalancer"
fi

k3d kubeconfig merge "$CLUSTER" \
    --kubeconfig-switch-context

kubectl wait \
    --for=condition=Ready \
    nodes \
    --all \
    --timeout=180s


# ==================================================
# Create namespaces
# ==================================================

kubectl create namespace dev \
    --dry-run=client -o yaml | kubectl apply -f -

kubectl create namespace argocd \
    --dry-run=client -o yaml | kubectl apply -f -

kubectl create namespace gitlab \
    --dry-run=client -o yaml | kubectl apply -f -


# ==================================================
# Install Argo CD
# ==================================================

echo
echo "Installing Argo CD..."

kubectl apply \
    -n argocd \
    --server-side \
    --force-conflicts \
    -f "https://raw.githubusercontent.com/argoproj/argo-cd/$ARGOCD_VERSION/manifests/install.yaml"

kubectl wait \
    --for=condition=Available \
    deployment/argocd-server \
    -n argocd \
    --timeout=10m


# Allow HTTP behind Traefik
kubectl patch configmap argocd-cmd-params-cm \
    -n argocd \
    --type merge \
    -p '{"data":{"server.insecure":"true"}}'

kubectl rollout restart \
    deployment/argocd-server \
    -n argocd

kubectl rollout status \
    deployment/argocd-server \
    -n argocd \
    --timeout=5m


# Create Argo CD ingress
kubectl apply \
    -f confs/argocd-ingress.yaml

echo "Argo CD ready."


# ==================================================
# Add GitLab Helm repository
# ==================================================

helm repo add gitlab \
    https://charts.gitlab.io/ \
    --force-update


# ==================================================
# Download GitLab helper files
# ==================================================

if [ ! -d "$CHART_DIR" ]; then

    echo
    echo "Downloading GitLab helper files..."

    git clone \
        --depth 1 \
        --branch "v$GITLAB_VERSION" \
        https://gitlab.com/gitlab-org/charts/gitlab.git \
        "$CHART_DIR"

fi


# ==================================================
# Enable Garage persistent storage
# ==================================================

sed -i \
    's/--set persistence.enabled=false/--set persistence.enabled=true --set persistence.data.size=1Gi/' \
    "$CHART_DIR/scripts/ci/lib/garage.sh"


# ==================================================
# Install GitLab dependencies
#
# Valkey
# PostgreSQL
# Garage
# ==================================================

echo
echo "Installing GitLab dependencies..."

set +e

(
    cd "$CHART_DIR"

    NAMESPACE=gitlab \
    VALKEY_CHART_VERSION=0.12.0 \
    CNPG_CHART_VERSION=0.29.0 \
    CNPG_POSTGRESQL_TAG=17 \
    GARAGE_APP_VERSION=2.2.0 \
    bash scripts/dev_dependencies.sh setup
)

DEPENDENCY_STATUS=$?

set -e


# ==================================================
# Handle slow PostgreSQL startup
# ==================================================

if [ "$DEPENDENCY_STATUS" -ne 0 ]; then

    echo
    echo "Waiting for PostgreSQL..."

    kubectl wait \
        --for=condition=Ready \
        cluster/dev-cluster \
        -n gitlab \
        --timeout=15m

    echo "PostgreSQL ready."

    echo
    echo "Continuing GitLab dependency setup..."

    (
        cd "$CHART_DIR"

        NAMESPACE=gitlab \
        VALKEY_CHART_VERSION=0.12.0 \
        CNPG_CHART_VERSION=0.29.0 \
        CNPG_POSTGRESQL_TAG=17 \
        GARAGE_APP_VERSION=2.2.0 \
        bash scripts/dev_dependencies.sh setup
    )

fi


# ==================================================
# Verify Garage
# ==================================================

echo
echo "Checking Garage..."

kubectl get secret \
    dev-garage-gitlab-object-storage \
    -n gitlab \
    >/dev/null

kubectl get secret \
    dev-garage-gitlab-object-storage-s3cmd \
    -n gitlab \
    >/dev/null

echo "Garage ready."


# ==================================================
# Install GitLab
# ==================================================

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

# ==================================================
# Get passwords
# ==================================================

echo
echo "Getting login credentials..."


# Argo CD password
ARGOCD_PASSWORD=$(
    kubectl get secret \
        argocd-initial-admin-secret \
        -n argocd \
        -o jsonpath='{.data.password}' \
        | base64 -d
)


# GitLab root password
GITLAB_PASSWORD=$(
    kubectl get secret \
        gitlab-gitlab-initial-root-password \
        -n gitlab \
        -o jsonpath='{.data.password}' \
        | base64 -d
)


# ==================================================
# Results
# ==================================================

echo
echo "========================================"
echo "              SETUP READY"
echo "========================================"


echo
echo "Argo CD pods:"
kubectl get pods -n argocd


echo
echo "GitLab pods:"
kubectl get pods -n gitlab


echo
echo "Ingress:"
kubectl get ingress -A


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