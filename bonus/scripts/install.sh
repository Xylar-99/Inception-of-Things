#!/usr/bin/env bash
set -euo pipefail

echo "Installing required tools..."

sudo apt update

sudo apt install -y \
    curl \
    git \
    ca-certificates \
    openssl


# ==================================================
# Docker
# ==================================================

if ! command -v docker >/dev/null 2>&1; then

    echo "Installing Docker..."

    curl -fsSL https://get.docker.com | sudo sh

    sudo usermod -aG docker "$USER"

else
    echo "Docker already installed."
fi


# ==================================================
# kubectl
# ==================================================

if ! command -v kubectl >/dev/null 2>&1; then

    echo "Installing kubectl..."

    KUBECTL_VERSION=$(curl -fsSL \
        https://dl.k8s.io/release/stable.txt)

    curl -fsSL \
        "https://dl.k8s.io/release/$KUBECTL_VERSION/bin/linux/amd64/kubectl" \
        -o /tmp/kubectl

    sudo install \
        -m 0755 \
        /tmp/kubectl \
        /usr/local/bin/kubectl

    rm /tmp/kubectl

else
    echo "kubectl already installed."
fi


# ==================================================
# k3d
# ==================================================

if ! command -v k3d >/dev/null 2>&1; then

    echo "Installing k3d..."

    curl -fsSL \
        https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh \
        | bash

else
    echo "k3d already installed."
fi


# ==================================================
# Helm
# ==================================================

if ! command -v helm >/dev/null 2>&1; then

    echo "Installing Helm..."

    curl -fsSL \
        https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-4 \
        | bash

else
    echo "Helm already installed."
fi


# ==================================================
# Result
# ==================================================

echo
echo "========================================"
echo "          TOOLS INSTALLED"
echo "========================================"

docker --version
kubectl version --client
k3d version
helm version --short
git --version
curl --version | head -n 1

echo "========================================"
echo
echo "If Docker was just installed, log out"
echo "and log back in before running setup.sh."