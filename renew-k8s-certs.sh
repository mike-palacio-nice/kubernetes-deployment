#!/bin/bash

# Ensure the script is run as root
if [ "$EUID" -ne 0 ]; then 
  echo "Please run as root (use sudo)"
  exit 1
fi

echo "--- Starting Kubernetes Certificate Renewal ---"

# 1. Ensure crictl is pointing to the correct containerd socket
if [ ! -f /etc/crictl.yaml ]; then
    echo "[!] Creating crictl config for containerd..."
    cat <<EOF > /etc/crictl.yaml
runtime-endpoint: unix:///run/containerd/containerd.sock
image-endpoint: unix:///run/containerd/containerd.sock
EOF
fi

# 2. Renew the certificates
echo "[1/5] Renewing all certificates via kubeadm..."
kubeadm certs renew all

# 3. Update the admin.conf for kubectl
echo "[2/5] Updating admin.conf and user kubeconfig..."
cp /etc/kubernetes/admin.conf $HOME/.kube/config
USER_HOME=$(getent passwd $SUDO_USER | cut -d: -f6)
if [ -d "$USER_HOME/.kube" ]; then
    cp /etc/kubernetes/admin.conf "$USER_HOME/.kube/config"
    chown $(id -u $SUDO_USER):$(id -g $SUDO_USER) "$USER_HOME/.kube/config"
fi

# 4. Restart Kubelet
echo "[3/5] Restarting Kubelet..."
systemctl restart kubelet

# 5. Force-restart the Control Plane "Brains" (API, Controller, Scheduler)
# We stop them; Kubelet will immediately restart them with new certs.
echo "[4/5] Bouncing Control Plane components to refresh TLS sessions..."
COMPONENTS=("kube-apiserver" "kube-controller-manager" "kube-scheduler" "etcd")

for COMP in "${COMPONENTS[@]}"; do
    ID=$(crictl ps --name "$COMP" -q)
    if [ ! -z "$ID" ]; then
        echo "Restarting $COMP ($ID)..."
        crictl stop "$ID" > /dev/null
    fi
done

# 6. Wait for API Server to come back online
echo "[5/5] Waiting 30s for the cluster to stabilize..."
sleep 30

# Final check
echo "--- Post-Renewal Status ---"
kubeadm certs check-expiration
kubectl get nodes