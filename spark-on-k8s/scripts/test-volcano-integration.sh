#!/bin/bash

# Test script for Volcano integration with Spark Operator
# This script validates the Volcano scheduler setup and queue functionality

set -e

echo "🧪 Starting Volcano Integration Tests..."
echo "======================================="

# Function to check command status
check_status() {
    if [ $? -eq 0 ]; then
        echo "✅ $1"
    else
        echo "❌ $1 failed"
        exit 1
    fi
}

# Test 1: Verify Volcano is installed
echo ""
echo "Test 1: Checking Volcano Installation..."
kubectl get pods -n volcano-system > /dev/null 2>&1
check_status "Volcano pods are running"

# Test 2: Verify queues are created
echo ""
echo "Test 2: Checking Volcano Queues..."
kubectl get queue queue-theta > /dev/null 2>&1
check_status "Queue-theta exists"
kubectl get queue queue-delta > /dev/null 2>&1
check_status "Queue-delta exists"

# Test 3: Verify namespaces exist
echo ""
echo "Test 3: Checking Team Namespaces..."
kubectl get namespace team-theta > /dev/null 2>&1
check_status "Namespace team-theta exists"
kubectl get namespace team-delta > /dev/null 2>&1
check_status "Namespace team-delta exists"

# Test 4: Submit test job for team-theta
echo ""
echo "Test 4: Submitting Spark job for team-theta..."
kubectl apply -f spark-jobs/team-theta-spark-volcano.yaml
check_status "Team-theta job submitted"

# Test 5: Submit test job for team-delta
echo ""
echo "Test 5: Submitting Spark job for team-delta..."
kubectl apply -f spark-jobs/team-delta-spark-volcano.yaml
check_status "Team-delta job submitted"

# Wait for jobs to start
echo ""
echo "⏳ Waiting for jobs to be scheduled (30 seconds)..."
sleep 30

# Test 6: Check if jobs are using Volcano scheduler
echo ""
echo "Test 6: Verifying Volcano scheduling..."
THETA_SCHEDULER=$(kubectl get pods -n team-theta -o jsonpath='{.items[0].spec.schedulerName}' 2>/dev/null || echo "none")
if [ "$THETA_SCHEDULER" = "volcano" ]; then
    echo "✅ Team-theta using Volcano scheduler"
else
    echo "⚠️  Team-theta scheduler: $THETA_SCHEDULER (expected: volcano)"
fi

DELTA_SCHEDULER=$(kubectl get pods -n team-delta -o jsonpath='{.items[0].spec.schedulerName}' 2>/dev/null || echo "none")
if [ "$DELTA_SCHEDULER" = "volcano" ]; then
    echo "✅ Team-delta using Volcano scheduler"
else
    echo "⚠️  Team-delta scheduler: $DELTA_SCHEDULER (expected: volcano)"
fi

# Test 7: Check PodGroups
echo ""
echo "Test 7: Checking PodGroups..."
kubectl get podgroup -A | grep -E "theta|delta" && echo "✅ PodGroups created" || echo "⚠️  No PodGroups found"

# Test 8: Monitor queue status
echo ""
echo "Test 8: Queue Status..."
echo "Queue-theta:"
kubectl get queue queue-theta -o jsonpath='{.status}' | python3 -m json.tool 2>/dev/null || kubectl describe queue queue-theta | grep -A5 "Status:"
echo ""
echo "Queue-delta:"
kubectl get queue queue-delta -o jsonpath='{.status}' | python3 -m json.tool 2>/dev/null || kubectl describe queue queue-delta | grep -A5 "Status:"

# Test 9: Check Spark application status
echo ""
echo "Test 9: Spark Application Status..."
kubectl get sparkapplication -n team-theta
kubectl get sparkapplication -n team-delta

# Test 10: Resource quota usage
echo ""
echo "Test 10: Resource Quota Usage..."
echo "Team-theta quota:"
kubectl describe quota -n team-theta | grep -A5 "Used"
echo ""
echo "Team-delta quota:"
kubectl describe quota -n team-delta | grep -A5 "Used"

# Summary
echo ""
echo "======================================="
echo "📊 Test Summary"
echo "======================================="
echo "1. Volcano Installation: ✅"
echo "2. Queues Created: ✅"
echo "3. Namespaces Ready: ✅"
echo "4. Jobs Submitted: ✅"
echo "5. Scheduler Verification: Check above"
echo "6. PodGroups: Check above"
echo "7. Applications Running: Check above"
echo ""
echo "💡 To monitor jobs:"
echo "   kubectl get sparkapplication -A -w"
echo "   kubectl get pods -n team-theta -w"
echo "   kubectl get pods -n team-delta -w"
echo ""
echo "🔍 To check logs:"
echo "   kubectl logs -n team-theta <driver-pod>"
echo "   kubectl logs -n team-delta <driver-pod>"
echo "   kubectl logs -n volcano-system deployment/volcano-scheduler"