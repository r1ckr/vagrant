#!/bin/bash

if [ -f "/etc/kubernetes/bootstrap.env" ]; then
	source "/etc/kubernetes/bootstrap.env"
else
	echo "Environment file not found"
	exit 1
fi

if [ -z "${MASTER_NODE}" ]; then
	echo "MASTER_NODE variable not found, setting to default 127.0.0.1"
	MASTER_NODE="127.0.0.1"
fi

if [ -z "${K8S_VERSION}" ]; then
	echo "K8S_VERSION variable not found, setting to default 1.8.5"
	K8S_VERSION="1.8.5"
fi

if [ -z "${NODE_NAME}" ]; then
	echo "NODE_NAME variable not found, setting to $(hostname -s)"
	NODE_NAME=$(hostname -s)
fi

if [ -z "${NODE_IP}" ]; then
	echo "NODE_IP variable not found, setting to eth0: $(ip -4 -br addr show eth0 | awk '{print $3}' | cut -d"/" -f1)"
	NODE_IP=$(ip -4 -br addr show eth0 | awk '{print $3}' | cut -d"/" -f1)
fi


# Since this is a master node we are setting the master IP to itself
MASTER_IP=${NODE_IP}

MASTER_API_NODE="https://${NODE_IP}"

#### Downloading Kubernetes ####

#export CLUSTER_NAME=local
# This is the Flannel network
export POD_NETWORK=10.1.0.0/16
export SERVICE_CLUSTER_IP_RANGE=10.3.0.0/16
#export K8S_SERVICE_IP=10.3.0.1
export DNS_SERVICE_IP=10.3.0.10
export CLUSTER_DOMAIN=kubernetes.local

# Extract the source to access the files:
# cd kubernetes && tar -xvf kubernetes-src.tar.gz && cd -

TOKEN=T1XXVHXsJ3bNVpC66sXQcHYNnG8dAZRL
# TOKEN=$(dd if=/dev/urandom bs=128 count=1 2>/dev/null | base64 | tr -d "=+/" | dd bs=32 count=1 2>/dev/null)

echo "Creating the manifests for the API Server, Controller and the Scheduler..."
mkdir -p /etc/kubernetes/manifests

echo "kube-api-server.json..."
cat > /etc/kubernetes/manifests/kube-api-server.json <<- EOF
{
  "kind": "Pod",
  "apiVersion": "v1",
  "metadata": {
    "name": "kube-apiserver",
    "namespace": "kube-system"
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
          "--etcd-servers=http://127.0.0.1:2389",
          "--insecure-bind-address=127.0.0.1",
          "--anonymous-auth=true",
          "--advertise-address=${MASTER_IP}",
          "--bind-address=0.0.0.0",
          "--secure-port=443",
          "--client-ca-file=/etc/ssl/kube/ca.crt",
          "--tls-cert-file=/etc/ssl/kube/server.crt",
          "--tls-private-key-file=/etc/ssl/kube/server.key",
          "--token-auth-file=/srv/kubernetes/token-auth-file.csv"
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
    "name": "kube-scheduler",
    "namespace": "kube-system"
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
    "name": "kube-controller-manager",
    "namespace": "kube-system"
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

echo "Waiting for api node to start"
until $(curl --output /dev/null --silent --head --fail http://127.0.0.1:8080); do
    printf '.'
    sleep 5
done

echo "Adding root user rolebinding..."
kubectl create clusterrolebinding root-cluster-admin-binding --clusterrole=cluster-admin --user=root

echo "Creating token file..."
echo -n $(cat /etc/kubernetes/bootstrap.env | grep TOKEN | awk -F "=" '{print $2}') > /tmp/token

echo "Creating secret from token file..."
kubectl create --namespace=kube-system secret generic api-token --from-file=/tmp/token

echo "Deploying dashboard..."
kubectl create -f /tmp/dashboard.yaml
