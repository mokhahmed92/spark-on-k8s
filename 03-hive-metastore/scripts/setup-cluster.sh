#!/usr/bin/env bash
# setup-cluster.sh — Create the k3d cluster for Spark on Kubernetes tutorials
# Idempotent: skips creation if cluster already exists
# Usage: ./scripts/setup-cluster.sh [--dry-run]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TUTORIAL_DIR="$(dirname "$SCRIPT_DIR")"

CLUSTER_NAME="spark-on-k8s-clstr"
CONFIG_FILE="${TUTORIAL_DIR}/manifests/k3d/cluster-config.yaml"
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

echo "Step 1: Creating k3d cluster with config from ${CONFIG_FILE}..."
if [[ "$DRY_RUN" == true ]]; then
  echo "  k3d cluster create --config ${CONFIG_FILE}"
else
  k3d cluster create --config "${CONFIG_FILE}"
fi

echo "Step 2: Verifying cluster nodes are ready..."
if [[ "$DRY_RUN" == true ]]; then
  echo "  kubectl get nodes"
else
  kubectl get nodes
  echo ""
  echo "Waiting for all nodes to be Ready..."
  kubectl wait --for=condition=Ready nodes --all --timeout=120s
fi

echo "Step 3: Verifying local registry is running..."
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
echo "  API:      https://127.0.0.1:6443"
