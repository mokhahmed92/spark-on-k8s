# Spark-on-K8s Helm Chart

A production-ready Helm chart for deploying Apache Spark on Kubernetes with multi-tenant support, Volcano scheduler integration, and comprehensive resource management.

## Features

- **Multi-Tenant Architecture**: Isolated namespaces for different teams with RBAC
- **Dual Scheduling Support**: Standard Kubernetes scheduler and Volcano queue-based scheduling
- **Resource Management**: Per-team resource quotas and Volcano queue-based allocation
- **Spark Operator Integration**: Automated Spark job lifecycle management
- **Production-Ready**: Includes monitoring, metrics, and high availability configurations

## Prerequisites

- Kubernetes 1.24+
- Helm 3.8+
- Volcano Scheduler 1.8+ (if using Volcano features)
- kubectl configured to access your cluster

## Architecture

The chart deploys the following components:

1. **Spark Operator**: Manages SparkApplication custom resources
2. **Team Namespaces**: Isolated environments for each team
3. **RBAC Resources**: Service accounts, roles, and role bindings per team
4. **Volcano Queues**: Queue-based resource scheduling (optional)
5. **Resource Quotas**: Hard limits on CPU, m
emory, and pod counts

### Team Types

#### Default Scheduler Teams
Teams using standard Kubernetes scheduling:
- `team-alpha`: PySpark workloads
- `team-beta`: Scala Spark workloads

#### Volcano Scheduler Teams
Teams using Volcano queue-based scheduling:
- `team-theta`: Individual queue with 40% weight
- `team-delta`: Individual queue with 40% weight
- `ds-team-ns`: Shared queue (Data Science)
- `de-team-ns`: Shared queue (Data Engineering)

## Installation

### 1. Install Volcano (Required for Volcano teams)

```bash
# Install Volcano scheduler
kubectl apply -f https://raw.githubusercontent.com/volcano-sh/volcano/v1.8.2/installer/volcano-development.yaml

# Verify Volcano is running
kubectl get pods -n volcano-system
```

### 2. Add Spark Operator Helm Repository

```bash
helm repo add spark-operator https://kubeflow.github.io/spark-operator
helm repo update
```

### 3. Install the Chart

#### Basic Installation

```bash
helm install spark-platform ./helm-charts/spark-on-k8s \
  --namespace spark-operator \
  --create-namespace
```

#### Custom Values Installation

```bash
helm install spark-platform ./helm-charts/spark-on-k8s \
  --namespace spark-operator \
  --create-namespace \
  --values custom-values.yaml
```

#### Install Without Volcano Support

```bash
helm install spark-platform ./helm-charts/spark-on-k8s \
  --namespace spark-operator \
  --create-namespace \
  --set sparkOperator.batchScheduler.enable=false
```

## Configuration

### Key Configuration Parameters

| Parameter | Description | Default |
|-----------|-------------|---------|
| `global.createNamespaces` | Create team namespaces | `true` |
| `sparkOperator.enabled` | Enable Spark Operator | `true` |
| `sparkOperator.batchScheduler.enable` | Enable Volcano support | `true` |
| `sparkOperator.controller.replicas` | Controller replicas | `1` |
| `sparkOperator.webhook.enable` | Enable admission webhook | `true` |
| `sparkOperator.metrics.enable` | Enable metrics endpoint | `true` |

### Team Configuration

#### Adding a New Default Scheduler Team

```yaml
teams:
  defaultScheduler:
    - name: team-charlie
      displayName: "Team Charlie"
      labels:
        team: team-charlie-id
      serviceAccount:
        name: team-charlie-sa
      resourceQuota:
        enabled: true
        requests:
          cpu: "4"
          memory: "8Gi"
        limits:
          cpu: "8"
          memory: "16Gi"
        pods: "10"
```

#### Adding a New Volcano Scheduler Team

