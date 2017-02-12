#!/bin/bash

echo "INFO: Installing Docker..."
sudo apt-get update
sudo apt -y install docker.io

echo "INFO: Adding current user to docker..."
sudo usermod -aG docker ubuntu

echo "INFO: Pulling minio..."
docker pull minio/minio

echo "INFO: Running minio server..."
docker run -d --name minio \
--net=host \
-e "MINIO_ACCESS_KEY=O9RGDJAYKPPIRUS7F6K2" \
-e "MINIO_SECRET_KEY=AUagMf7zIuzTd9ZAeXmS658VY8R4DKdVaKnt9w3j" \
-v /data/export/minio:/export \
-v /data/config/minio:/root/.minio \
minio/minio server http://192.167.201.101/export http://192.167.201.102/export http://192.167.201.103/export http://192.167.201.104/export

date > /etc/vagrant_provisioned_at