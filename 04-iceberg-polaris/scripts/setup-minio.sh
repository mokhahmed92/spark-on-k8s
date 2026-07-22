#!/usr/bin/env bash
# setup-minio.sh — Deploy MinIO and create the iceberg-warehouse bucket
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

echo "Step 3: Creating iceberg-warehouse bucket..."
if [[ "$DRY_RUN" == true ]]; then
  echo "  kubectl exec -n minio deploy/minio -- sh -c \"mc alias set local http://localhost:9000 minioadmin minioadmin && mc mb --ignore-existing local/iceberg-warehouse\""
else
  kubectl exec -n minio deploy/minio -- sh -c "
    mc alias set local http://localhost:9000 minioadmin minioadmin &&
    mc mb --ignore-existing local/iceberg-warehouse
  "
  echo "Bucket created (or already exists)."
fi

echo "Step 4: Verifying bucket exists..."
if [[ "$DRY_RUN" == true ]]; then
  echo "  kubectl exec -n minio deploy/minio -- sh -c \"mc ls local/ | grep iceberg-warehouse\""
else
  if kubectl exec -n minio deploy/minio -- sh -c "mc alias set local http://localhost:9000 minioadmin minioadmin && mc ls local/" | grep -q "iceberg-warehouse"; then
    echo "Bucket 'iceberg-warehouse' verified."
  else
    echo "WARNING: Bucket 'iceberg-warehouse' not found."
    exit 1
  fi
fi

echo ""
echo "=== MinIO setup complete ==="
echo "  Namespace:  minio"
echo "  API:        http://minio.minio.svc.cluster.local:9000 (in-cluster)"
echo "  Console:    port-forward to 9001 or use k3d loadbalancer mapping"
echo "  Bucket:     iceberg-warehouse"
