#!/bin/bash

echo "INFO: Installing Docker..."
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh

echo "INFO: Adding current user to docker..."
sudo usermod -aG docker vagrant

date > /etc/vagrant_provisioned_at