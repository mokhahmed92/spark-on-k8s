# Installation Guide

## Two-Step Installation Process

Due to Helm's validation requirements, the chart must be installed in two steps:

### Step 1: Install without Queues (Initial Install)

This installs Volcano, Spark Operator, and all team resources but skips Queue creation:

```bash
# Install the chart with queue creation disabled
helm install spark-on-k8s . \
  --namespace spark-platform \
  --create-namespace \
  --set createQueues=false \
  --wait \
  --timeout 10m
```

Wait for all pods to be ready:

```bash
kubectl wait --for=condition=ready pod -l app.kubernetes.io/instance=spark-on-k8s \
  -n spark-platform --timeout=300s
```

### Step 2: Create Queues (Upgrade)

Once Volcano CRDs are installed and the admission webhook is running, enable queue creation:

```bash
# Upgrade to enable queue creation
helm upgrade spark-on-k8s . \
  --namespace spark-platform \
  --set createQueues=true \
  --wait \
  --timeout 5m
```

## Verification

Verify all components are installed:

```bash
# Check all namespaces
kubectl get ns -l app.kubernetes.io/part-of=spark-on-k8s

# Check Volcano queues
kubectl get queues

# Check Spark Operator
kubectl get pods -n spark-platform

# Check team service accounts
kubectl get sa -A -l app.kubernetes.io/part-of=spark-on-k8s

# Check resource quotas
kubectl get resourcequota -A
```

## One-Command Installation (Alternative)

If you prefer a single command, you can chain them:

```bash
helm install spark-on-k8s . \
  --namespace spark-platform \
  --create-namespace \
  --set createQueues=false \
  --wait \
  --timeout 10m && \
kubectl wait --for=condition=ready pod \
  -l app.kubernetes.io/instance=spark-on-k8s \
  -n spark-platform \
  --timeout=300s && \
helm upgrade spark-on-k8s . \
  --namespace spark-platform \
  --set createQueues=true \
  --wait \
  --timeout 5m
```

## Expected Output

After successful installation, you should have:

- **6 team namespaces**: team-alpha, team-beta, team-theta, team-delta, ds-team-ns, de-team-ns
- **6 Volcano queues**: queue-alpha, queue-beta, queue-theta, queue-delta, batch-jobs-queue, default
- **Volcano components**: scheduler, controllers, admission webhook
- **Spark Operator**: controller and webhook
- **RBAC**: Service accounts, roles, and role bindings for each team
- **Resource Quotas**: Applied to 4 teams (alpha, beta, theta, delta)

## Troubleshooting

### Volcano Admission Webhook Not Ready

If the upgrade fails with webhook errors, wait longer and retry:

```bash
# Check admission webhook status
kubectl get deployment -n spark-platform spark-on-k8s-admission

# Wait for it to be ready
kubectl wait --for=condition=available \
  deployment/spark-on-k8s-admission \
  -n spark-platform \
  --timeout=300s

# Retry upgrade
helm upgrade spark-on-k8s . \
  --namespace spark-platform \
  --set createQueues=true
```

### Queues Already Exist

If you need to reinstall:

```bash
# Delete queues first
kubectl delete queues --all

# Uninstall release
helm uninstall spark-on-k8s -n spark-platform

# Delete namespace (optional, removes everything)
kubectl delete ns spark-platform

# Start fresh with Step 1
```

## Uninstallation

```bash
# Uninstall the release
helm uninstall spark-on-k8s -n spark-platform

# Clean up Volcano CRDs (if needed)
kubectl delete crds -l app.kubernetes.io/name=volcano

# Clean up namespace
kubectl delete ns spark-platform
```
