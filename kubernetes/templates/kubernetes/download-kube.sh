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

      echo "Creating bootstrap kubeconfig..."
      /opt/bin/kubectl config set-cluster kubernetes --certificate-authority=/etc/ssl/kube/ca.pem \
        --embed-certs=true \
        --server=${KUBE_API_LB_URL} \
        --kubeconfig=bootstrap.kubeconfig
      /opt/bin/kubectl config set-credentials kubelet-bootstrap \
        --token=${TOKEN} \
        --kubeconfig=bootstrap.kubeconfig
      /opt/bin/kubectl config set-context default \
        --cluster=kubernetes \
        --user=kubelet-bootstrap \
        --kubeconfig=bootstrap.kubeconfig
      /opt/bin/kubectl config use-context default --kubeconfig=bootstrap.kubeconfig
      mkdir -p /var/lib/kubelet/
      mv bootstrap.kubeconfig /var/lib/kubelet/bootstrap.kubeconfig

      echo "Creating kube-proxy kubeconfig..."
      /opt/bin/kubectl config set-cluster kubernetes \
        --certificate-authority=/etc/ssl/kube/ca.pem \
        --embed-certs=true \
        --server=${KUBE_API_LB_URL} \
        --kubeconfig=kube-proxy.kubeconfig
      /opt/bin/kubectl config set-credentials kube-proxy \
        --client-certificate=/etc/ssl/kube/kube-proxy.pem \
        --client-key=/etc/ssl/kube/kube-proxy-key.pem \
        --embed-certs=true \
        --kubeconfig=kube-proxy.kubeconfig
      /opt/bin/kubectl config set-context default --cluster=kubernetes \
        --user=kube-proxy --kubeconfig=kube-proxy.kubeconfig
      mkdir -p /var/lib/kube-proxy/
      mv kube-proxy.kubeconfig /var/lib/kube-proxy/kubeconfig