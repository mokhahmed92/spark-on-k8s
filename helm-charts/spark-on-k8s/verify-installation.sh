#!/bin/bash
#
# Spark-on-K8s Installation Verification Script
# Verifies that all components are properly deployed and functioning
#

set -e

RELEASE_NAME="${1:-spark-platform}"
NAMESPACE="${2:-spark-operator}"

echo "=========================================="
echo "Spark-on-K8s Installation Verification"
echo "=========================================="
echo "Release: $RELEASE_NAME"
echo "Namespace: $NAMESPACE"
echo ""

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check functions
check_passed() {
    echo -e "${GREEN}✓${NC} $1"
}

check_failed() {
    echo -e "${RED}✗${NC} $1"
}

check_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

# 1. Check Helm release
echo "1. Checking Helm release..."
if helm list -n $NAMESPACE | grep -q $RELEASE_NAME; then
    check_passed "Helm release '$RELEASE_NAME' found in namespace '$NAMESPACE'"
    RELEASE_STATUS=$(helm status $RELEASE_NAME -n $NAMESPACE -o json | jq -r '.info.status')
    if [ "$RELEASE_STATUS" = "deployed" ]; then
        check_passed "Release status: deployed"
    else
        check_failed "Release status: $RELEASE_STATUS"
    fi
else
    check_failed "Helm release '$RELEASE_NAME' not found"
    exit 1
fi
echo ""

# 2. Check Spark Operator
echo "2. Checking Spark Operator..."
if kubectl get deployment -n $NAMESPACE | grep -q "spark-operator"; then
    check_passed "Spark Operator deployment found"

    READY_REPLICAS=$(kubectl get deployment -n $NAMESPACE -l app.kubernetes.io/name=spark-operator -o jsonpath='{.items[0].status.readyReplicas}')
    DESIRED_REPLICAS=$(kubectl get deployment -n $NAMESPACE -l app.kubernetes.io/name=spark-operator -o jsonpath='{.items[0].status.replicas}')

    if [ "$READY_REPLICAS" = "$DESIRED_REPLICAS" ]; then
        check_passed "Spark Operator pods ready: $READY_REPLICAS/$DESIRED_REPLICAS"
    else
        check_failed "Spark Operator pods not ready: $READY_REPLICAS/$DESIRED_REPLICAS"
    fi
else
    check_failed "Spark Operator deployment not found"
fi
echo ""

# 3. Check team namespaces
echo "3. Checking team namespaces..."
EXPECTED_TEAMS=("team-alpha" "team-beta" "team-theta" "team-delta" "ds-team-ns" "de-team-ns")
for team in "${EXPECTED_TEAMS[@]}"; do
    if kubectl get namespace $team &>/dev/null; then
        check_passed "Namespace '$team' exists"
    else
        check_warning "Namespace '$team' not found (may not be configured)"
    fi
done
echo ""

# 4. Check service accounts
echo "4. Checking service accounts..."
EXPECTED_SAS=("team-alpha-sa" "team-beta-sa" "team-theta-sa" "team-delta-sa" "ds-team-sa" "de-team-sa")
TEAMS=("team-alpha" "team-beta" "team-theta" "team-delta" "ds-team-ns" "de-team-ns")
for i in "${!TEAMS[@]}"; do
    team="${TEAMS[$i]}"
    sa="${EXPECTED_SAS[$i]}"
    if kubectl get namespace $team &>/dev/null; then
        if kubectl get serviceaccount $sa -n $team &>/dev/null; then
            check_passed "ServiceAccount '$sa' exists in '$team'"
        else
            check_failed "ServiceAccount '$sa' not found in '$team'"
        fi
    fi
done
echo ""

# 5. Check resource quotas
echo "5. Checking resource quotas..."
for team in team-alpha team-beta team-theta team-delta; do
    if kubectl get namespace $team &>/dev/null; then
        if kubectl get resourcequota -n $team &>/dev/null; then
            QUOTA_COUNT=$(kubectl get resourcequota -n $team --no-headers 2>/dev/null | wc -l)
            if [ "$QUOTA_COUNT" -gt 0 ]; then
                check_passed "ResourceQuota found in '$team'"
            else
                check_warning "No ResourceQuota in '$team'"
            fi
        else
            check_warning "No ResourceQuota in '$team'"
        fi
    fi
done
echo ""

