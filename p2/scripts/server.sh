#!/bin/bash
set -e

echo "Creating swap..."

if ! swapon --show | grep -q /swapfile; then
    fallocate -l 3G /swapfile
    chmod 600 /swapfile
    mkswap /swapfile
    swapon /swapfile
fi

echo "Installing K3s..."

apt-get update && apt-get install -y curl

curl -sfL https://get.k3s.io | sh -s - \
    --node-ip 192.168.56.110 \
    --advertise-address 192.168.56.110 \
    --kubelet-arg=fail-swap-on=false

export KUBECONFIG=/etc/rancher/k3s/k3s.yaml

echo "Waiting for K3s..."

until kubectl get nodes | grep -q " Ready"; do
    sleep 3
done

echo "Deploying applications..."

kubectl apply -f /home/vagrant/confs

echo 'alias k=kubectl' >> /home/vagrant/.bashrc
sudo chmod 644 /etc/rancher/k3s/k3s.yaml

echo "K3s server is ready."
