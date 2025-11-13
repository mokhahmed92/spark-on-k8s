# K8s Platform Configuration

This directory contains the consolidated Kubernetes platform configuration files for the multi-tenant Spark data platform.

## Directory Structure

```
k8s-platform/
├── namespaces/
│   └── all-teams.yaml              # All team namespaces (alpha, beta, theta, delta, ds-team, de-team)
├── rbac/
│   └── all-teams-rbac.yaml         # RBAC for all teams (ServiceAccounts, Roles, RoleBindings)
├── queues/
│   └── all-queues.yaml             # All Volcano queues (individual + shared batch-jobs-queue)
├── resource-quotas/
│   └── all-teams-quotas.yaml       # Resource quotas (alpha, beta, theta, delta only)
├── jobs/
│   ├── all-team-jobs.yaml          # All team job examples in one file
│   ├── default-scheduler/          # Default scheduler job examples
│   │   ├── team-alpha-pyspark-test.yaml
│   │   └── team-beta-spark-test.yaml
│   └── volcano-scheduler/          # Volcano scheduler job examples
│       ├── team-theta-spark-volcano.yaml
│       ├── team-delta-spark-volcano.yaml
│       ├── ds-team-pyspark-volcano.yaml
│       └── de-team-spark-volcano.yaml
├── spark-operator/
│   ├── values-default.yaml         # Original Spark Operator values
│   └── values-volcano.yaml         # Volcano-enabled Spark Operator values
└── scripts/
    ├── install-volcano.sh          # Volcano installation script
    └── test-volcano-integration.sh # Integration testing script
```

## Team Architecture

### Default Scheduler Teams
- **team-alpha**: PySpark jobs, 4-8 CPU, 8-16Gi memory
- **team-beta**: Scala Spark jobs, 4-8 CPU, 8-16Gi memory

### Volcano Scheduler Teams
- **team-theta**: Scala Spark, queue-theta (40% weight), 6-8 CPU, 12-16Gi memory
- **team-delta**: PySpark, queue-delta (40% weight), 6-8 CPU, 12-16Gi memory
- **ds-team-ns**: Data Science team, batch-jobs-queue (40% effective share), no quotas
- **de-team-ns**: Data Engineering team, batch-jobs-queue (60% effective share), no quotas

## Deployment Commands

### Initial Setup
```bash
# Install Volcano
./k8s-platform/scripts/install-volcano.sh

# Deploy all namespaces
kubectl apply -f k8s-platform/namespaces/all-teams.yaml

# Deploy all RBAC
kubectl apply -f k8s-platform/rbac/all-teams-rbac.yaml

# Deploy all queues
kubectl apply -f k8s-platform/queues/all-queues.yaml

# Deploy resource quotas (optional, alpha/beta/theta/delta only)
kubectl apply -f k8s-platform/resource-quotas/all-teams-quotas.yaml

# Install/Update Spark Operator
helm install spark-operator spark-operator/spark-operator \
  --namespace spark-operator --create-namespace \
  -f k8s-platform/spark-operator/values-volcano.yaml
```

### Testing
```bash
# Run integration tests
./k8s-platform/scripts/test-volcano-integration.sh

# Submit all team jobs at once
kubectl apply -f k8s-platform/jobs/all-team-jobs.yaml

# Or submit jobs by scheduler type
kubectl apply -f k8s-platform/jobs/default-scheduler/
kubectl apply -f k8s-platform/jobs/volcano-scheduler/

# Submit individual team jobs
kubectl apply -f k8s-platform/jobs/default-scheduler/team-alpha-pyspark-test.yaml
kubectl apply -f k8s-platform/jobs/volcano-scheduler/ds-team-pyspark-volcano.yaml
```

## Key Features

- **Consolidated Configuration**: All team configs in single files for easier management
- **Mixed Scheduling**: Default + Volcano schedulers for different use cases
- **Queue-based Resource Management**: Individual queues + shared batch-jobs-queue
- **Namespace Isolation**: Each team operates independently with proper RBAC
- **Flexible Resource Management**: Resource quotas for some teams, unlimited for others
- **Gang Scheduling**: PodGroups ensure all pods start together for Volcano teams
- **Multi-Tenant Support**: 6 teams with different scheduling and resource profiles

## Team Configuration Details

### Default Scheduler Teams (Resource Quotas Applied)
| Team | Namespace | Workload | CPU Quota | Memory Quota | Pod Limit |
|------|-----------|----------|-----------|--------------|-----------|
| Alpha | team-alpha | PySpark | 4-8 CPU | 8-16Gi | 10 pods |
| Beta | team-beta | Scala Spark | 4-8 CPU | 8-16Gi | 10 pods |

### Volcano Scheduler Teams
| Team | Namespace | Queue | Share | CPU Resources | Memory Resources | Quotas |
|------|-----------|-------|-------|---------------|------------------|--------|
| Theta | team-theta | queue-theta | 40% | 6-8 CPU | 12-16Gi | Yes (15 pods) |
| Delta | team-delta | queue-delta | 40% | 6-8 CPU | 12-16Gi | Yes (15 pods) |
| DS-Team | ds-team-ns | batch-jobs-queue | 40% effective | Unlimited | Unlimited | No |
| DE-Team | de-team-ns | batch-jobs-queue | 60% effective | Unlimited | Unlimited | No |

### Queue Configuration
- **queue-theta**: Individual queue, 40% weight, 8 CPU/16Gi capacity
- **queue-delta**: Individual queue, 40% weight, 8 CPU/16Gi capacity
- **batch-jobs-queue**: Shared queue, 100% weight, 16 CPU/32Gi capacity
- **default**: Fallback queue, 20% weight, 4 CPU/8Gi capacity