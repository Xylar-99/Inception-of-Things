#!/usr/bin/env bash
set -euo pipefail

echo
echo "========================================"
echo "       INSTALLING REQUIRED TOOLS"
echo "========================================"

sudo apt update

sudo apt install -y \
    curl \
    git \
    ca-certificates


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
# Check Docker
# ==================================================

if ! docker info >/dev/null 2>&1; then

    echo
    echo "========================================"
    echo "Docker permission is not active yet."
    echo
    echo "Log out and log back in."
    echo "Then run:"
    echo
    echo "./scripts/setup.sh"
    echo "========================================"

    exit 1
fi


# ==================================================
# Versions
# ==================================================

echo
echo "========================================"
echo "            TOOLS READY"
echo "========================================"

docker --version
kubectl version --client
k3d version
git --version

echo "========================================"