#!/usr/bin/env bash
# setup-minio.sh — Deploy MinIO and create required buckets
# Idempotent: applies manifests (kubectl apply is idempotent) and checks existing buckets
# Usage: ./scripts/setup-minio.sh [--dry-run]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TUTORIAL_DIR="$(dirname "$SCRIPT_DIR")"

DRY_RUN=false

if [[ "${1:-}" == "--dry-run" ]]; then
  DRY_RUN=true
  echo "[DRY RUN] Commands will be printed but not executed."
fi

echo "=== Setting up MinIO ==="

echo "Step 1: Applying MinIO manifests..."
if [[ "$DRY_RUN" == true ]]; then
  echo "  kubectl apply -f ${TUTORIAL_DIR}/manifests/minio/"
else
  kubectl apply -f "${TUTORIAL_DIR}/manifests/minio/"
fi

echo "Step 2: Waiting for MinIO pod to be ready..."
if [[ "$DRY_RUN" == true ]]; then
  echo "  kubectl -n minio wait --for=condition=Ready pod -l app=minio --timeout=120s"
else
  kubectl -n minio wait --for=condition=Ready pod -l app=minio --timeout=120s
  echo "MinIO pod is ready."
fi

echo "Step 3: Setting up port-forward for bucket creation..."
if [[ "$DRY_RUN" == true ]]; then
  echo "  kubectl -n minio port-forward svc/minio 9000:9000 &"
  echo "  mc alias set local http://localhost:9000 minioadmin minioadmin123"
else
  # Kill any existing port-forward on port 9000
  pkill -f "port-forward.*minio.*9000" 2>/dev/null || true
  sleep 1

  kubectl -n minio port-forward svc/minio 9000:9000 &
  PF_PID=$!
  sleep 3

  # Configure mc alias
  mc alias set local http://localhost:9000 minioadmin minioadmin123
fi

echo "Step 4: Creating buckets..."
if [[ "$DRY_RUN" == true ]]; then
  echo "  mc mb --ignore-existing local/spark-data"
  echo "  mc mb --ignore-existing local/spark-logs"
else
  mc mb --ignore-existing local/spark-data
  mc mb --ignore-existing local/spark-logs
  echo "Buckets created."
fi

echo "Step 5: Uploading sample input data..."
if [[ "$DRY_RUN" == true ]]; then
  echo "  mc cp ${TUTORIAL_DIR}/code/data/sample-input.txt local/spark-data/input/"
else
  mc cp "${TUTORIAL_DIR}/code/data/sample-input.txt" local/spark-data/input/
  echo "Sample data uploaded."
fi

echo "Step 6: Verifying setup..."
if [[ "$DRY_RUN" == true ]]; then
  echo "  mc ls local/spark-data/input/"
  echo "  mc ls local/spark-logs/"
else
  echo "Buckets:"
  mc ls local/
  echo ""
  echo "Input data:"
  mc ls local/spark-data/input/

  # Clean up port-forward
  kill $PF_PID 2>/dev/null || true
fi

echo ""
echo "=== MinIO setup complete ==="
echo "  Namespace:  minio"
echo "  API:        http://minio.minio.svc.cluster.local:9000 (in-cluster)"
echo "  Console:    port-forward to 9001 or use k3d loadbalancer mapping"
echo "  Buckets:    spark-data, spark-logs"
