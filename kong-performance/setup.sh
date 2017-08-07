#!/bin/bash

echo "Installing Docker dependencies..."
apt-get update
apt-get -y install \
  apt-transport-https \
  ca-certificates \
  curl \
  software-properties-common
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
apt-key fingerprint 0EBFCD88
add-apt-repository    "deb [arch=amd64] https://download.docker.com/linux/ubuntu \
   $(lsb_release -cs) \
   stable"
apt-get update
echo "Installing Docker..."
apt-get -y install docker-ce

echo "Installing Docker Compose..."
curl -L https://github.com/docker/compose/releases/download/1.15.0/docker-compose-`uname -s`-`uname -m` > /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

echo "Adding current user to docker..."
sudo usermod -aG docker ubuntu

echo "Installing Apache Utils..."
apt-get -y install apache2-utils

date > /etc/vagrant_provisioned_at