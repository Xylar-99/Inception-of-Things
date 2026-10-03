#!/usr/bin/env bash
set -e
set -o pipefail

cd "$(dirname "$0")/.."
BONUS_DIR="$PWD"
CLUSTER_NAME="iot"
GITLAB_CHART_VERSION="10.4.1"
ARGOCD_VERSION="v3.5.3"
CHART_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/iot/gitlab-chart-$GITLAB_CHART_VERSION"

# Docker must already be installed and usable by the current user.
docker info > /dev/null
for tool in curl git openssl; do
    command -v "$tool" > /dev/null
done

if ! command -v kubectl > /dev/null 2>&1; then
    echo "Installing kubectl for Linux x86_64..."
    KUBECTL_VERSION=$(curl -fsSL https://dl.k8s.io/release/stable.txt)
    KUBECTL_BINARY=$(mktemp)
    curl -fsSL "https://dl.k8s.io/release/$KUBECTL_VERSION/bin/linux/amd64/kubectl" -o "$KUBECTL_BINARY"
    sudo install -m 0755 "$KUBECTL_BINARY" /usr/local/bin/kubectl
    rm "$KUBECTL_BINARY"
fi

if ! command -v k3d > /dev/null 2>&1; then
    echo "Installing K3d..."
    curl -fsSL https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | bash
fi

if ! k3d cluster list --no-headers | awk '{print $1}' | grep -qx "$CLUSTER_NAME"; then
    echo "Creating cluster $CLUSTER_NAME..."
    # Native Linux Docker can reach the node IP directly, without binding host port 80.
    k3d cluster create "$CLUSTER_NAME"
fi

# Ensure all following commands, including the dependency helper, use iot.
k3d kubeconfig merge "$CLUSTER_NAME" --kubeconfig-switch-context
kubectl wait --for=condition=Ready nodes --all --timeout=180s
GITLAB_IP=$(kubectl get node "k3d-$CLUSTER_NAME-server-0" \
    -o jsonpath='{.status.addresses[?(@.type=="InternalIP")].address}')
kubectl get storageclass local-path

for namespace in dev argocd gitlab; do
    kubectl create namespace "$namespace" --dry-run=client -o yaml | kubectl apply -f -
done

echo "Installing Argo CD $ARGOCD_VERSION..."
kubectl apply -n argocd --server-side --force-conflicts \
    -f "https://raw.githubusercontent.com/argoproj/argo-cd/$ARGOCD_VERSION/manifests/install.yaml"
kubectl wait -n argocd --for=condition=Available deployment --all --timeout=600s
kubectl rollout status -n argocd statefulset/argocd-application-controller --timeout=600s

# The official GitLab helper needs Helm 4 for its Garage Helm plugin.
if ! command -v helm > /dev/null 2>&1 || ! helm version --short | grep -q '^v4\.'; then
    echo "Installing Helm 4..."
    curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-4 | bash
fi

helm repo add gitlab https://charts.gitlab.io/ --force-update
helm repo update gitlab

# Use the helper from the same released chart version we install below.
if [ ! -d "$CHART_DIR" ]; then
    mkdir -p "$(dirname "$CHART_DIR")"
    git clone --depth 1 --branch "v$GITLAB_CHART_VERSION" \
        https://gitlab.com/gitlab-org/charts/gitlab.git "$CHART_DIR"
fi

# The upstream development helper disables Garage persistence. Enable it
# before first boot so both S3 data and bucket credentials survive Pod restarts.
sed -i 's/--set persistence.enabled=false/--set persistence.enabled=true --set persistence.data.size=1Gi/' \
    "$CHART_DIR/scripts/ci/lib/garage.sh"

echo "Installing PostgreSQL, Valkey, and Garage..."
(
    cd "$CHART_DIR"
    # These are the dependency versions used by this chart's official CI.
    unset CI_PIPELINE_ID
    NAMESPACE=gitlab VALKEY_CHART_VERSION=0.12.0 CNPG_CHART_VERSION=0.29.0 \
        CNPG_POSTGRESQL_TAG=17 GARAGE_APP_VERSION=2.2.0 \
        bash scripts/dev_dependencies.sh setup
)
kubectl rollout status -n gitlab deployment/dev-valkey --timeout=300s

echo "Installing GitLab chart $GITLAB_CHART_VERSION..."
helm upgrade --install gitlab gitlab/gitlab \
    --version "$GITLAB_CHART_VERSION" \
    --namespace gitlab --timeout 20m --wait --wait-for-jobs \
    -f "$CHART_DIR/.values/dev-external.values.yaml" \
    -f "$BONUS_DIR/confs/gitlab-values.yaml"

kubectl get pods -n gitlab
kubectl get services -n gitlab
kubectl get ingress -n gitlab
kubectl get pvc -n gitlab

echo "Infrastructure is ready. Follow bonus/README.md to create root/IOT-test."
echo "Browser URL: http://gitlab.iot.local"
echo "Add this entry to /etc/hosts: $GITLAB_IP gitlab.iot.local"
echo "After pushing manifests to GitLab: kubectl apply -f $BONUS_DIR/confs/app.yaml"
