# Kubernetes

This is a vagrant setup that spins up a kube cluster with RBAC ready to use with a `root` user.  

## Bring it up
```bash
vagrant up
```
After this Kubernetes will be up and running

## Deploy Dashboard:
After it is up, deploy the Dashboard:
```
vagrant ssh m1
sudo -i
kubectl create --namespace=kube-system secret generic api-token --from-file=/tmp/token

## After this we can create the dashboard:
kubectl create -f /tmp/dashboard.yaml
```

## Kubectl config:
You can use the following kubeconfig from your local machine: 
```yaml
apiVersion: v1
kind: Config
users:
- name: root
  user:
    token: T1XXVHXsJ3bNVpC66sXQcHYNnG8dAZRL
clusters:
- name: local
  cluster:
    insecure-skip-tls-verify: true
    server: https://192.168.47.21
contexts:
- context:
    cluster: local
    user: root
  name: service-account-context
current-context: service-account-context
preferences: {}
```

## Access the Dashboard:
To access the dashboard create a proxy in your localmachine:
```
$ kubectl proxy
Starting to serve on 127.0.0.1:8001
```
Now access [http://127.0.0.1:8001/ui](http://127.0.0.1:8001/ui)
