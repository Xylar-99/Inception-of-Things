#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."


# Configuration

CLUSTER="iot-p3"
ARGOCD_VERSION="v3.5.3"


# Install required tools

bash scripts/install.sh


# Local hostnames

grep -q "argocd.iot.local" /etc/hosts ||
    echo "127.0.0.1 argocd.iot.local" | sudo tee -a /etc/hosts

grep -q "app.iot.local" /etc/hosts ||
    echo "127.0.0.1 app.iot.local" | sudo tee -a /etc/hosts


# Create fresh k3d cluster

echo
echo "Creating fresh k3d cluster..."


k3d cluster create "$CLUSTER" -p "80:80@loadbalancer"

k3d kubeconfig merge "$CLUSTER" --kubeconfig-switch-context

kubectl wait --for=condition=Ready nodes --all --timeout=180s


# Create namespaces

kubectl create namespace dev
kubectl create namespace argocd


# Install Argo CD

echo
echo "Installing Argo CD..."

kubectl apply \
    -n argocd \
    -f "https://raw.githubusercontent.com/argoproj/argo-cd/$ARGOCD_VERSION/manifests/install.yaml"

kubectl wait \
    --for=condition=Available \
    deployment/argocd-server \
    -n argocd \
    --timeout=10m


# Configure Argo CD

#   this is mean nto used https only http 

# Allow Argo CD HTTP behind Traefik

kubectl patch configmap argocd-cmd-params-cm \
    -n argocd \
    --type merge \
    -p '{"data":{"server.insecure":"true"}}'

kubectl rollout restart deployment/argocd-server -n argocd

kubectl rollout status \
    deployment/argocd-server \
    -n argocd \
    --timeout=5m


# Argo CD application

kubectl apply -f confs/app.yaml


# Argo CD ingress

kubectl apply -f confs/argocd-ingress.yaml

echo "Argo CD ready."


# Wait for application

echo
echo "Waiting for playground..."

until kubectl get service playground \
    -n dev >/dev/null 2>&1
do
    sleep 2
done

kubectl wait \
    --for=condition=Ready \
    pod \
    -l app=playground \
    -n dev \
    --timeout=5m


# Get credentials

ARGOCD_PASSWORD=$(
    kubectl get secret \
        argocd-initial-admin-secret \
        -n argocd \
        -o jsonpath='{.data.password}' |
        base64 -d
)


# Results

echo
echo "========================================"
echo "                ARGO CD"
echo "========================================"
echo "URL:      http://argocd.iot.local"
echo "Username: admin"
echo "Password: $ARGOCD_PASSWORD"

echo
echo "========================================"
echo "              APPLICATION"
echo "========================================"
echo "URL:      http://app.iot.local"

echo
echo "========================================"
echo "               ALL READY"
echo "========================================"