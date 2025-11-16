# Spark on Kubernetes Helm Chart

Production-ready Helm chart for Apache Spark on Kubernetes with unified Volcano scheduler support, multi-tenant architecture, and resource management.

## Features

- **Unified Volcano Scheduler**: All teams use Volcano for advanced scheduling capabilities
- **Multi-Tenant Support**: 6 isolated team namespaces with dedicated queues
- **Resource Management**: Queue-based resource allocation with weights and guarantees
- **RBAC**: Comprehensive role-based access control per team
- **Resource Quotas**: Hard limits on CPU, memory, and pod counts
- **Spark Operator**: Automated Spark application lifecycle management

## Chart Version

- **Chart Version**: 0.2.0
- **Spark Operator**: 2.0.2
- **Volcano**: 1.10.0

## Teams & Queues

| Team | Namespace | Queue | Weight | CPU | Memory |
|------|-----------|-------|--------|-----|--------|
| Team Alpha | team-alpha | queue-alpha | 30 | 8-16 cores | 16-32Gi |
| Team Beta | team-beta | queue-beta | 30 | 8-16 cores | 16-32Gi |
| Team Theta | team-theta | queue-theta | 40 | 12-16 cores | 24-32Gi |
| Team Delta | team-delta | queue-delta | 40 | 12-16 cores | 24-32Gi |
| Data Science | ds-team-ns | batch-jobs-queue | shared | flexible | flexible |
| Data Engineering | de-team-ns | batch-jobs-queue | shared | flexible | flexible |

## Quick Start

### Prerequisites

- Kubernetes cluster (tested on k3d)
- Helm 3.x
- kubectl configured

### Installation

See [INSTALL.md](INSTALL.md) for detailed installation instructions.

**Quick install:**
```bash
# Step 1: Install without queues
helm install spark-on-k8s . \
  --namespace spark-platform \
  --create-namespace \
  --set createQueues=false \
  --wait \
  --timeout 10m

# Step 2: Create queues
helm upgrade spark-on-k8s . \
  --namespace spark-platform \
  --set createQueues=true \
  --wait \
  --timeout 5m
```

### Verification

```bash
# Check queues
kubectl get queues

# Check namespaces
kubectl get ns -l app.kubernetes.io/part-of=spark-on-k8s

# Check Volcano and Spark Operator pods
kubectl get pods -n spark-platform

# Check resource quotas
kubectl get resourcequota -A
```

## Configuration

### Key Values

| Parameter | Description | Default |
|-----------|-------------|---------|
| `createQueues` | Enable/disable queue creation | `true` |
| `volcano.enabled` | Enable Volcano scheduler | `true` |
| `sparkOperator.enabled` | Enable Spark Operator | `true` |
| `global.createNamespaces` | Create team namespaces | `true` |

### Customization

Edit `values.yaml` to customize:
- Team configurations
- Queue weights and resource limits
- Resource quotas
- RBAC permissions

## Submitting Spark Jobs

All Spark applications must use Volcano scheduler:

```yaml
apiVersion: sparkoperator.k8s.io/v1beta2
kind: SparkApplication
metadata:
  name: my-spark-app
  namespace: team-alpha
spec:
  batchScheduler: volcano
  batchSchedulerOptions:
    queue: queue-alpha
    priorityClassName: normal
  driver:
    annotations:
      scheduling.volcano.sh/queue-name: queue-alpha
    coreLimit: "1000m"
    cores: 1
    memory: "1g"
    serviceAccount: team-alpha-sa
  executor:
    coreLimit: "1000m"
    cores: 1
    instances: 2
    memory: "1g"
  # ... rest of spec
```

## Architecture

```
spark-on-k8s-chart/
├── Chart.yaml                    # Chart metadata and dependencies
├── values.yaml                   # Default configuration
├── templates/
│   ├── namespaces.yaml          # Team namespace definitions
│   ├── queues.yaml              # Volcano queue resources
│   ├── rbac.yaml                # Service accounts, roles, bindings
│   ├── resource-quotas.yaml     # Resource quota enforcement
│   └── _helpers.tpl             # Template helper functions
├── charts/                       # Subchart dependencies
│   ├── spark-operator-2.0.2.tgz
│   └── volcano-1.10.0.tgz
├── INSTALL.md                    # Installation guide
└── README.md                     # This file
```

## Upgrading

```bash
helm upgrade spark-on-k8s . \
  --namespace spark-platform \
  -f values.yaml \
  --wait
```

## Uninstallation

```bash
# Uninstall release
helm uninstall spark-on-k8s -n spark-platform

# Clean up namespace (optional)
kubectl delete ns spark-platform

# Clean up CRDs (optional - affects all Volcano/Spark installations)
kubectl delete crds -l app.kubernetes.io/name=volcano
kubectl delete crds -l app.kubernetes.io/name=spark-operator
```

## Troubleshooting

### Common Issues

1. **Queue creation fails**: Ensure Volcano admission webhook is ready
2. **Resource quota exceeded**: Check `coreLimit` is set in SparkApplication
3. **Pods not scheduling**: Verify queue name matches and has capacity

See [INSTALL.md](INSTALL.md) for detailed troubleshooting steps.

## Changes from v0.1.0

- **Breaking**: Unified all teams to use Volcano scheduler
- **Breaking**: Two-step installation required (install, then upgrade)
- **New**: Added queues for team-alpha and team-beta
- **Changed**: Renamed default queue to `default-fallback` (Volcano creates its own `default`)
- **Removed**: Dual scheduler support (defaultScheduler vs volcanoScheduler)
- **Simplified**: Single teams list in values.yaml

## License

See parent project LICENSE file.
