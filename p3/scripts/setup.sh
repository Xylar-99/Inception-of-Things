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

CLUSTER_NAME="iot-p3"


# ==================================================
# Local hostname
# ==================================================

if ! grep -q "argocd.iot.local" /etc/hosts; then
    echo "127.0.0.1 argocd.iot.local" | sudo tee -a /etc/hosts

fi

if ! grep -q "app.iot.local" /etc/hosts; then
    echo "127.0.0.1 app.iot.local" | sudo tee -a /etc/hosts
fi



# ==================================================
# Create k3d cluster
# ==================================================

if ! k3d cluster list | grep -q "$CLUSTER_NAME"; then

    echo
    echo "Creating k3d cluster..."

    k3d cluster create "$CLUSTER_NAME" \
        -p "80:80@loadbalancer"

fi


# ==================================================
# Select cluster
# ==================================================

k3d kubeconfig merge "$CLUSTER_NAME" \
    --kubeconfig-switch-context


# ==================================================
# Wait for Kubernetes
# ==================================================

echo
echo "Waiting for Kubernetes..."

kubectl wait \
    --for=condition=Ready \
    nodes \
    --all \
    --timeout=120s


# ==================================================
# Create namespaces
# ==================================================

echo
echo "Creating namespaces..."

kubectl create namespace dev \
    --dry-run=client -o yaml \
    | kubectl apply -f -

kubectl create namespace argocd \
    --dry-run=client -o yaml \
    | kubectl apply -f -


# ==================================================
# Install Argo CD
# ==================================================

echo
echo "Installing Argo CD..."

kubectl apply \
    -n argocd \
    --server-side \
    --force-conflicts \
    -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml


# ==================================================
# Wait for Argo CD
# ==================================================

echo
echo "Waiting for Argo CD..."

kubectl wait \
    --for=condition=Available \
    deployment/argocd-server \
    -n argocd \
    --timeout=300s


# ==================================================
# Allow HTTP behind Traefik
# ==================================================

echo
echo "Configuring Argo CD..."

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
    --timeout=300s


# ==================================================
# Argo CD Ingress
# ==================================================

echo
echo "Creating Argo CD ingress..."

kubectl apply -f confs/argocd-ingress.yaml


# ==================================================
# Create Argo CD Application
# ==================================================

echo
echo "Creating application..."

kubectl apply -f confs/app.yaml


# ==================================================
# Wait for application Service
# ==================================================

echo
echo "Waiting for playground service..."

until kubectl get service playground \
    -n dev >/dev/null 2>&1
do
    sleep 2
done


# ==================================================
# Wait for application Pod
# ==================================================

echo
echo "Waiting for playground pod..."

kubectl wait \
    --for=condition=Ready \
    pod \
    -l app=playground \
    -n dev \
    --timeout=300s


# ==================================================
# Get Argo CD password
# ==================================================

ARGOCD_PASSWORD=$(
    kubectl get secret \
        argocd-initial-admin-secret \
        -n argocd \
        -o jsonpath="{.data.password}" \
        | base64 -d
)


# ==================================================
# Result
# ==================================================

echo
echo "========================================"
echo "               P3 READY"
echo "========================================"

echo
echo "Kubernetes:"
kubectl get nodes

echo
echo "Application:"
kubectl get pods -n dev

echo
echo "Argo CD:"
kubectl get pods -n argocd

echo
echo "Ingress:"
kubectl get ingress -n argocd

echo
echo "========================================"
echo "               ARGO CD"
echo "========================================"

echo
echo "URL:"
echo "http://argocd.iot.local"

echo
echo "Username:"
echo "admin"

echo
echo "Password:"
echo "$ARGOCD_PASSWORD"

echo
echo "========================================"