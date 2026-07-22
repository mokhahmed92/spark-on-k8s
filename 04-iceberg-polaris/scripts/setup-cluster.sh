#!/usr/bin/env bash
# setup-cluster.sh — Create the k3d cluster for Spark on Kubernetes (Iceberg + Polaris)
# Idempotent: skips creation if cluster already exists
# Usage: ./scripts/setup-cluster.sh [--dry-run]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TUTORIAL_DIR="$(dirname "$SCRIPT_DIR")"

CLUSTER_NAME="spark-on-k8s-clstr"
CONFIG_FILE="${TUTORIAL_DIR}/manifests/k3d/cluster-config.yaml"
K3S_NFS_IMAGE="k3s-nfs:v1.31.5-k3s1"
K3S_NFS_DOCKERFILE="${TUTORIAL_DIR}/manifests/k3d/Dockerfile.k3s-nfs"
K3S_NFS_CONTEXT="${TUTORIAL_DIR}/manifests/k3d"
DRY_RUN=false

if [[ "${1:-}" == "--dry-run" ]]; then
  DRY_RUN=true
  echo "[DRY RUN] Commands will be printed but not executed."
fi

echo "=== Setting up k3d cluster: ${CLUSTER_NAME} ==="

# Check if cluster already exists
if k3d cluster list 2>/dev/null | grep -q "${CLUSTER_NAME}"; then
  echo "Cluster '${CLUSTER_NAME}' already exists. Skipping creation."
  kubectl get nodes
  exit 0
fi

echo "Step 1: Ensuring custom k3s-nfs node image exists..."
echo "  (Default k3s images lack NFS client tools needed for RWX PVCs)"
if [[ "$DRY_RUN" == true ]]; then
  echo "  docker build -t ${K3S_NFS_IMAGE} -f ${K3S_NFS_DOCKERFILE} ${K3S_NFS_CONTEXT}"
else
  if docker image inspect "${K3S_NFS_IMAGE}" &>/dev/null; then
    echo "  Image '${K3S_NFS_IMAGE}' already exists. Skipping build."
  else
    echo "  Building ${K3S_NFS_IMAGE}..."
    docker build -t "${K3S_NFS_IMAGE}" -f "${K3S_NFS_DOCKERFILE}" "${K3S_NFS_CONTEXT}"
  fi
fi

echo "Step 2: Creating k3d cluster with config from ${CONFIG_FILE}..."
if [[ "$DRY_RUN" == true ]]; then
  echo "  k3d cluster create --config ${CONFIG_FILE}"
else
  k3d cluster create --config "${CONFIG_FILE}"
fi

echo "Step 3: Verifying cluster nodes are ready..."
if [[ "$DRY_RUN" == true ]]; then
  echo "  kubectl wait --for=condition=Ready nodes --all --timeout=120s"
else
  kubectl get nodes
  echo ""
  echo "Waiting for all nodes to be Ready..."
  kubectl wait --for=condition=Ready nodes --all --timeout=120s
fi

echo "Step 4: Deploying NFS provisioner for ReadWriteMany PVCs..."
if [[ "$DRY_RUN" == true ]]; then
  echo "  kubectl apply -f ${TUTORIAL_DIR}/manifests/storage/nfs-provisioner.yaml"
  echo "  kubectl -n nfs-provisioner wait --for=condition=Ready pod -l app=nfs-provisioner --timeout=120s"
else
  kubectl apply -f "${TUTORIAL_DIR}/manifests/storage/nfs-provisioner.yaml"
  echo "  Waiting for NFS provisioner pod to be ready..."
  kubectl -n nfs-provisioner wait --for=condition=Ready pod -l app=nfs-provisioner --timeout=120s
  echo "  NFS provisioner is ready."
fi

echo "Step 5: Verifying local registry is running..."
if [[ "$DRY_RUN" == true ]]; then
  echo "  docker ps --filter name=spark-registry"
else
  docker ps --filter "name=spark-registry" --format "table {{.Names}}\t{{.Ports}}\t{{.Status}}"
fi

echo ""
echo "=== Cluster setup complete ==="
echo "  Cluster:  ${CLUSTER_NAME}"
echo "  Nodes:    1 server + 3 agents"
echo "  Registry: localhost:5111 (spark-registry)"
echo "  NFS:      StorageClass 'nfs' (ReadWriteMany support)"
echo "  API:      https://127.0.0.1:6443"
