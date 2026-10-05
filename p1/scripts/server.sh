#!/bin/bash
set -e

SERVER_IP="192.168.56.110"

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

echo "Installing K3s server..."

curl -sfL https://get.k3s.io | \
    sh -s - server \
    --node-ip "$SERVER_IP" \
    --advertise-address "$SERVER_IP" \
    --write-kubeconfig-mode 644

echo "Waiting for K3s server..."

until systemctl is-active --quiet k3s; do
    sleep 2
done

echo "Waiting for K3s token..."

while [ ! -s /var/lib/rancher/k3s/server/node-token ]; do
    sleep 2
done

echo "Sharing token with worker..."

cp /var/lib/rancher/k3s/server/node-token /vagrant/k3s-token

chmod 644 /etc/rancher/k3s/k3s.yaml

echo 'alias k=kubectl' >> /home/vagrant/.bashrc


echo "K3s server is ready."