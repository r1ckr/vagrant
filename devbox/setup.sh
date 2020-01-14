#!/bin/bash

echo "Installing Docker..."
sudo apt -y install docker.io

echo "Adding current user to docker..."
sudo usermod -aG docker vagrant

echo "Copying ssh keys into .ssh directory..."
su ubuntu -c "cp -rn /host-ssh/* /home/vagrant/.ssh/"

date > /etc/vagrant_provisioned_at