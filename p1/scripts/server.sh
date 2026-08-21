#!/bin/bash

set -e

echo "=== Configuring SSH ==="

apt-get update
apt-get install -y openssh-server

systemctl enable --now ssh

mkdir -p /home/vagrant/.ssh

chmod 700 /home/vagrant/.ssh

echo "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEe4xCg2FZVBAj5Vqmku3bdADg1fVxOzH9G7GaAJZay0 abdelbassat@abdelbassat-HVY-WXX9
" >> /home/vagrant/.ssh/authorized_keys

chmod 600 /home/vagrant/.ssh/authorized_keys

chown -R vagrant:vagrant /home/vagrant/.ssh

echo "=== SSH configured ==="