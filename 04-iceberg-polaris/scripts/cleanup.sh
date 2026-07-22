#!/usr/bin/env bash
# cleanup.sh — Delete the k3d cluster and optionally the k3s-nfs Docker image (full teardown)
# This removes all Kubernetes resources, the local registry, and the cluster
# Usage: ./scripts/cleanup.sh [--dry-run]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TUTORIAL_DIR="$(dirname "$SCRIPT_DIR")"

CLUSTER_NAME="spark-on-k8s-clstr"
K3S_NFS_IMAGE="k3s-nfs:v1.31.5-k3s1"
DRY_RUN=false

if [[ "${1:-}" == "--dry-run" ]]; then
  DRY_RUN=true
  echo "[DRY RUN] Commands will be printed but not executed."
fi

echo "=== Cleaning up Spark on Kubernetes (Iceberg + Polaris) environment ==="

echo "Step 1: Checking if cluster exists..."
if ! k3d cluster list 2>/dev/null | grep -q "${CLUSTER_NAME}"; then
  echo "Cluster '${CLUSTER_NAME}' does not exist. Nothing to clean up."
else
  echo "Step 2: Deleting k3d cluster '${CLUSTER_NAME}'..."
  echo "  This will remove all pods, services, volumes, and the local registry."
  if [[ "$DRY_RUN" == true ]]; then
    echo "  k3d cluster delete ${CLUSTER_NAME}"
  else
    k3d cluster delete "${CLUSTER_NAME}"

    # Verify deletion
    if k3d cluster list 2>/dev/null | grep -q "${CLUSTER_NAME}"; then
      echo "WARNING: Cluster still exists after deletion attempt."
      exit 1
    else
      echo "Cluster successfully deleted."
    fi
  fi
fi

echo "Step 3: Optionally removing k3s-nfs Docker image..."
if docker image inspect "${K3S_NFS_IMAGE}" &>/dev/null; then
  if [[ "$DRY_RUN" == true ]]; then
    echo "  docker rmi ${K3S_NFS_IMAGE}"
    echo "  (Image '${K3S_NFS_IMAGE}' would be removed)"
  else
    read -r -p "Remove k3s-nfs Docker image '${K3S_NFS_IMAGE}'? [y/N] " REPLY
    if [[ "${REPLY}" =~ ^[Yy]$ ]]; then
      docker rmi "${K3S_NFS_IMAGE}"
      echo "  Image removed."
    else
      echo "  Keeping image '${K3S_NFS_IMAGE}'."
    fi
  fi
else
  echo "  Image '${K3S_NFS_IMAGE}' not found. Nothing to remove."
fi

echo ""
echo "Step 4: Cleanup summary"
echo "=== Cleanup complete ==="
echo "  Cluster '${CLUSTER_NAME}' and all associated resources have been removed."
echo "  Removed namespaces: spark, minio, polaris (via cluster deletion)"
echo "  To recreate: ./scripts/setup-cluster.sh"
