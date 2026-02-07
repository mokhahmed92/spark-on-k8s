#!/usr/bin/env bash
# cleanup.sh — Delete the k3d cluster (full teardown)
# This removes all Kubernetes resources, the local registry, and the cluster
# Usage: ./scripts/cleanup.sh [--dry-run]

set -euo pipefail

CLUSTER_NAME="spark-on-k8s-clstr"
DRY_RUN=false

if [[ "${1:-}" == "--dry-run" ]]; then
  DRY_RUN=true
  echo "[DRY RUN] Commands will be printed but not executed."
fi

echo "=== Cleaning up Spark on Kubernetes environment ==="

# Check if cluster exists
if ! k3d cluster list 2>/dev/null | grep -q "${CLUSTER_NAME}"; then
  echo "Cluster '${CLUSTER_NAME}' does not exist. Nothing to clean up."
  exit 0
fi

echo "Step 1: Deleting k3d cluster '${CLUSTER_NAME}'..."
echo "  This will remove all pods, services, volumes, and the local registry."
if [[ "$DRY_RUN" == true ]]; then
  echo "  k3d cluster delete ${CLUSTER_NAME}"
else
  k3d cluster delete "${CLUSTER_NAME}"
fi

echo "Step 2: Verifying cleanup..."
if [[ "$DRY_RUN" == true ]]; then
  echo "  k3d cluster list"
else
  if k3d cluster list 2>/dev/null | grep -q "${CLUSTER_NAME}"; then
    echo "WARNING: Cluster still exists after deletion attempt."
    exit 1
  else
    echo "Cluster successfully deleted."
  fi
fi

echo ""
echo "=== Cleanup complete ==="
echo "  Cluster '${CLUSTER_NAME}' and all associated resources have been removed."
echo "  To recreate: ./scripts/setup-cluster.sh"
