#!/usr/bin/env bash

## Following: https://kubernetes.io/docs/concepts/cluster-administration/certificates/
set -e

function usage {
    echo "USAGE: $0 <MASTER_CLUSTER_IP>,<MASTER_IP>,<MASTER_IP>"
    echo "  example: $0 ./ssl"
}

if [ -z "$1" ]; then
    usage
    exit 1
fi

IPS="IP:$1"

IPS="${IPS//,/,IP:}"

# Check if easy-rsa is already downloaded
if [ -d easy-rsa-master/easyrsa3 ]; then
	echo "easy-rsa already downloaded"
	
	if [ -d easy-rsa-master/easyrsa3/pki ]; then
		echo "pki already initialized, using previous values..."
		exit 0
	fi
else
	curl -L -O https://storage.googleapis.com/kubernetes-release/easy-rsa/easy-rsa.tar.gz > /dev/null 2>&1
	tar xzf easy-rsa.tar.gz > /dev/null 2>&1
fi

echo "Initializing easy-rsa"
cd easy-rsa-master/easyrsa3
./easyrsa init-pki > /dev/null 2>&1

echo "Creating the CA..."
./easyrsa --batch "--req-cn=kube-ca@`date +%s`" build-ca nopass

echo "Creating the server certificate and key ..."
./easyrsa --subject-alt-name="${IPS}",\
"DNS:kubernetes,"\
"DNS:kubernetes.default,"\
"DNS:kubernetes.default.svc,"\
"DNS:kubernetes.default.svc.cluster,"\
"DNS:kubernetes.default.svc.cluster.local" \
--days=10000 \
build-server-full server nopass