#!/bin/bash

set -e


apt-get update
apt-get install -y  net-tools


curl -sfL https://get.k3s.io | \
    INSTALL_K3S_EXEC="server --write-kubeconfig-mode 644" \
    sh -


systemctl is-active --quiet k3s

echo "alias k=kubectl" >> /home/vagrant/.bashrc

# Make the token available to the worker through Vagrant's shared folder
cat /var/lib/rancher/k3s/server/node-token > /vagrant/k3s-token
