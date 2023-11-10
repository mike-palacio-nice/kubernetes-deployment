## Deploying Nginx Ingress Controller

(Source)[https://github.com/morrismusumi/kubernetes/tree/main/clusters/homelab-k8s/apps/metallb-plus-nginx-ingress]

```sh
helm install nginx-ingress oci://ghcr.io/nginxinc/charts/nginx-ingress --version 1.0.2
```
## Deploying Cert Manager

(Source)[https://github.com/morrismusumi/kubernetes/tree/main/clusters/homelab-k8s/apps/cert-manager]

## Deploying MetalLb

(Source)[https://metallb.universe.tf/installation/]
```sh
# see what changes would be made, returns nonzero returncode if different
kubectl get configmap kube-proxy -n kube-system -o yaml | \
sed -e "s/strictARP: false/strictARP: true/" | \
kubectl diff -f - -n kube-system

# actually apply the changes, returns nonzero returncode on errors only
kubectl get configmap kube-proxy -n kube-system -o yaml | \
sed -e "s/strictARP: false/strictARP: true/" | \
kubectl apply -f - -n kube-system

helm repo add metallb https://metallb.github.io/metallb
helm install metallb metallb/metallb
```

