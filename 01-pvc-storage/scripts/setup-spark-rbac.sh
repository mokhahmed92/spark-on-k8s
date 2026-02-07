#!/usr/bin/env bash
# setup-spark-rbac.sh — Create the Spark namespace, ServiceAccount, Role, and RoleBinding
# Idempotent: kubectl apply is safe to run multiple times
# Usage: ./scripts/setup-spark-rbac.sh [--dry-run]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TUTORIAL_DIR="$(dirname "$SCRIPT_DIR")"

DRY_RUN=false

if [[ "${1:-}" == "--dry-run" ]]; then
  DRY_RUN=true
  echo "[DRY RUN] Commands will be printed but not executed."
fi

echo "=== Setting up Spark RBAC ==="

echo "Step 1: Creating Spark namespace..."
if [[ "$DRY_RUN" == true ]]; then
  echo "  kubectl apply -f ${TUTORIAL_DIR}/manifests/spark/namespace.yaml"
else
  kubectl apply -f "${TUTORIAL_DIR}/manifests/spark/namespace.yaml"
fi

echo "Step 2: Creating ServiceAccount, Role, and RoleBinding..."
if [[ "$DRY_RUN" == true ]]; then
  echo "  kubectl apply -f ${TUTORIAL_DIR}/manifests/spark/rbac.yaml"
else
  kubectl apply -f "${TUTORIAL_DIR}/manifests/spark/rbac.yaml"
fi

echo "Step 3: Verifying resources..."
if [[ "$DRY_RUN" == true ]]; then
  echo "  kubectl -n spark get sa,role,rolebinding"
else
  kubectl -n spark get sa,role,rolebinding
fi

echo ""
echo "=== Spark RBAC setup complete ==="
echo "  Namespace:       spark"
echo "  ServiceAccount:  spark"
echo "  Role:            spark-role"
echo "  RoleBinding:     spark-role-binding"
