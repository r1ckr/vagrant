#!/bin/bash

echo "INFO: Installing Docker..."
sudo apt-get update
sudo apt -y install docker.io

echo "INFO: Adding current user to docker..."
sudo usermod -aG docker ubuntu

date > /etc/vagrant_provisioned_at