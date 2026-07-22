#!/usr/bin/env bash
# setup-polaris.sh — Deploy PostgreSQL, Polaris Catalog, and configure the Iceberg catalog
# Idempotent: kubectl apply is safe to run multiple times; catalog creation is checked
# Usage: ./scripts/setup-polaris.sh [--dry-run]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TUTORIAL_DIR="$(dirname "$SCRIPT_DIR")"

DRY_RUN=false

if [[ "${1:-}" == "--dry-run" ]]; then
  DRY_RUN=true
  echo "[DRY RUN] Commands will be printed but not executed."
fi

# Cleanup function to kill port-forward on exit
cleanup_port_forward() {
  if [[ -n "${PF_PID:-}" ]]; then
    kill "$PF_PID" 2>/dev/null || true
    wait "$PF_PID" 2>/dev/null || true
  fi
}
trap cleanup_port_forward EXIT

echo "=== Setting up Polaris Catalog ==="

echo "Step 1: Creating Polaris namespace..."
if [[ "$DRY_RUN" == true ]]; then
  echo "  kubectl apply -f ${TUTORIAL_DIR}/manifests/polaris/namespace.yaml"
else
  kubectl apply -f "${TUTORIAL_DIR}/manifests/polaris/namespace.yaml"
fi

echo "Step 2: Deploying PostgreSQL for Polaris backend..."
if [[ "$DRY_RUN" == true ]]; then
  echo "  kubectl apply -f ${TUTORIAL_DIR}/manifests/polaris/postgres-secret.yaml"
  echo "  kubectl apply -f ${TUTORIAL_DIR}/manifests/polaris/postgres-pvc.yaml"
  echo "  kubectl apply -f ${TUTORIAL_DIR}/manifests/polaris/postgres-deployment.yaml"
  echo "  kubectl apply -f ${TUTORIAL_DIR}/manifests/polaris/postgres-service.yaml"
else
  kubectl apply -f "${TUTORIAL_DIR}/manifests/polaris/postgres-secret.yaml"
  kubectl apply -f "${TUTORIAL_DIR}/manifests/polaris/postgres-pvc.yaml"
  kubectl apply -f "${TUTORIAL_DIR}/manifests/polaris/postgres-deployment.yaml"
  kubectl apply -f "${TUTORIAL_DIR}/manifests/polaris/postgres-service.yaml"
fi

echo "Step 3: Waiting for PostgreSQL to be ready..."
if [[ "$DRY_RUN" == true ]]; then
  echo "  kubectl -n polaris wait --for=condition=Ready pod -l app=postgres --timeout=120s"
else
  kubectl -n polaris wait --for=condition=Ready pod -l app=postgres --timeout=120s
  echo "PostgreSQL is ready."
fi

echo "Step 4: Deploying Polaris Catalog server..."
if [[ "$DRY_RUN" == true ]]; then
  echo "  kubectl apply -f ${TUTORIAL_DIR}/manifests/polaris/polaris-secret.yaml"
  echo "  kubectl apply -f ${TUTORIAL_DIR}/manifests/polaris/polaris-deployment.yaml"
  echo "  kubectl apply -f ${TUTORIAL_DIR}/manifests/polaris/polaris-service.yaml"
else
  kubectl apply -f "${TUTORIAL_DIR}/manifests/polaris/polaris-secret.yaml"
  kubectl apply -f "${TUTORIAL_DIR}/manifests/polaris/polaris-deployment.yaml"
  kubectl apply -f "${TUTORIAL_DIR}/manifests/polaris/polaris-service.yaml"
fi

echo "Step 5: Waiting for Polaris pod to be ready..."
if [[ "$DRY_RUN" == true ]]; then
  echo "  kubectl -n polaris wait --for=condition=Ready pod -l app=polaris --timeout=120s"
else
  kubectl -n polaris wait --for=condition=Ready pod -l app=polaris --timeout=120s
  echo "Polaris is ready."
fi

echo "Step 6: Running Polaris bootstrap job..."
if [[ "$DRY_RUN" == true ]]; then
  echo "  kubectl apply -f ${TUTORIAL_DIR}/manifests/polaris/polaris-bootstrap-job.yaml"
  echo "  kubectl -n polaris wait --for=condition=Complete job/polaris-bootstrap --timeout=120s"
else
  kubectl apply -f "${TUTORIAL_DIR}/manifests/polaris/polaris-bootstrap-job.yaml"
  echo "Waiting for bootstrap job to complete..."
  kubectl -n polaris wait --for=condition=Complete job/polaris-bootstrap --timeout=120s
  echo "Bootstrap job completed."
fi

echo "Step 7: Creating spark_warehouse catalog via Polaris Management API..."
if [[ "$DRY_RUN" == true ]]; then
  echo "  kubectl port-forward -n polaris svc/polaris 8181:8181 8182:8182 &"
  echo "  curl -s http://localhost:8181/api/catalog/v1/oauth/tokens (get OAuth2 token)"
  echo "  curl -s -X POST http://localhost:8182/api/management/v1/catalogs (create catalog)"
  echo "  curl -s -X POST http://localhost:8182/api/management/v1/catalogs/spark_warehouse/catalog-roles (create catalog role)"
  echo "  curl -s -X PUT http://localhost:8182/api/management/v1/catalogs/spark_warehouse/catalog-roles/catalog_admin/grants (grant privileges)"
  echo "  curl -s -X PUT http://localhost:8182/api/management/v1/principal-roles/root/catalog-roles/spark_warehouse (assign catalog role)"
