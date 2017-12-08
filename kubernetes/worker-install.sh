#!/bin/bash

if [ -f "/tmp/bootstrap.env" ]; then
	source "/tmp/bootstrap.env"
else
	echo "Environment file not found"
	exit 1
fi

if [ -z "${MASTER_NODE}" ]; then
	echo "MASTER_NODE variable not found, setting to default 127.0.0.1"
	MASTER_NODE="127.0.0.1"
fi

if [ -z "${NODE_NAME}" ]; then
	echo "NODE_NAME variable not found, setting to $(hostname -s)"
	NODE_NAME=$(hostname -s)
fi

if [ -z "${NODE_IP}" ]; then
	echo "NODE_IP variable not found, setting to eth0: $(ip -4 -br addr show eth0 | awk '{print $3}' | cut -d"/" -f1)"
	NODE_IP=$(ip -4 -br addr show eth0 | awk '{print $3}' | cut -d"/" -f1)
fi

MASTER_API_NODE="https://${MASTER_NODE}"

#### Downloading Kubernetes ####

export K8S_VERSION=v1.8.5
export ARCH=amd64
export CLUSTER_NAME=local
# This is the Flannel network
export POD_NETWORK=10.1.0.0/16
export SERVICE_CLUSTER_IP_RANGE=10.3.0.0/16
export K8S_SERVICE_IP=10.3.0.1
export DNS_SERVICE_IP=10.3.0.10
export CLUSTER_DOMAIN=kubernetes.local

# Download Binaries
echo "Downloading Kubernetes..."
wget -q https://dl.k8s.io/${K8S_VERSION}/kubernetes-server-linux-${ARCH}.tar.gz

# Extract the main tar and add it to PATH
tar -xvf kubernetes-server-linux-amd64.tar.gz
export PATH=$(pwd)/kubernetes/server/bin:$PATH

# Drop kubelet and kube-proxy in a system wide location
echo "Dropping kubectl, kubelet and kube-proxy in /opt/bin/..."
mkdir -p /opt/bin
cp kubernetes/server/bin/kubelet /opt/bin/
cp kubernetes/server/bin/kube-proxy /opt/bin/
cp kubernetes/server/bin/kubectl /opt/bin/

# Extract the source to access the files:
# cd kubernetes && tar -xvf kubernetes-src.tar.gz && cd -

TOKEN=T1XXVHXsJ3bNVpC66sXQcHYNnG8dAZRL
# TOKEN=$(dd if=/dev/urandom bs=128 count=1 2>/dev/null | base64 | tr -d "=+/" | dd bs=32 count=1 2>/dev/null)

# Creating the kubeconfig file:
echo "Creating kubeconfig..."
mkdir ~/.kube
cat > ~/.kube/config <<- EOF
apiVersion: v1
kind: Config
users:
- name: root
  user:
    token: ${TOKEN}
clusters:
- name: local
  cluster:
    server: ${MASTER_API_NODE}
contexts:
- context:
    cluster: local
    user: root
  name: service-account-context
current-context: service-account-context
preferences: {}
EOF

# Creating the directories to place the Kubeconfig and copying it:
mkdir -p /var/lib/kube-proxy/ /var/lib/kubelet/
cp ~/.kube/config /var/lib/kube-proxy/kubeconfig
cp ~/.kube/config /var/lib/kubelet/kubeconfig


echo "Creating the kubelet service..."
cat > /etc/systemd/system/kubelet.service <<- EOF
[Unit]
Description=Kubernetes kubelet
Documentation=https://github.com/kubernetes/kubernetes
After=docker.service
Requires=docker.service

[Service]
ExecStartPre=/usr/bin/mkdir -p /etc/kubernetes/manifests
ExecStartPre=/usr/bin/mkdir -p /var/log/containers

ExecStart=/opt/bin/kubelet \
--address=0.0.0.0 \
--hostname-override=${NODE_IP} \
--require-kubeconfig=true \
--healthz-bind-address=0.0.0.0 \
--cluster-dns=${DNS_SERVICE_IP} \
--cluster-domain=kubernetes.local \
--pod-manifest-path=/etc/kubernetes/manifests \
--logtostderr=true \
--node-labels=kubernetes.io/role="node" \
--v=2
Restart=always
RestartSec=10
[Install]
WantedBy=multi-user.target

EOF

echo "Creating the kube-proxy service..."
cat > /etc/systemd/system/kube-proxy.service <<- EOF
[Unit]
Description=Kubernetes kube-proxy
Documentation=https://github.com/kubernetes/kubernetes
Requires=docker.service
After=docker.service
[Service]
ExecStart=/opt/bin/kube-proxy \
--master=${MASTER_API_NODE}
Restart=always
RestartSec=10
[Install]
WantedBy=multi-user.target

EOF

echo "Starting Kubelet and Kube Proxy..."
systemctl daemon-reload
systemctl enable kubelet
systemctl enable kube-proxy
systemctl start kubelet.service
systemctl start kube-proxy.service
