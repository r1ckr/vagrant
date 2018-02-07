#!/bin/bash
      set -x
      # Download Binaries
      echo "Downloading Kubernetes..."
      mkdir kubernetes && cd kubernetes
      
      if [ -z "${K8S_VERSION}" ]; then
          export K8S_VERSION=$(curl -fsSL --retry 5 "https://dl.k8s.io/release/stable.txt")
        echo "K8S_VERSION variable not found, setting it to the latest stable version: ${K8S_VERSION}"
      fi
      
      wget -q \
        "https://storage.googleapis.com/kubernetes-release/release/${K8S_VERSION}/bin/linux/amd64/kubelet" \
        "https://storage.googleapis.com/kubernetes-release/release/${K8S_VERSION}/bin/linux/amd64/kube-proxy" \
        "https://storage.googleapis.com/kubernetes-release/release/${K8S_VERSION}/bin/linux/amd64/kubectl"
      
      if [ "${IS_MASTER}" == "true" ]; then
          wget -q \
            "https://storage.googleapis.com/kubernetes-release/release/${K8S_VERSION}/bin/linux/amd64/kube-apiserver" \
            "https://storage.googleapis.com/kubernetes-release/release/${K8S_VERSION}/bin/linux/amd64/kube-controller-manager" \
            "https://storage.googleapis.com/kubernetes-release/release/${K8S_VERSION}/bin/linux/amd64/kube-scheduler"
      fi
      
      
      chmod +x kube*
      
      echo "Copying k8s binaries into /opt/bin/..."
      mkdir -p /opt/bin
      rsync -a ./* /opt/bin/
      
      cd ../