# 6. Check Volcano (if enabled)
echo "6. Checking Volcano scheduler..."
if kubectl get namespace volcano-system &>/dev/null; then
    check_passed "Volcano namespace exists"

    VOLCANO_SCHEDULER=$(kubectl get pods -n volcano-system -l app=volcano-scheduler --no-headers 2>/dev/null | wc -l)
    if [ "$VOLCANO_SCHEDULER" -gt 0 ]; then
        check_passed "Volcano scheduler pod(s) running"
    else
        check_failed "Volcano scheduler not running"
    fi
else
    check_warning "Volcano not installed (optional for default scheduler teams)"
fi
echo ""

# 7. Check Volcano queues (if Volcano is installed)
if kubectl get namespace volcano-system &>/dev/null; then
    echo "7. Checking Volcano queues..."
    EXPECTED_QUEUES=("queue-theta" "queue-delta" "batch-jobs-queue" "default")
    for queue in "${EXPECTED_QUEUES[@]}"; do
        if kubectl get queue $queue &>/dev/null; then
            check_passed "Queue '$queue' exists"
        else
            check_warning "Queue '$queue' not found (may not be configured)"
        fi
    done
    echo ""
fi

# 8. Check RBAC
echo "8. Checking RBAC resources..."
for team in team-alpha team-beta team-theta team-delta ds-team-ns de-team-ns; do
    if kubectl get namespace $team &>/dev/null; then
        ROLES=$(kubectl get roles -n $team --no-headers 2>/dev/null | wc -l)
        ROLEBINDINGS=$(kubectl get rolebindings -n $team --no-headers 2>/dev/null | wc -l)

        if [ "$ROLES" -gt 0 ] && [ "$ROLEBINDINGS" -gt 0 ]; then
            check_passed "RBAC resources found in '$team'"
        else
            check_failed "Missing RBAC resources in '$team'"
        fi
    fi
done
echo ""

# 9. Check CRDs
echo "9. Checking Spark CRDs..."
if kubectl get crd sparkapplications.sparkoperator.k8s.io &>/dev/null; then
    check_passed "SparkApplication CRD exists"
else
    check_failed "SparkApplication CRD not found"
fi

if kubectl get crd scheduledsparkapplications.sparkoperator.k8s.io &>/dev/null; then
    check_passed "ScheduledSparkApplication CRD exists"
else
    check_warning "ScheduledSparkApplication CRD not found (optional)"
fi
echo ""

# 10. Summary
echo "=========================================="
echo "Verification Summary"
echo "=========================================="
echo ""
echo "Helm Release: $RELEASE_NAME"
echo "Namespace: $NAMESPACE"
echo "Status: $(helm status $RELEASE_NAME -n $NAMESPACE -o json | jq -r '.info.status')"
echo ""

# Count namespaces
NAMESPACE_COUNT=0
for team in team-alpha team-beta team-theta team-delta ds-team-ns de-team-ns; do
    if kubectl get namespace $team &>/dev/null; then
        ((NAMESPACE_COUNT++))
    fi
done
echo "Team Namespaces: $NAMESPACE_COUNT/6"

# Count queues
if kubectl get queues &>/dev/null 2>&1; then
    QUEUE_COUNT=$(kubectl get queues --no-headers 2>/dev/null | wc -l)
    echo "Volcano Queues: $QUEUE_COUNT"
fi

# Count quotas
QUOTA_COUNT=0
for team in team-alpha team-beta team-theta team-delta ds-team-ns de-team-ns; do
    if kubectl get namespace $team &>/dev/null; then
        TEAM_QUOTAS=$(kubectl get resourcequota -n $team --no-headers 2>/dev/null | wc -l)
        QUOTA_COUNT=$((QUOTA_COUNT + TEAM_QUOTAS))
    fi
done
echo "Resource Quotas: $QUOTA_COUNT"

echo ""
echo "=========================================="
echo "Next Steps"
echo "=========================================="
echo ""
echo "1. Submit a test job:"
echo "   kubectl apply -f ../../spark-on-k8s/jobs/default-scheduler/team-alpha-pyspark-test.yaml"
echo ""
echo "2. Watch the job:"
echo "   kubectl get sparkapplications -n team-alpha -w"
echo ""
echo "3. Check logs:"
echo "   kubectl logs -n team-alpha <driver-pod-name>"
echo ""
echo "4. Monitor resources:"
echo "   kubectl describe quota -n team-alpha"
echo ""

if kubectl get namespace volcano-system &>/dev/null; then
    echo "5. Check Volcano queues:"
    echo "   kubectl describe queue queue-theta"
    echo ""
fi

echo "For more information, see:"
echo "  - helm-charts/spark-on-k8s/README.md"
echo "  - helm-charts/spark-on-k8s/INSTALL.md"
echo ""
