## Restarting the K8s Cluster (WARNING: all resources will be removed)

(Initial Setup)[https://deploy.equinix.com/blog/installing-and-deploying-kubernetes-on-ubuntu/]

```sh
sudo kubeadm reset

sudo systemctl stop kubelet
sudo systemctl stop docker
sudo rm -rf /var/lib/cni/
sudo rm -rf /var/lib/kubelet/*
sudo rm -rf /etc/cni/
sudo ifconfig cni0 down
sudo ifconfig flannel.1 down
# sudo ifconfig docker0 down

sudo systemctl restart kubelet
sudo systemctl restart containerd

sudo kubeadm init --pod-network-cidr=10.244.0.0/16

mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config

kubectl taint nodes master-node node-role.kubernetes.io/control-plane-
```
## Install Pod Network - Flannel
```sh
# Needs manual creation of namespace to avoid helm error
kubectl create ns kube-flannel
kubectl label --overwrite ns kube-flannel pod-security.kubernetes.io/enforce=privileged

helm repo add flannel https://flannel-io.github.io/flannel/
helm install flannel --set podCidr="10.244.0.0/16" --namespace kube-flannel flannel/flannel


## Prefer Helm?
# kubectl apply -f https://raw.githubusercontent.com/flannel-io/flannel/master/Documentation/kube-flannel.yml

# kubectl taint nodes master-node node-role.kubernetes.io/control-plane-

# sudo ip link delete cni0 type bridge
```

## Deploying Nginx Ingress Controller

<!-- (Source)[https://github.com/morrismusumi/kubernetes/tree/main/clusters/homelab-k8s/apps/metallb-plus-nginx-ingress]
```sh
helm install nginx-ingress oci://ghcr.io/nginxinc/charts/nginx-ingress --version 1.0.2 -->
```sh
(Source)[https://kubernetes.github.io/ingress-nginx/deploy/]
```sh
helm upgrade --install ingress-nginx ingress-nginx \
  --repo https://kubernetes.github.io/ingress-nginx \
  --namespace ingress-nginx --create-namespace
```

## Deploying Cert Manager

<!-- (Source)[https://github.com/morrismusumi/kubernetes/tree/main/clusters/homelab-k8s/apps/cert-manager]

```sh
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.12.0/cert-manager.yaml

kubectl --namespace cert-manager create secret generic cloudflare-api-key \
  --from-literal=apiKey=YOUR_API_KEY \
  --from-literal=email=YOUR_CLOUDFLARE_EMAIL \
  --from-literal=apiToken=YOUR_API_TOKEN

kubectl apply -f certmanager/tls-clusterissuer.yaml
kubectl apply -f certmanager/tls-certificate.yaml
``` -->

(Source)[https://cert-manager.io/docs/installation/helm/]
```sh
helm repo add jetstack https://charts.jetstack.io --force-update

helm install \
  cert-manager jetstack/cert-manager \
  --namespace cert-manager \
  --create-namespace \
  --version v1.17.0 \
  --set crds.enabled=true

kubectl --namespace cert-manager create secret generic cloudflare-api-key \
  --from-literal=apiKey=YOUR_API_KEY \
  --from-literal=email=YOUR_CLOUDFLARE_EMAIL \
  --from-literal=apiToken=YOUR_API_TOKEN

kubectl apply -f certmanager/tls-clusterissuer.yaml
kubectl apply -f certmanager/tls-certificate.yaml
```



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
```
It might be a good idea to restart kube-proxy here.

```sh
helm repo add metallb https://metallb.github.io/metallb --force-update
helm install metallb metallb/metallb --namespace metallb --create-namespace

## Create the address pool and L2 advertisement
kubectl apply -f metallb/ip-address-pool.yaml
kubectl apply -f metallb/l2-advertisement.yaml
```

## Deploying CloudFlare Ingress Controller (this may not be needed as of 2025-03-29)
```sh
helm upgrade --install --wait \
  -n cloudflare-tunnel-ingress-controller --create-namespace \
  cloudflare-tunnel-ingress-controller \
  strrl.dev/cloudflare-tunnel-ingress-controller \
  --set=cloudflare.apiToken="<cloudflare-api-token>",cloudflare.accountId="<cloudflare-account-id>",cloudflare.tunnelName="<your-favorite-tunnel-name>"
```

## Deploying External-DNS

<!-- ```sh
kubectl create secret generic cloudflare-api-key --from-literal=apiKey=YOUR_API_KEY --from-literal=email=YOUR_CLOUDFLARE_EMAIL --from-literal=apiToken=YOUR_API_TOKEN
kubectl apply -f external-dns/deployment.yaml
``` -->

(Source)[https://github.com/kubernetes-sigs/external-dns/blob/master/docs/tutorials/cloudflare.md]
```sh
kubectl create namespace external-dns
kubectl --namespace external-dns create secret generic cloudflare-api-key \
  --from-literal=apiKey=YOUR_API_KEY

helm repo add external-dns https://kubernetes-sigs.github.io/external-dns/
helm repo update
helm upgrade --install external-dns external-dns/external-dns --values external-dns/values.yaml --namespace external-dns
```

## Deploying ArgoCD

(Source)[https://artifacthub.io/packages/helm/argo/argo-cd]
```sh
helm repo add argo https://argoproj.github.io/argo-helm
helm install argocd argo/argo-cd --version 7.8.15 --values argocd/values.yaml --namespace argocd --create-namespace
```

```sh
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
kubectl patch svc argocd-server -n argocd -p '{"spec": {"type": "LoadBalancer"}}'

kubectl apply -f argocd/ingress.yaml

```

### NFS Setup

```sh
sudo mkdir -p /mnt/plex-media
sudo mount /dev/sdb /mnt/plex-media

sudo chown nobody:nogroup /mnt/plex-media
sudo chmod 0777 /mnt/plex-media
echo '/mnt/plex-media 192.168.1.3/24(rw,sync,no_subtree_check)' | sudo tee /etc/exports
sudo exportfs -rav
sudo systemctl restart nfs-kernel-server

helm repo add csi-driver-nfs https://raw.githubusercontent.com/kubernetes-csi/csi-driver-nfs/master/charts
helm repo update
helm install csi-driver-nfs csi-driver-nfs/csi-driver-nfs --namespace kube-system --set kubeletDir=/var/lib/kubelet
```

## Deploying Kubernetes Dashboard

```sh
kubectl apply -f https://raw.githubusercontent.com/kubernetes/dashboard/v2.7.0/aio/deploy/recommended.yaml
```

## Deploying Jackett

```sh
kubectl apply -f media-tools/jackett/config-pvc.yaml
mkdir -p /mnt/ssd/media/configs/jackett/Jackett/

sudo vi /etc/jackett/configs/jackett/Jackett/ServerConfig.json
(insert)
{
  "BasePathOverride": "/jackett"
}

helm install jackett bananaspliff/jackett \
    --values plex/jackett/values.yaml \
    --namespace plexserver
```

## Deploying Radarr

```sh
kubectl apply -f media-tools/radarr/config-pvc.yaml

sudo vi /etc/radarr/configs/radarr/config.xml
(insert)
<Config>
  <UrlBase>/home</UrlBase>
</Config>
```

## Deploying Longhorn

```sh
helm repo add longhorn https://charts.longhorn.io &&
helm repo update &&
helm install longhorn longhorn/longhorn --namespace longhorn-system --create-namespace -f longhorn/values.yaml

USER=<USERNAME_HERE>; PASSWORD=<PASSWORD_HERE>; echo "${USER}:$(openssl passwd -stdin -apr1 <<< ${PASSWORD})" >> auth
kubectl -n longhorn-system create secret generic basic-auth --from-file=auth

kubectl -n longhorn-system apply -f longhorn/ingress.yaml
```

## Deploying Qbittorrent

```sh
kubectl apply -f media-tools/qbittorrent
```


## Deploying AMD Plugin (Not working)

This plugin allows passthrough for the AMD GPU to K8s resources

```sh
helm install amd-gpu helm/amd-gpu/
```

## Deploying ELK Stack

```sh
## Install CRDs
kubectl create -f https://download.elastic.co/downloads/eck/2.14.0/crds.yaml
kubectl apply -f kubernetes-deployment/elastic-stack/operator.yaml

helm repo add elastic https://helm.elastic.co
helm repo update

# Install an eck-managed Elasticsearch, Kibana, Beats and Logstash using custom values.
helm install eck-stack elastic/eck-stack \
    --values kubernetes-deployment/eck-stack/values.yaml -n elastic-stack
```


## Installing S3 CSI Driver

```sh
helm repo add aws-mountpoint-s3-csi-driver https://awslabs.github.io/mountpoint-s3-csi-driver
helm repo update

helm upgrade --install aws-mountpoint-s3-csi-driver \
    --namespace kube-system \
    aws-mountpoint-s3-csi-driver/aws-mountpoint-s3-csi-driver

```