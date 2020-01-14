#!/bin/bash

echo "Installing Docker..."
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add -
add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
apt-get update
apt-get install -y docker-ce docker-ce-cli containerd.io
apt-get install -y docker-compose

echo "Adding current user to docker..."
sudo usermod -aG docker vagrant

echo "Installing Apache Utils..."
apt-get -y install apache2-utils

date > /etc/vagrant_provisioned_at