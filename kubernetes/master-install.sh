#!/bin/bash

if [ -f "/tmp/bootstrap.env" ]; then
	source "/tmp/bootstrap.env"
else
	echo "Environment file not found"
	exit 1
fi


if [ -z "${ETCD_ENDPOINTS}" ]; then
	echo "ETCD_ENDPOINTS variable not found, setting to default http://127.0.0.1:2379"
	ETCD_ENDPOINTS="http://127.0.0.1:2379"
fi

if [ -z "${ETCD_INITIAL_CLUSTER}" ]; then
	echo "ETCD_INITIAL_CLUSTER variable not found, setting to default $(hosname)=http://127.0.0.1:2380"
	ETCD_INITIAL_CLUSTER="$(hosname)=http://127.0.0.1:2380"
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


## Changing default ports to not collide with CoreOS etcd
ETCD_ENDPOINTS="${ETCD_ENDPOINTS//2379/2389}"
ETCD_INITIAL_CLUSTER="${ETCD_INITIAL_CLUSTER//2380/2390}"

# Since this is a master node we are setting the master IP to itself
MASTER_IP=${NODE_IP}


# We are transforming "172.17.4.51,172.17.4.52" to "http://172.17.4.51:8080,http://172.17.4.52:8080"
MASTER_API_NODE="http://${MASTER_NODE}:8080"


echo "Starting Kube etcd..."
### Run ETCD:

cat > /etc/systemd/system/kube-etcd.service <<- EOF
[Unit]
Description=etcd cluster for Kubernetes
After=docker.service
Requires=docker.service
[Service]
Restart=on-failure
RestartSec=20
TimeoutStartSec=60
RemainAfterExit=yes
ExecStartPre=-/usr/bin/docker stop kube-etcd
ExecStartPre=-/usr/bin/docker rm kube-etcd
ExecStartPre=/usr/bin/docker pull gcr.io/google-containers/etcd:3.0.17
ExecStart=/usr/bin/docker run --name kube-etcd \
  --net=host \
  --volume=/var/etcd-data:/etcd-data \
  gcr.io/google-containers/etcd:3.0.17 \
  /usr/local/bin/etcd \
  --data-dir=/etcd-data --name ${NODE_NAME} \
  --initial-advertise-peer-urls http://${NODE_IP}:2390 \
  --listen-peer-urls http://0.0.0.0:2390 \
  --advertise-client-urls http://${NODE_IP}:2389 \
  --listen-client-urls http://0.0.0.0:2389 \
  --initial-cluster "${ETCD_INITIAL_CLUSTER}"
ExecStop=/usr/bin/docker stop kube-etcd
ExecStop=/usr/bin/docker rm kube-etcd
[Install]
WantedBy=multi-user.target
EOF

echo "Starting Kube etcd..."
systemctl daemon-reload
systemctl enable kube-etcd
systemctl start kube-etcd.service



#### Downloading Kubernetes ####

export K8S_VERSION=v1.8.4
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
- name: kubelet
  user:
    token: ${TOKEN}
clusters:
- name: local
  cluster:
    insecure-skip-tls-verify: true
    server: ${MASTER_API_NODE}
contexts:
- context:
    cluster: local
    user: kubelet
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


echo "Creating the manifests for the API Server, Controller and the Scheduler..."
mkdir -p /etc/kubernetes/manifests

