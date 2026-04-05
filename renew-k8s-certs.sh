#!/bin/bash

# Ensure the script is run as root
if [ "$EUID" -ne 0 ]; then 
  echo "Please run as root (use sudo)"
  exit 1
fi

echo "--- Starting Kubernetes Certificate Renewal ---"

# 1. Renew the certificates
echo "[1/4] Renewing all certificates via kubeadm..."
kubeadm certs renew all

# 2. Update the admin.conf for kubectl
echo "[2/4] Updating admin.conf and user kubeconfig..."
cp /etc/kubernetes/admin.conf $HOME/.kube/config
# Also update the non-root user config if it exists
USER_HOME=$(getent passwd $SUDO_USER | cut -d: -f6)
if [ -d "$USER_HOME/.kube" ]; then
    cp /etc/kubernetes/admin.conf "$USER_HOME/.kube/config"
    chown $(id -u $SUDO_USER):$(id -g $SUDO_USER) "$USER_HOME/.kube/config"
    echo "Updated kubeconfig for user: $SUDO_USER"
fi

# 3. Restart Kubelet to pick up new certs
echo "[3/4] Restarting Kubelet..."
systemctl restart kubelet

# 4. Wait for API Server to come back online
echo "[4/4] Waiting for API server to stabilize (30s)..."
sleep 30

# Final check
echo "--- Post-Renewal Status ---"
kubeadm certs check-expiration
kubectl get nodes
