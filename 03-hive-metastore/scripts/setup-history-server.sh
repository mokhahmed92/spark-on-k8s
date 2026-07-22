#!/usr/bin/env bash
# setup-history-server.sh — Deploy the S3-backed Spark History Server
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

echo "=== Setting up Spark History Server (S3-backed) ==="

echo "Step 1: Creating History Server S3 ConfigMap..."
if [[ "$DRY_RUN" == true ]]; then
  echo "  kubectl apply -f ${TUTORIAL_DIR}/manifests/history-server/config.yaml"
else
  kubectl apply -f "${TUTORIAL_DIR}/manifests/history-server/config.yaml"
fi

echo "Step 2: Deploying History Server (S3 variant)..."
if [[ "$DRY_RUN" == true ]]; then
  echo "  kubectl apply -f ${TUTORIAL_DIR}/manifests/history-server/deployment.yaml"
else
  kubectl apply -f "${TUTORIAL_DIR}/manifests/history-server/deployment.yaml"
fi

echo "Step 3: Creating History Server service..."
if [[ "$DRY_RUN" == true ]]; then
  echo "  kubectl apply -f ${TUTORIAL_DIR}/manifests/history-server/service.yaml"
else
  kubectl apply -f "${TUTORIAL_DIR}/manifests/history-server/service.yaml"
fi

echo "Step 4: Waiting for History Server pod to be ready..."
if [[ "$DRY_RUN" == true ]]; then
  echo "  kubectl -n spark wait --for=condition=Ready pod -l app=spark-history-server --timeout=120s"
else
  kubectl -n spark wait --for=condition=Ready pod -l app=spark-history-server --timeout=120s
  echo "History Server is ready."
fi

echo "Step 5: Verifying deployment..."
if [[ "$DRY_RUN" == true ]]; then
  echo "  kubectl -n spark get pods -l app=spark-history-server"
else
  kubectl -n spark get pods -l app=spark-history-server
fi

echo ""
echo "=== History Server (S3) setup complete ==="
echo "  Namespace:  spark"
echo "  Event logs: s3a://spark-logs/event-logs/ (via MinIO)"
echo "  Access UI:  kubectl -n spark port-forward svc/spark-history-server 18080:18080"
echo "  URL:        http://localhost:18080"
