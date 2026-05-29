#!/bin/bash
set -e

CLUSTER_NAME="${1:-pipeline-lab}"

# Write kubeconfig to a stable location
KUBECONFIG_DIR="${HOME}/.kube"
KUBECONFIG_FILE="${KUBECONFIG_DIR}/config"
mkdir -p "$KUBECONFIG_DIR"

k3d kubeconfig write "$CLUSTER_NAME" --output "$KUBECONFIG_FILE" --overwrite

# Patch to use k3d load balancer hostname (stable across server restarts)
LB_HOST="k3d-${CLUSTER_NAME}-serverlb"
sed -i "s|https://0.0.0.0:[0-9]*|https://${LB_HOST}:6443|" "$KUBECONFIG_FILE"

echo "Kubeconfig written: ${KUBECONFIG_FILE}"
echo "Server: https://${LB_HOST}:6443"
kubectl get nodes
