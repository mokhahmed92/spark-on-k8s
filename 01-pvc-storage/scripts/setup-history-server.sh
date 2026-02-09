#!/usr/bin/env bash
# setup-history-server.sh — Deploy the PVC-backed Spark History Server
# Idempotent: kubectl apply is safe to run multiple times
# Usage: ./scripts/setup-history-server.sh [--dry-run]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TUTORIAL_DIR="$(dirname "$SCRIPT_DIR")"

DRY_RUN=false

if [[ "${1:-}" == "--dry-run" ]]; then
  DRY_RUN=true
  echo "[DRY RUN] Commands will be printed but not executed."
fi

echo "=== Setting up Spark History Server (PVC-backed) ==="

echo "Step 1: Deploying NFS provisioner (required for RWX PVCs)..."
if [[ "$DRY_RUN" == true ]]; then
  echo "  kubectl apply -f ${TUTORIAL_DIR}/manifests/storage/nfs-provisioner.yaml"
  echo "  kubectl -n nfs-provisioner wait --for=condition=Ready pod -l app=nfs-provisioner --timeout=120s"
else
  kubectl apply -f "${TUTORIAL_DIR}/manifests/storage/nfs-provisioner.yaml"
  echo "Waiting for NFS provisioner pod to be ready..."
  kubectl -n nfs-provisioner wait --for=condition=Ready pod -l app=nfs-provisioner --timeout=120s
  echo "NFS provisioner is ready."
fi

echo "Step 2: Creating event logs PVC..."
if [[ "$DRY_RUN" == true ]]; then
  echo "  kubectl apply -f ${TUTORIAL_DIR}/manifests/history-server/pvc.yaml"
else
  kubectl apply -f "${TUTORIAL_DIR}/manifests/history-server/pvc.yaml"
fi

echo "Step 3: Creating History Server ConfigMap..."
if [[ "$DRY_RUN" == true ]]; then
  echo "  kubectl apply -f ${TUTORIAL_DIR}/manifests/history-server/config.yaml"
else
  kubectl apply -f "${TUTORIAL_DIR}/manifests/history-server/config.yaml"
fi

echo "Step 4: Deploying History Server..."
if [[ "$DRY_RUN" == true ]]; then
  echo "  kubectl apply -f ${TUTORIAL_DIR}/manifests/history-server/deployment.yaml"
else
  kubectl apply -f "${TUTORIAL_DIR}/manifests/history-server/deployment.yaml"
fi

echo "Step 5: Creating History Server service..."
if [[ "$DRY_RUN" == true ]]; then
  echo "  kubectl apply -f ${TUTORIAL_DIR}/manifests/history-server/service.yaml"
else
  kubectl apply -f "${TUTORIAL_DIR}/manifests/history-server/service.yaml"
fi

echo "Step 6: Waiting for History Server pod to be ready..."
if [[ "$DRY_RUN" == true ]]; then
  echo "  kubectl -n spark wait --for=condition=Ready pod -l app=spark-history-server --timeout=120s"
else
  kubectl -n spark wait --for=condition=Ready pod -l app=spark-history-server --timeout=120s
  echo "History Server is ready."
fi

echo "Step 7: Verifying deployment..."
if [[ "$DRY_RUN" == true ]]; then
  echo "  kubectl -n spark get pods -l app=spark-history-server"
else
  kubectl -n spark get pods -l app=spark-history-server
fi

echo ""
echo "=== History Server (PVC) setup complete ==="
echo "  Namespace:  spark"
echo "  Event logs: file:///mnt/spark-events (from spark-events-pvc)"
echo "  Access UI:  kubectl -n spark port-forward svc/spark-history-server 18080:18080"
echo "  URL:        http://localhost:18080"