```yaml
teams:
  volcanoScheduler:
    - name: team-epsilon
      displayName: "Team Epsilon"
      labels:
        team: team-epsilon-id
      serviceAccount:
        name: team-epsilon-sa
      queue:
        name: queue-epsilon
        weight: 50
        capability:
          cpu: "10000m"
          memory: "20Gi"
        guarantee:
          cpu: "5000m"
          memory: "10Gi"
        reclaimable: true
      resourceQuota:
        enabled: true
        requests:
          cpu: "8"
          memory: "16Gi"
        limits:
          cpu: "10"
          memory: "20Gi"
        pods: "20"

# Don't forget to add the corresponding queue
queues:
  individual:
    - name: queue-epsilon
      weight: 50
      capability:
        cpu: "10000m"
        memory: "20Gi"
      guarantee:
        cpu: "5000m"
        memory: "10Gi"
      reclaimable: true
```

### Resource Quota Configuration

Adjust resource quotas per team:

```yaml
teams:
  defaultScheduler:
    - name: team-alpha
      resourceQuota:
        enabled: true
        requests:
          cpu: "8"        # Increased from 4
          memory: "16Gi"  # Increased from 8Gi
        limits:
          cpu: "16"       # Increased from 8
          memory: "32Gi"  # Increased from 16Gi
        pods: "20"        # Increased from 10
```

### Volcano Queue Configuration

Modify queue weights and capacities:

```yaml
queues:
  individual:
    - name: queue-theta
      weight: 50        # Increased from 40
      capability:
        cpu: "12000m"   # Increased from 8000m
        memory: "24Gi"  # Increased from 16Gi
      guarantee:
        cpu: "6000m"    # Increased from 4000m
        memory: "12Gi"  # Increased from 8Gi
      reclaimable: true
```

## Usage

### Submitting Spark Jobs

#### Default Scheduler Example (team-alpha)

```yaml
apiVersion: sparkoperator.k8s.io/v1beta2
kind: SparkApplication
metadata:
  name: spark-pi-alpha
  namespace: team-alpha
spec:
  type: Scala
  mode: cluster
  image: "apache/spark:3.5.0"
  imagePullPolicy: IfNotPresent
  mainClass: org.apache.spark.examples.SparkPi
  mainApplicationFile: "local:///opt/spark/examples/jars/spark-examples_2.12-3.5.0.jar"
  sparkVersion: "3.5.0"
  driver:
    cores: 1
    coreLimit: "1000m"  # REQUIRED for quota compliance
    memory: "512m"
    serviceAccount: team-alpha-sa
  executor:
    cores: 1
    coreLimit: "1000m"  # REQUIRED for quota compliance
    instances: 2
    memory: "512m"
```

#### Volcano Scheduler Example (team-theta)

```yaml
apiVersion: sparkoperator.k8s.io/v1beta2
kind: SparkApplication
metadata:
  name: spark-pi-theta
  namespace: team-theta
spec:
  type: Scala
  mode: cluster
  image: "apache/spark:3.5.0"
  imagePullPolicy: IfNotPresent
  mainClass: org.apache.spark.examples.SparkPi
  mainApplicationFile: "local:///opt/spark/examples/jars/spark-examples_2.12-3.5.0.jar"
  sparkVersion: "3.5.0"
  batchScheduler: volcano
  batchSchedulerOptions:
    queue: queue-theta
    priorityClassName: normal
  driver:
    cores: 1
    coreLimit: "1000m"  # REQUIRED for quota compliance
    memory: "512m"
    serviceAccount: team-theta-sa
    annotations:
      scheduling.volcano.sh/queue-name: queue-theta
  executor:
    cores: 1
    coreLimit: "1000m"  # REQUIRED for quota compliance
    instances: 2
    memory: "512m"
```

### Monitoring

#### Check Spark Applications

```bash
# View all Spark applications
kubectl get sparkapplications -A

# Watch application status
kubectl get sparkapplications -A -w

# Check application details
kubectl describe sparkapplication <app-name> -n <namespace>
```

