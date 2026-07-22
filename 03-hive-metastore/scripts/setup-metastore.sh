#!/usr/bin/env bash
# setup-metastore.sh — Deploy PostgreSQL and Hive Metastore
# Idempotent: kubectl apply is safe to run multiple times
# Usage: ./scripts/setup-metastore.sh [--dry-run]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TUTORIAL_DIR="$(dirname "$SCRIPT_DIR")"

DRY_RUN=false

if [[ "${1:-}" == "--dry-run" ]]; then
  DRY_RUN=true
  echo "[DRY RUN] Commands will be printed but not executed."
fi

echo "=== Setting up Hive Metastore ==="

echo "Step 1: Creating metastore namespace..."
if [[ "$DRY_RUN" == true ]]; then
  echo "  kubectl apply -f ${TUTORIAL_DIR}/manifests/metastore/namespace.yaml"
else
  kubectl apply -f "${TUTORIAL_DIR}/manifests/metastore/namespace.yaml"
fi

echo "Step 2: Creating PostgreSQL credentials secret..."
if [[ "$DRY_RUN" == true ]]; then
  echo "  kubectl apply -f ${TUTORIAL_DIR}/manifests/metastore/postgres-secret.yaml"
else
  kubectl apply -f "${TUTORIAL_DIR}/manifests/metastore/postgres-secret.yaml"
fi

echo "Step 3: Creating PostgreSQL PVC..."
if [[ "$DRY_RUN" == true ]]; then
  echo "  kubectl apply -f ${TUTORIAL_DIR}/manifests/metastore/postgres-pvc.yaml"
else
  kubectl apply -f "${TUTORIAL_DIR}/manifests/metastore/postgres-pvc.yaml"
fi

echo "Step 4: Deploying PostgreSQL..."
if [[ "$DRY_RUN" == true ]]; then
  echo "  kubectl apply -f ${TUTORIAL_DIR}/manifests/metastore/postgres-deployment.yaml"
  echo "  kubectl apply -f ${TUTORIAL_DIR}/manifests/metastore/postgres-service.yaml"
else
  kubectl apply -f "${TUTORIAL_DIR}/manifests/metastore/postgres-deployment.yaml"
  kubectl apply -f "${TUTORIAL_DIR}/manifests/metastore/postgres-service.yaml"
fi

echo "Step 5: Waiting for PostgreSQL to be ready..."
if [[ "$DRY_RUN" == true ]]; then
  echo "  kubectl -n metastore wait --for=condition=Ready pod -l app=postgres --timeout=120s"
else
  kubectl -n metastore wait --for=condition=Ready pod -l app=postgres --timeout=120s
  echo "PostgreSQL is ready."
fi

echo "Step 6: Creating Hive Metastore ConfigMap..."
if [[ "$DRY_RUN" == true ]]; then
  echo "  kubectl apply -f ${TUTORIAL_DIR}/manifests/metastore/hive-metastore-config.yaml"
else
  kubectl apply -f "${TUTORIAL_DIR}/manifests/metastore/hive-metastore-config.yaml"
fi

echo "Step 7: Deploying Hive Metastore (init: download PostgreSQL driver + schema init)..."
if [[ "$DRY_RUN" == true ]]; then
  echo "  kubectl apply -f ${TUTORIAL_DIR}/manifests/metastore/hive-metastore-deployment.yaml"
  echo "  kubectl apply -f ${TUTORIAL_DIR}/manifests/metastore/hive-metastore-service.yaml"
else
  kubectl apply -f "${TUTORIAL_DIR}/manifests/metastore/hive-metastore-deployment.yaml"
  kubectl apply -f "${TUTORIAL_DIR}/manifests/metastore/hive-metastore-service.yaml"
fi

echo "Step 8: Waiting for Hive Metastore to be ready..."
echo "  (This may take a few minutes on first run — downloading PostgreSQL driver + schema init)"
if [[ "$DRY_RUN" == true ]]; then
  echo "  kubectl -n metastore wait --for=condition=Ready pod -l app=hive-metastore --timeout=300s"
else
  kubectl -n metastore wait --for=condition=Ready pod -l app=hive-metastore --timeout=300s
  echo "Hive Metastore is ready."
fi

echo "Step 9: Verifying deployment..."
if [[ "$DRY_RUN" == true ]]; then
  echo "  kubectl -n metastore get pods"
else
  kubectl -n metastore get pods
fi

echo ""
echo "=== Hive Metastore setup complete ==="
echo "  Namespace:    metastore"
echo "  PostgreSQL:   postgres.metastore.svc.cluster.local:5432"
echo "  Database:     metastore_db (user: hive)"
echo "  Metastore:    thrift://hive-metastore.metastore.svc.cluster.local:9083"
echo "  Warehouse:    s3a://spark-data/warehouse (resolved by Spark pods via MinIO)"