echo "kube-api-server.json..."
cat > /etc/kubernetes/manifests/kube-api-server.json <<- EOF
{
  "kind": "Pod",
  "apiVersion": "v1",
  "metadata": {
    "name": "kube-apiserver"
  },
  "spec": {
    "hostNetwork": true,
    "containers": [
      {
        "name": "kube-apiserver",
        "image": "gcr.io/google-containers/hyperkube:${K8S_VERSION}",
        "command": [
          "/hyperkube",
          "apiserver",
          "--service-cluster-ip-range=${SERVICE_CLUSTER_IP_RANGE}",
          "--etcd-servers=http://${MASTER_IP}:2389",
          "--token-auth-file=/dev/null",
          "--insecure-bind-address=0.0.0.0",
          "--advertise-address=${MASTER_IP}",
          "--anonymous-auth=true"
        ],
        "ports": [
          {
            "name": "https",
            "hostPort": 443,
            "containerPort": 443
          },
          {
            "name": "local",
            "hostPort": 8080,
            "containerPort": 8080
          }
        ],
        "volumeMounts": [
          {
            "name": "srvkube",
            "mountPath": "/srv/kubernetes",
            "readOnly": true
          },
          {
            "name": "etcssl",
            "mountPath": "/etc/ssl",
            "readOnly": true
          }
        ],
        "livenessProbe": {
          "httpGet": {
            "scheme": "HTTP",
            "host": "127.0.0.1",
            "port": 8080,
            "path": "/healthz"
          },
          "initialDelaySeconds": 15,
          "timeoutSeconds": 15
        }
      }
    ],
    "volumes": [
      {
        "name": "srvkube",
        "hostPath": {
          "path": "/srv/kubernetes"
        }
      },
      {
        "name": "etcssl",
        "hostPath": {
          "path": "/etc/ssl"
        }
      }
    ]
  }
}
EOF

echo "kube-scheduler.json..."
cat > /etc/kubernetes/manifests/kube-scheduler.json <<- EOF
{
  "kind": "Pod",
  "apiVersion": "v1",
  "metadata": {
    "name": "kube-scheduler"
  },
  "spec": {
    "hostNetwork": true,
    "containers": [
      {
        "name": "kube-scheduler",
        "image": "gcr.io/google-containers/hyperkube:${K8S_VERSION}",
        "command": [
          "/hyperkube",
          "scheduler",
          "--master=127.0.0.1:8080"
        ],
        "livenessProbe": {
          "httpGet": {
            "scheme": "HTTP",
            "host": "127.0.0.1",
            "port": 10251,
            "path": "/healthz"
          },
          "initialDelaySeconds": 15,
          "timeoutSeconds": 15
        }
      }
    ]
  }
}
EOF

echo "kube-controller-manager.json..."
cat > /etc/kubernetes/manifests/kube-controller-manager.json <<- EOF
{
  "kind": "Pod",
  "apiVersion": "v1",
  "metadata": {
    "name": "kube-controller-manager"
  },
  "spec": {
    "hostNetwork": true,
    "containers": [
      {
        "name": "kube-controller-manager",
        "image": "gcr.io/google-containers/hyperkube:${K8S_VERSION}",
        "command": [
          "/hyperkube",
          "controller-manager",
          "--cluster-cidr=${POD_NETWORK}",
          "--master=127.0.0.1:8080"
        ],
        "volumeMounts": [
          {
            "name": "srvkube",
            "mountPath": "/srv/kubernetes",
            "readOnly": true
          },
          {
            "name": "etcssl",
            "mountPath": "/etc/ssl",
            "readOnly": true
          }
        ],
        "livenessProbe": {
          "httpGet": {
            "scheme": "HTTP",
            "host": "127.0.0.1",
            "port": 10252,
            "path": "/healthz"
          },
          "initialDelaySeconds": 15,
          "timeoutSeconds": 15
        }
      }
    ],
    "volumes": [
      {
        "name": "srvkube",
        "hostPath": {
          "path": "/srv/kubernetes"
        }
      },
      {
        "name": "etcssl",
        "hostPath": {
          "path": "/etc/ssl"
        }
      }
    ]
  }
}
EOF

echo "Starting Kubelet and Kube Proxy..."
systemctl daemon-reload
systemctl enable kubelet
systemctl enable kube-proxy
systemctl start kubelet.service
systemctl start kube-proxy.service


# After this we can create the dashboard:
# kubectl create -f /tmp/dashboard.yaml
# get the node where the dashboard is running:
# kubectl get pods 
