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

## Deploying CephFS with Rook

*CephFs is not working as expected. Need to wait for (issue)[https://github.com/rook/rook/issues/6314] to be resolved so a PVC can be provisioned.*
(Source)[https://github.com/morrismusumi/kubernetes/blob/main/clusters/homelab-k8s/apps/rook/README.md]

```sh
$ git clone --single-branch --branch master https://github.com/rook/rook.git
cd rook/deploy/examples
kubectl create -f crds.yaml -f common.yaml -f ceph-operator.yaml
kubectl create -f ceph-cluster.yaml

# Verify
kubectl -n rook-ceph get pod

# Toolbox ()
$ kubectl create -f deploy/examples/toolbox.yaml

# CephFS
kubectl create -f ceph-filesystem.yaml
kubectl create -f ceph-storageclass.yaml
```

## Deploying Kube-Plex

(Source)[https://github.com/ressu/kube-plex/pkgs/container/kube-plex]
```sh
helm repo add kube-plex https://ressu.github.io/kube-plex

kubectl create -f plex-pvc.yam (this is using cephfs that is not working.)

helm upgrade plex kube-plex \
    --namespace plex \
    --install \
    --set claimToken=[insert claim token here] \
    --set persistence.data.claimName=[existing-pms-data-pvc] \
    --set persistence.transcode.enabled=true \
    --set persistence.transcode.claimName=plex-pvc \
    --set ingress.enabled=true
```

## Deploying Plex

(Source)[https://www.debontonline.com/2021/01/part-14-deploy-plexserver-yaml-with.html]
### NFS Setup
```sh
sudo mkdir -p /mnt/plex-media
sudo mount /dev/sdb /mnt/plex-media

sudo chown nobody:nogroup /mnt/plex-media
sudo chmod 0777 /mnt/plex-media
echo '/srv/nfs 192.168.1.3/24(rw,sync,no_subtree_check)' | sudo tee /etc/exports
sudo exportfs -rav
sudo systemctl restart nfs-kernel-server

helm repo add csi-driver-nfs https://raw.githubusercontent.com/kubernetes-csi/csi-driver-nfs/master/charts
helm repo update
helm install csi-driver-nfs csi-driver-nfs/csi-driver-nfs --namespace kube-system --set kubeletDir=/var/lib/kubelet
```

## Deploying Kube-Plex

See (kube-plex)[https://github.com/mike-palacio-nice/kube-plex#readme]

## Deploying Kubernetes Dashboard
```sh
kubectl apply -f https://raw.githubusercontent.com/kubernetes/dashboard/v2.7.0/aio/deploy/recommended.yaml
```