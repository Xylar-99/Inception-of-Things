#!/bin/bash
set -e

SERVER_IP="192.168.56.110"
WORKER_IP="192.168.56.111"

echo "Creating swap..."

if ! swapon --show | grep -q /swapfile; then
    fallocate -l 3G /swapfile
    chmod 600 /swapfile
    mkswap /swapfile
    swapon /swapfile
fi

echo "Installing curl..."

apt-get update
apt-get install -y curl

echo "Waiting for server token..."

while [ ! -s /vagrant/k3s-token ]; do
    sleep 2
done

K3S_TOKEN="$(cat /vagrant/k3s-token)"

echo "Installing K3s worker..."

curl -sfL https://get.k3s.io | \
    K3S_URL="https://${SERVER_IP}:6443" \
    K3S_TOKEN="$K3S_TOKEN" \
    sh -s - agent \
    --node-ip "$WORKER_IP"

echo "Waiting for K3s agent..."

until systemctl is-active --quiet k3s-agent; do
    sleep 2
done

echo 'alias k=kubectl' >> /home/vagrant/.bashrc


