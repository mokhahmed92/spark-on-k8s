#!/usr/bin/env bash
# build-image.sh — Build and push the custom Spark image to the local k3d registry
# Idempotent: rebuilds and re-pushes (overwriting the existing tag)
# Usage: ./scripts/build-image.sh [--dry-run]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TUTORIAL_DIR="$(dirname "$SCRIPT_DIR")"

IMAGE_TAG="localhost:5111/spark-custom:v1.0"
DOCKERFILE="${TUTORIAL_DIR}/code/Dockerfile"
BUILD_CONTEXT="${TUTORIAL_DIR}/code"
DRY_RUN=false

if [[ "${1:-}" == "--dry-run" ]]; then
  DRY_RUN=true
  echo "[DRY RUN] Commands will be printed but not executed."
fi

echo "=== Building custom Spark image ==="

echo "Step 1: Building Docker image..."
echo "  Image:      ${IMAGE_TAG}"
echo "  Dockerfile: ${DOCKERFILE}"
echo "  Context:    ${BUILD_CONTEXT}"
if [[ "$DRY_RUN" == true ]]; then
  echo "  docker build -t ${IMAGE_TAG} -f ${DOCKERFILE} ${BUILD_CONTEXT}"
else
  docker build -t "${IMAGE_TAG}" -f "${DOCKERFILE}" "${BUILD_CONTEXT}"
fi

echo "Step 2: Pushing image to local registry..."
if [[ "$DRY_RUN" == true ]]; then
  echo "  docker push ${IMAGE_TAG}"
else
  docker push "${IMAGE_TAG}"
fi

echo "Step 3: Verifying push..."
if [[ "$DRY_RUN" == true ]]; then
  echo "  curl -s http://localhost:5111/v2/spark-custom/tags/list"
else
  VERIFY=$(curl -s http://localhost:5111/v2/spark-custom/tags/list 2>/dev/null || true)
  if echo "$VERIFY" | grep -q "v1.0"; then
    echo "Image successfully pushed to registry."
  else
    echo "Image pushed successfully (verified by docker push exit code)."
  fi
fi

echo ""
echo "=== Image build complete ==="
echo "  Local tag:     ${IMAGE_TAG}"
echo "  In-cluster:    spark-registry:5111/spark-custom:v1.0"
echo "  Pull policy:   IfNotPresent"
