#!/bin/bash

set -e

# --------------------------------------------------
# Configuration
# --------------------------------------------------

K3S_INSTALL_URL="https://get.k3s.io"
TOKEN_FILE="/vagrant/k3s-token"
CONFS_DIR="/vagrant/confs"
VAGRANT_BASHRC="/home/vagrant/.bashrc"


# --------------------------------------------------
# 1. Update packages
# --------------------------------------------------

echo "[1/7] Updating packages..."

apt-get update -qq > /dev/null 2>&1


# --------------------------------------------------
# 2. Install dependencies
# --------------------------------------------------

echo "[2/7] Installing dependencies..."

DEBIAN_FRONTEND=noninteractive \
apt-get install -y -qq net-tools > /dev/null 2>&1


# --------------------------------------------------
# 3. Install K3s Server
# --------------------------------------------------

echo "[3/7] Installing K3s server..."

curl -sfL "$K3S_INSTALL_URL" | \
    INSTALL_K3S_EXEC="server --write-kubeconfig-mode 644" \
    sh - > /dev/null 2>&1


# --------------------------------------------------
# 4. Verify K3s service
# --------------------------------------------------

echo "[4/7] Checking K3s service..."

systemctl is-active --quiet k3s


# --------------------------------------------------
# 5. Configure kubectl
# --------------------------------------------------

echo "[5/7] Configuring kubectl..."

# Avoid adding the alias multiple times
if ! grep -q "alias k=kubectl" "$VAGRANT_BASHRC"; then
    echo "alias k=kubectl" >> "$VAGRANT_BASHRC"
fi

# Share K3s token with worker
cat /var/lib/rancher/k3s/server/node-token > "$TOKEN_FILE"


# --------------------------------------------------
# 6. Wait for Kubernetes
# --------------------------------------------------

echo "[6/7] Waiting for Kubernetes API..."

until kubectl get nodes > /dev/null 2>&1; do
    sleep 2
done


# --------------------------------------------------
# 7. Deploy applications
# --------------------------------------------------

echo "[7/7] Deploying applications..."

kubectl apply -f "$CONFS_DIR/app1.yaml"   > /dev/null 2>&1
kubectl apply -f "$CONFS_DIR/app2.yaml"   > /dev/null 2>&1
kubectl apply -f "$CONFS_DIR/app3.yaml"   > /dev/null 2>&1
kubectl apply -f "$CONFS_DIR/ingress.yaml" > /dev/null 2>&1


# --------------------------------------------------
# Complete
# --------------------------------------------------

echo
echo "======================================"
echo "       K3s SERVER READY ✓"
echo "======================================"