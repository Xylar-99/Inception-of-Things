#!/usr/bin/env bash
set -e

CLUSTER_NAME="iot"



# Install K3d if needed
if ! command -v k3d > /dev/null 2>&1; then
    echo "Installing K3d..."
    curl -s https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | bash
fi


# Create cluster if needed
if ! k3d cluster list | grep -q "$CLUSTER_NAME"; then
    echo "Creating cluster..."
    k3d cluster create "$CLUSTER_NAME"
fi



# Wait for Kubernetes
echo "Waiting for Kubernetes..."
kubectl wait \
    --for=condition=Ready \
    nodes \
    --all \
    --timeout=120s

# Create namespaces
echo "Creating namespaces..."

kubectl create namespace dev
kubectl create namespace argocd


# Install Argo CD
echo "Installing Argo CD..."

kubectl apply \
    -n argocd \
    --server-side \
    --force-conflicts \
    -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Wait for Argo CD
echo "Waiting for Argo CD..."

kubectl wait \
    --for=condition=Available \
    deployment/argocd-server \
    -n argocd \
    --timeout=300s



# Create Argo CD Application
echo "Creating application..."

kubectl apply -f confs/app.yaml

# Wait until Argo CD creates our Service
echo "Waiting for playground..."

until kubectl get service playground -n dev > /dev/null 2>&1; do
    sleep 2
done

# Wait until application Pod is ready
kubectl wait \
    --for=condition=Ready \
    pod \
    -l app=playground \
    -n dev \
    --timeout=300s