#### Monitor Resource Usage

```bash
# Check resource quotas
kubectl describe quota -A

# Check queue status (Volcano)
kubectl get queues
kubectl describe queue <queue-name>

# View PodGroups (Volcano)
kubectl get podgroups -A
```

#### View Logs

```bash
# Spark Operator logs
kubectl logs -n spark-operator deployment/spark-platform-spark-operator-controller --follow

# Driver pod logs
kubectl logs <driver-pod> -n <team-namespace>

# Executor pod logs
kubectl logs <executor-pod> -n <team-namespace>
```

## Upgrading

### Upgrade the Chart

```bash
helm upgrade spark-platform ./helm-charts/spark-on-k8s \
  --namespace spark-operator \
  --values custom-values.yaml
```

### Add New Teams Without Recreating Existing Resources

```bash
# Upgrade with new team configuration
helm upgrade spark-platform ./helm-charts/spark-on-k8s \
  --namespace spark-operator \
  --values updated-values.yaml \
  --reuse-values
```

## Uninstalling

### Remove the Chart

```bash
# Uninstall the chart
helm uninstall spark-platform --namespace spark-operator

# Optional: Delete namespaces
kubectl delete namespace team-alpha team-beta team-theta team-delta ds-team-ns de-team-ns

# Optional: Delete Volcano queues
kubectl delete queue queue-theta queue-delta batch-jobs-queue default
```

## Troubleshooting

### Common Issues

#### 1. Spark Applications Stuck in NEW State

**Cause**: Spark Operator not watching the namespace

**Solution**:
```bash
# Verify watched namespaces
kubectl logs -n spark-operator deployment/spark-platform-spark-operator-controller | grep "watch namespace"

# Update values.yaml to include the namespace in sparkOperator.jobNamespaces
helm upgrade spark-platform ./helm-charts/spark-on-k8s \
  --namespace spark-operator \
  --reuse-values
```

#### 2. Resource Quota Exceeded

**Cause**: Missing `coreLimit` in SparkApplication spec

**Solution**: Always set `coreLimit` for driver and executor:
```yaml
driver:
  coreLimit: "1000m"
executor:
  coreLimit: "1000m"
```

#### 3. Volcano Scheduler Not Used

**Cause**: Missing Volcano configuration in SparkApplication

**Solution**: Add required Volcano fields:
```yaml
batchScheduler: volcano
batchSchedulerOptions:
  queue: queue-theta
driver:
  annotations:
    scheduling.volcano.sh/queue-name: queue-theta
```

#### 4. PodGroup Not Created

**Cause**: Volcano admission webhook not running

**Solution**:
```bash
# Check Volcano components
kubectl get pods -n volcano-system

# Restart Volcano admission
kubectl rollout restart deployment/volcano-admission -n volcano-system
```

### Debug Commands

```bash
# Check Spark Operator status
kubectl get pods -n spark-operator
kubectl logs -n spark-operator deployment/spark-platform-spark-operator-controller

# Verify RBAC
kubectl auth can-i create sparkapplications --as=system:serviceaccount:team-alpha:team-alpha-sa -n team-alpha

# Check scheduler assignment
kubectl get pod <pod-name> -n <namespace> -o jsonpath='{.spec.schedulerName}'

# Describe resource quota
kubectl describe quota <quota-name> -n <namespace>
```

## Values

See [values.yaml](values.yaml) for the full list of configurable parameters.

## Examples

See the [spark-on-k8s/jobs](../../spark-on-k8s/jobs/) directory for example Spark job definitions.

## Contributing

Contributions are welcome! Please open an issue or pull request.

## License

Apache License 2.0

## Support

For issues and questions:
- GitHub Issues: https://github.com/your-org/spark-operators-on-k8s/issues
- Documentation: [docs/architecture.md](../../docs/architecture.md)
