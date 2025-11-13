#!/bin/bash
#
# WSL Installation Script for Spark-on-K8s
# Workaround for Windows Helm path issues in WSL
#

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Default values
ENVIRONMENT="${1:-prod}"
RELEASE_NAME="${2:-spark-platform}"
NAMESPACE="${3:-spark-operator}"

echo -e "${CYAN}============================================${NC}"
echo -e "${CYAN}Spark-on-K8s Helm Chart Installation${NC}"
echo -e "${CYAN}WSL Compatible Version${NC}"
echo -e "${CYAN}============================================${NC}"
echo ""
echo -e "Release: ${YELLOW}${RELEASE_NAME}${NC}"
echo -e "Namespace: ${YELLOW}${NAMESPACE}${NC}"
echo -e "Environment: ${YELLOW}${ENVIRONMENT}${NC}"
echo ""

# Check if values file exists
VALUES_FILE="values-${ENVIRONMENT}.yaml"
if [ ! -f "$VALUES_FILE" ]; then
    echo -e "${RED}Error: Values file not found: ${VALUES_FILE}${NC}"
    echo "Available values files:"
    ls -1 values-*.yaml
    exit 1
fi

# Get script directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
echo -e "Working directory: ${SCRIPT_DIR}"
echo ""

# Create temp directory
TEMP_DIR=$(mktemp -d)
echo -e "Temporary directory: ${TEMP_DIR}"
echo ""

# Cleanup function
cleanup() {
    if [ -d "$TEMP_DIR" ]; then
        echo -e "${CYAN}Cleaning up temporary files...${NC}"
        rm -rf "$TEMP_DIR"
    fi
}
trap cleanup EXIT

# Copy files to temp
echo -e "${CYAN}[Step 1/5] Preparing installation...${NC}"
cp "$SCRIPT_DIR/Chart.yaml" "$TEMP_DIR/"
cp "$SCRIPT_DIR/$VALUES_FILE" "$TEMP_DIR/"
cp -r "$SCRIPT_DIR/templates" "$TEMP_DIR/"
[ -f "$SCRIPT_DIR/.helmignore" ] && cp "$SCRIPT_DIR/.helmignore" "$TEMP_DIR/" || true
mkdir -p "$TEMP_DIR/charts"
echo -e "${GREEN}✓ Files prepared${NC}"
echo ""

# Add Helm repositories
echo -e "${CYAN}[Step 2/5] Adding Helm repositories...${NC}"
helm repo add spark-operator https://kubeflow.github.io/spark-operator 2>/dev/null || true
helm repo add volcano-sh https://volcano-sh.github.io/helm-charts 2>/dev/null || true
helm repo update >/dev/null 2>&1
echo -e "${GREEN}✓ Repositories added${NC}"
echo ""

# Build dependencies
echo -e "${CYAN}[Step 3/5] Building chart dependencies...${NC}"
echo "  This may take a minute..."
cd "$TEMP_DIR"
if ! helm dependency build 2>&1; then
    echo -e "${RED}✗ Failed to build dependencies${NC}"
    exit 1
fi
echo -e "${GREEN}✓ Dependencies built${NC}"
echo ""

# Validate chart
echo -e "${CYAN}[Step 4/5] Validating chart...${NC}"
if helm lint . --values "$VALUES_FILE" 2>&1 | grep -q "ERROR"; then
    echo -e "${YELLOW}⚠ Chart has validation warnings (non-fatal)${NC}"
else
    echo -e "${GREEN}✓ Chart validated${NC}"
fi
echo ""

# Check if release exists
echo -e "${CYAN}[Step 5/5] Installing chart...${NC}"
if helm list -n "$NAMESPACE" 2>/dev/null | grep -q "^${RELEASE_NAME}"; then
    echo -e "${YELLOW}Release '${RELEASE_NAME}' already exists in namespace '${NAMESPACE}'${NC}"
    read -p "Do you want to upgrade it? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        ACTION="upgrade"
    else
        echo -e "${YELLOW}Installation cancelled.${NC}"
        exit 0
    fi
else
    ACTION="install"
fi

# Install or upgrade
echo ""
echo -e "  Action: ${ACTION}"
echo -e "  Release: ${RELEASE_NAME}"
echo -e "  Namespace: ${NAMESPACE}"
echo -e "  Values: ${VALUES_FILE}"
echo ""

if [ "$ACTION" = "install" ]; then
    if helm install "$RELEASE_NAME" . \
        --namespace "$NAMESPACE" \
        --create-namespace \
        --values "$VALUES_FILE" \
        --wait \
        --timeout 10m; then
        SUCCESS=true
    else
        SUCCESS=false
    fi
else
    if helm upgrade "$RELEASE_NAME" . \
        --namespace "$NAMESPACE" \
        --values "$VALUES_FILE" \
        --wait \
        --timeout 10m; then
        SUCCESS=true
    else
        SUCCESS=false
    fi
fi

echo ""
if [ "$SUCCESS" = true ]; then
    echo -e "${GREEN}============================================${NC}"
    echo -e "${GREEN}✓ ${ACTION^} Successful!${NC}"
    echo -e "${GREEN}============================================${NC}"
    echo ""
    echo -e "${CYAN}Installation Details:${NC}"
    echo -e "  Release: ${RELEASE_NAME}"
    echo -e "  Namespace: ${NAMESPACE}"
    echo -e "  Environment: ${ENVIRONMENT}"
    echo ""
    echo -e "${CYAN}Next Steps:${NC}"
    echo ""
    echo -e "${YELLOW}1.${NC} Check installation status:"
    echo "   helm status ${RELEASE_NAME} -n ${NAMESPACE}"
    echo ""
    echo -e "${YELLOW}2.${NC} Verify pods are running:"
    echo "   kubectl get pods -n ${NAMESPACE}"
    if [ "$ENVIRONMENT" = "prod" ]; then
        echo "   kubectl get pods -n volcano-system"
    fi
    echo ""
    echo -e "${YELLOW}3.${NC} Check team namespaces:"
    echo "   kubectl get namespaces | grep team-"
    echo ""
    echo -e "${YELLOW}4.${NC} View Spark applications:"
    echo "   kubectl get sparkapplications -A"
    echo ""
    if [ "$ENVIRONMENT" = "prod" ]; then
        echo -e "${YELLOW}5.${NC} Check Volcano queues:"
        echo "   kubectl get queues"
        echo ""
    fi
else
    echo -e "${RED}============================================${NC}"
    echo -e "${RED}✗ ${ACTION^} Failed${NC}"
    echo -e "${RED}============================================${NC}"
    echo ""
    echo -e "${CYAN}Troubleshooting:${NC}"
    echo ""
    echo -e "${YELLOW}1.${NC} Check cluster accessibility:"
    echo "   kubectl cluster-info"
    echo ""
    echo -e "${YELLOW}2.${NC} Check Helm version:"
    echo "   helm version"
    echo ""
    echo -e "${YELLOW}3.${NC} Verify repositories:"
    echo "   helm repo list"
    echo ""
    exit 1
fi
