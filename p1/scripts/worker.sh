#!/bin/bash

set -e

SERVER_IP="192.168.56.110"


# Wait until the server creates the token
while [ ! -f /vagrant/k3s-token ]; do
    sleep 2
done


K3S_TOKEN=$(cat /vagrant/k3s-token)


apt-get update
apt-get install -y  net-tools


curl -sfL https://get.k3s.io | \
    K3S_URL="https://${SERVER_IP}:6443" \
    K3S_TOKEN="${K3S_TOKEN}" \
    sh -


systemctl is-active --quiet k3s-agent

# k = kubectl
echo "alias k=kubectl" >> /home/vagrant/.bashrc
