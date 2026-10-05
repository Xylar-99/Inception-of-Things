#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

# ============================================================
# Configuration
# ============================================================

CLUSTER="iot-bonus"

ARGOCD_VERSION="v3.5.3"
GITLAB_VERSION="10.4.1"

CHART_DIR="$HOME/.cache/iot/gitlab-$GITLAB_VERSION"


# ============================================================
# Install required tools
# ============================================================

bash scripts/install.sh


# ============================================================
# Local hostnames
# ============================================================

grep -q "gitlab.iot.local" /etc/hosts ||
    echo "127.0.0.1 gitlab.iot.local" |
    sudo tee -a /etc/hosts >/dev/null

grep -q "argocd.iot.local" /etc/hosts ||
    echo "127.0.0.1 argocd.iot.local" |
    sudo tee -a /etc/hosts >/dev/null

grep -q "app.iot.local" /etc/hosts ||
    echo "127.0.0.1 app.iot.local" |
    sudo tee -a /etc/hosts >/dev/null


# ============================================================
# Create k3d cluster
# ============================================================

echo
echo "Creating k3d cluster..."

k3d cluster delete "$CLUSTER" 2>/dev/null || true

k3d cluster create "$CLUSTER" \
    -p "80:80@loadbalancer"

k3d kubeconfig merge "$CLUSTER" \
    --kubeconfig-switch-context

echo "Waiting for Kubernetes nodes..."

kubectl wait \
    --for=condition=Ready \
    nodes \
    --all \
    --timeout=180s


# ============================================================
# Namespaces
# ============================================================

kubectl create namespace dev
kubectl create namespace argocd
kubectl create namespace gitlab


# ============================================================
# Install Argo CD
# ============================================================

echo
echo "Installing Argo CD..."

kubectl apply \
    --server-side \
    -n argocd \
    -f "https://raw.githubusercontent.com/argoproj/argo-cd/$ARGOCD_VERSION/manifests/install.yaml"

echo "Waiting for Argo CD..."

kubectl wait \
    --for=condition=Available \
    deployment/argocd-server \
    -n argocd \
    --timeout=10m


# ============================================================
# Configure Argo CD HTTP
# ============================================================

kubectl patch \
    configmap argocd-cmd-params-cm \
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


# ============================================================
# Argo CD Application
# ============================================================

kubectl apply -f confs/app.yaml
kubectl apply -f confs/argocd-ingress.yaml

echo "Argo CD ready."


# ============================================================
# Prepare GitLab chart repository
# ============================================================

echo
echo "Preparing GitLab..."

helm repo add \
    gitlab \
    https://charts.gitlab.io/ \
    --force-update

helm repo update


# ============================================================
# Clone GitLab chart source
# ============================================================

mkdir -p "$(dirname "$CHART_DIR")"

if [ ! -d "$CHART_DIR/.git" ]; then

    echo
    echo "Downloading GitLab chart source..."

    rm -rf "$CHART_DIR"

    git clone \
        --depth 1 \
        --branch "v$GITLAB_VERSION" \
        https://gitlab.com/gitlab-org/charts/gitlab.git \
        "$CHART_DIR"

fi


# ============================================================
# Garage persistence
# ============================================================

GARAGE_SCRIPT="$CHART_DIR/scripts/ci/lib/garage.sh"

if ! grep -q "persistence.data.size=1Gi" "$GARAGE_SCRIPT"; then

    sed -i \
        's/--set persistence.enabled=false/--set persistence.enabled=true --set persistence.data.size=1Gi/' \
        "$GARAGE_SCRIPT"

fi


# ============================================================
# Clean broken Helm repository cache state
# ============================================================

echo
echo "Preparing dependency repositories..."

helm repo remove valkey 2>/dev/null || true
helm repo remove cnpg 2>/dev/null || true

helm repo add \
    valkey \
    https://valkey.io/valkey-helm/

helm repo add \
    cnpg \
    https://cloudnative-pg.github.io/charts

helm repo update


# ============================================================
# Install GitLab external dependencies
#
# Valkey
# CloudNativePG + PostgreSQL
# Garage
# ============================================================

echo
echo "Installing GitLab dependencies..."

(
    cd "$CHART_DIR"

    NAMESPACE=gitlab \
    GARAGE_APP_VERSION="2.2.0" \
    CNPG_POSTGRESQL_TAG="17" \
    bash scripts/dev_dependencies.sh setup
)


# ============================================================
# Wait for CloudNativePG CRD
# ============================================================

echo
echo "Waiting for CloudNativePG..."

until kubectl get crd clusters.postgresql.cnpg.io >/dev/null 2>&1; do
    sleep 2
done


# ============================================================
# Wait for PostgreSQL
# ============================================================

echo "Waiting for PostgreSQL..."

kubectl wait \
    --for=condition=Ready \
    cluster/dev-cluster \
    -n gitlab \
    --timeout=15m


# ============================================================
# Check Valkey
# ============================================================

echo
echo "Checking Valkey..."

kubectl wait \
    --for=condition=Available \
    deployment \
    -l app.kubernetes.io/name=valkey \
    -n gitlab \
    --timeout=10m


# ============================================================
# Check Garage secrets
# ============================================================

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

echo "GitLab dependencies ready."


# ============================================================
# Install GitLab
# ============================================================

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


# ============================================================
# Credentials
# ============================================================

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


# ============================================================
# Results
# ============================================================

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
echo "                  APP"
echo "========================================"
echo "URL:      http://app.iot.local"

echo
echo "========================================"
echo "               ALL READY"
echo "========================================"