else
  # Kill any existing port-forward on these ports
  pkill -f "port-forward.*polaris.*8181" 2>/dev/null || true
  pkill -f "port-forward.*polaris.*8182" 2>/dev/null || true
  sleep 1

  kubectl port-forward -n polaris svc/polaris 8181:8181 8182:8182 &
  PF_PID=$!
  echo "  Port-forward started (PID: ${PF_PID}), waiting for ports..."
  sleep 5

  # Get OAuth2 token
  echo "  Obtaining OAuth2 token..."
  TOKEN=$(curl -s -f http://localhost:8181/api/catalog/v1/oauth/tokens \
    -d "grant_type=client_credentials&client_id=root&client_secret=s3cr3t&scope=PRINCIPAL_ROLE:ALL" \
    | jq -r .access_token)

  if [[ -z "$TOKEN" || "$TOKEN" == "null" ]]; then
    echo "ERROR: Failed to obtain OAuth2 token from Polaris."
    exit 1
  fi
  echo "  Token obtained successfully."

  # Create catalog (ignore error if already exists)
  echo "  Creating spark_warehouse catalog..."
  HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" -X POST \
    http://localhost:8182/api/management/v1/catalogs \
    -H "Authorization: Bearer ${TOKEN}" \
    -H "Content-Type: application/json" \
    -d '{
      "catalog": {
        "name": "spark_warehouse",
        "type": "INTERNAL",
        "properties": {
          "default-base-location": "s3://iceberg-warehouse/"
        },
        "storageConfigInfo": {
          "storageType": "S3",
          "allowedLocations": ["s3://iceberg-warehouse/"],
          "s3": {
            "endpoint": "http://minio.minio.svc.cluster.local:9000",
            "region": "us-east-1",
            "pathStyleAccess": true
          }
        }
      }
    }')

  if [[ "$HTTP_CODE" == "201" ]]; then
    echo "  Catalog 'spark_warehouse' created successfully."
  elif [[ "$HTTP_CODE" == "409" ]]; then
    echo "  Catalog 'spark_warehouse' already exists. Skipping creation."
  else
    echo "  WARNING: Catalog creation returned HTTP ${HTTP_CODE}."
  fi

  # Create catalog role (ignore error if already exists)
  echo "  Creating catalog_admin role..."
  HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" -X POST \
    "http://localhost:8182/api/management/v1/catalogs/spark_warehouse/catalog-roles" \
    -H "Authorization: Bearer ${TOKEN}" \
    -H "Content-Type: application/json" \
    -d '{"catalogRole": {"name": "catalog_admin"}}')

  if [[ "$HTTP_CODE" == "201" ]]; then
    echo "  Catalog role 'catalog_admin' created successfully."
  elif [[ "$HTTP_CODE" == "409" ]]; then
    echo "  Catalog role 'catalog_admin' already exists. Skipping creation."
  else
    echo "  WARNING: Catalog role creation returned HTTP ${HTTP_CODE}."
  fi

  # Grant CATALOG_MANAGE_CONTENT to the catalog role
  echo "  Granting CATALOG_MANAGE_CONTENT to catalog_admin..."
  curl -s -f -X PUT \
    "http://localhost:8182/api/management/v1/catalogs/spark_warehouse/catalog-roles/catalog_admin/grants" \
    -H "Authorization: Bearer ${TOKEN}" \
    -H "Content-Type: application/json" \
    -d '{"grant": {"type": "catalog", "privilege": "CATALOG_MANAGE_CONTENT"}}' \
    > /dev/null
  echo "  Grant applied."

  # Assign catalog role to the root principal's default principal role
  echo "  Assigning catalog_admin to root principal role..."
  curl -s -f -X PUT \
    "http://localhost:8182/api/management/v1/principal-roles/root/catalog-roles/spark_warehouse" \
    -H "Authorization: Bearer ${TOKEN}" \
    -H "Content-Type: application/json" \
    -d '{"catalogRole": {"name": "catalog_admin"}}' \
    > /dev/null
  echo "  Assignment complete."

  # Kill port-forward (trap will also clean up)
  kill "$PF_PID" 2>/dev/null || true
  wait "$PF_PID" 2>/dev/null || true
  unset PF_PID
fi

echo "Step 8: Verifying Polaris deployment..."
if [[ "$DRY_RUN" == true ]]; then
  echo "  kubectl -n polaris get pods"
else
  kubectl -n polaris get pods
fi

echo ""
echo "=== Polaris Catalog setup complete ==="
echo "  Namespace:   polaris"
echo "  PostgreSQL:  postgres.polaris.svc.cluster.local:5432"
echo "  Polaris:     http://polaris.polaris.svc.cluster.local:8181 (catalog API)"
echo "  Management:  http://polaris.polaris.svc.cluster.local:8182 (management API)"
echo "  Catalog:     spark_warehouse (INTERNAL, S3-backed via MinIO)"
echo "  Credentials: root / s3cr3t (OAuth2 client_credentials)"
