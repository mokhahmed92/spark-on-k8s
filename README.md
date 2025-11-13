# Spark on Kubernetes with K3d and Volcano

A production-ready data platform on Kubernetes featuring multi-tenant Spark workloads, dual scheduling systems (Default & Volcano), and queue-based resource management.

## 🚀 Current Cluster Status

### Cluster Information
- **Platform**: K3d on WSL2 (Linux 5.15.167.4)
- **Kubernetes Version**: v1.31.4+k3s1
- **Nodes**: 3 (1 control-plane + 2 workers)
- **Teams**: 6 operational (Alpha, Beta, Theta, Delta, DS-Team, DE-Team)
- **Status**: ✅ Fully Operational

### Deployed Components

#### 1. Spark Operator
- **Namespace**: `spark-operator`
- **Version**: 2.3.0
- **Helm Revision**: 4
- **Status**: ✅ Running
- **Components**:
  - Controller: 1/1 replica running
  - Webhook: 1/1 replica running (port 9443)
- **Configuration**:
  - Watches: `team-alpha`, `team-beta`, `team-theta`, `team-delta`, `ds-team-ns`, `de-team-ns`
  - Batch Scheduler: Enabled (supports Volcano)
  - Metrics: Enabled on port 8080

#### 2. Volcano Scheduler
- **Namespace**: `volcano-system`
- **Version**: v1.8.2
- **Status**: ✅ Running
- **Components**:
  - Scheduler: 1/1 replica (handles pod scheduling)
  - Controller: 1/1 replica (manages queues/podgroups)
  - Admission: 1/1 replica (webhook validation)
- **Queues**:
  - `queue-theta`: 40% weight, 8 CPU / 16Gi capacity
  - `queue-delta`: 40% weight, 8 CPU / 16Gi capacity
  - `batch-jobs-queue`: 100% weight, 16 CPU / 32Gi capacity (shared)
  - `default`: 20% weight, 4 CPU / 8Gi capacity

#### 3. Multi-Tenant Setup

| Team | Namespace | Scheduler | Queue | Workload Type | Resource Quota |
|------|-----------|-----------|-------|---------------|----------------|
| Alpha | team-alpha | default | - | PySpark | 4-8 CPU, 8-16Gi, 10 pods |
| Beta | team-beta | default | - | Scala Spark | 4-8 CPU, 8-16Gi, 10 pods |
| Theta | team-theta | volcano | queue-theta | Scala Spark | 6-8 CPU, 12-16Gi, 15 pods |
| Delta | team-delta | volcano | queue-delta | PySpark | 6-8 CPU, 12-16Gi, 15 pods |
| DS-Team | ds-team-ns | volcano | batch-jobs-queue | Data Science | No quotas (40% share) |
| DE-Team | de-team-ns | volcano | batch-jobs-queue | Data Engineering | No quotas (60% share) |

### Latest Spark Applications

| Team | Application | Type | Scheduler | Status | Result | Duration |
|------|------------|------|-----------|--------|--------|----------|
| Alpha | pyspark-pi-test | PySpark | default | ✅ COMPLETED | Pi ≈ 3.148120 | 11s |
| Beta | spark-pi-test | Scala | default | ✅ COMPLETED | Pi ≈ 3.141711 | 12s |
| Theta | spark-volcano-test | Scala | volcano | ✅ COMPLETED | Pi ≈ 3.141641 | 15s |
| Delta | pyspark-volcano-test | PySpark | volcano | ✅ COMPLETED | Pi ≈ 3.144280 | 49s |

## 📁 Project Structure

```
spark-operators-on-k8s/
├── k3d/
│   └── k3d-config.yaml                    # K3d cluster configuration
├── k8s-platform/                         # 🆕 Consolidated Platform Configuration
│   ├── namespaces/
│   │   └── all-teams.yaml                 # All 6 team namespaces
│   ├── rbac/
│   │   └── all-teams-rbac.yaml            # RBAC for all teams
│   ├── queues/
│   │   └── all-queues.yaml                # All Volcano queues
│   ├── resource-quotas/
│   │   └── all-teams-quotas.yaml          # Resource quotas (4 teams only)
│   ├── jobs/                              # Spark job examples
│   │   ├── all-team-jobs.yaml             # All team jobs in one file
│   │   ├── default-scheduler/             # Default scheduler jobs
│   │   │   ├── team-alpha-pyspark-test.yaml
│   │   │   └── team-beta-spark-test.yaml
│   │   └── volcano-scheduler/             # Volcano scheduler jobs
│   │       ├── team-theta-spark-volcano.yaml
│   │       ├── team-delta-spark-volcano.yaml
│   │       ├── ds-team-pyspark-volcano.yaml
│   │       └── de-team-spark-volcano.yaml
│   ├── spark-operator/
│   │   ├── values-default.yaml            # Original Spark Operator values
│   │   └── values-volcano.yaml            # Volcano-enabled values
│   ├── scripts/
│   │   ├── install-volcano.sh             # Installation script
│   │   └── test-volcano-integration.sh    # Integration tests
│   └── README.md                          # Platform documentation
├── docs/
│   └── architecture.md                    # Detailed architecture diagrams
├── CLAUDE.md                              # AI assistant instructions
└── README.md                              # This file
```

### 🆕 New Consolidated Structure Benefits

- **Single Source of Truth**: All configurations consolidated by function
- **Easier Management**: Deploy all teams with single commands
- **Better Organization**: Logical grouping (namespaces, rbac, queues, jobs)
- **Reduced Complexity**: Fewer files to manage
- **Comprehensive Documentation**: Complete setup guides

### 📦 Legacy Structure (Deprecated)

The following directories have been consolidated into `k8s-platform/`:
- ~~`spark-operator/`~~ → `k8s-platform/{namespaces,rbac,resource-quotas,spark-operator}/`
- ~~`volcano/`~~ → `k8s-platform/{queues,scripts,spark-operator}/`
- ~~`spark-jobs/`~~ → `k8s-platform/jobs/`

## 🏗️ System Architecture

### High-Level Overview

The platform implements a multi-tenant Spark-on-Kubernetes architecture with dual scheduling systems (Default & Volcano) for optimal resource utilization and workload isolation.

```
┌─────────────────────────────────────────────────────────────────┐
│                     Data Platform Architecture                   │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  User Layer        Platform Layer         Workload Layer       │
│  ┌─────────┐      ┌──────────────┐      ┌──────────────┐     │
│  │ kubectl │─────▶│Spark Operator│─────▶│ Spark Jobs   │     │
│  │  Helm   │      │   Volcano    │      │ • Driver Pods │     │
│  └─────────┘      └──────────────┘      │ • Executors  │     │
│                                          └──────────────┘     │
│                                                                 │
│  Infrastructure: K3d Cluster (1 Control + 2 Workers)          │
└─────────────────────────────────────────────────────────────────┘
```

### Component Architecture

```
┌──────────────────────────────────────────────────────────────┐
│                    Kubernetes Cluster (K3d)                   │
├────────────────────────────────────────────────────────────────┤
│                                                                │
│  ┌─────────────────────┐      ┌─────────────────────┐       │
│  │  Control Plane      │      │   Platform Services  │       │
│  │  • API Server       │      │   • Spark Operator   │       │
│  │  • Scheduler        │      │   • Volcano          │       │
│  │  • Controller Mgr   │      │   • Webhooks         │       │
│  │  • etcd             │      │   • Metrics          │       │
│  └─────────────────────┘      └─────────────────────┘       │
│                                                                │
│  ┌──────────────────────────────────────────────────────┐    │
│  │              Team Namespaces & Scheduling             │    │
│  │                                                        │    │
│  │  Default Scheduler          Volcano Scheduler         │    │
│  │  ┌──────────────┐          ┌──────────────┐         │    │
│  │  │ team-alpha   │          │ team-theta   │         │    │
│  │  │ • PySpark    │          │ • Scala      │         │    │
│  │  │ • 4-8 CPU    │          │ • 6-8 CPU    │         │    │
│  │  └──────────────┘          │ • Queue: 40% │         │    │
│  │  ┌──────────────┐          └──────────────┘         │    │
│  │  │ team-beta    │          ┌──────────────┐         │    │
│  │  │ • Scala      │          │ team-delta   │         │    │
│  │  │ • 4-8 CPU    │          │ • PySpark    │         │    │
│  │  └──────────────┘          │ • 6-8 CPU    │         │    │
│  │                             │ • Queue: 40% │         │    │
│  │                             └──────────────┘         │    │
│  └──────────────────────────────────────────────────────┘    │
└──────────────────────────────────────────────────────────────┘
```

### Resource Allocation

```
Total Cluster: ~8 CPU, ~16Gi Memory

Volcano Queues (Theta & Delta Teams):
┌────────────────────────────────────────────┐
│ queue-theta: 40% weight, 8CPU/16Gi cap    │
│ queue-delta: 40% weight, 8CPU/16Gi cap    │
│ default:     20% weight, 4CPU/8Gi cap     │
└────────────────────────────────────────────┘

Team Resource Quotas:
• Alpha/Beta:  4-8 CPU, 8-16Gi,  10 pods max
• Theta/Delta: 6-8 CPU, 12-16Gi, 15 pods max
```

### Spark Job Execution Flow

```
1. User submits SparkApplication YAML
           ↓
2. Spark Operator validates and creates driver pod
           ↓
3. Scheduler assigns driver to node
   • Default scheduler for Alpha/Beta
   • Volcano scheduler for Theta/Delta
           ↓
4. Driver pod creates executor pods
           ↓
5. Job executes and completes
           ↓
6. Resources released back to queue/cluster
```

For detailed architecture diagrams including security, networking, and data flow, see [docs/architecture.md](docs/architecture.md).

## 🛠️ Quick Start

### Prerequisites
- Docker Desktop or Docker Engine
- kubectl command-line tool
- k3d (v5.x)
- Helm 3

### Installation Steps

#### 1. Install Tools

```bash
# Install k3d (Windows/WSL)
wget -q -O - https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | bash

# Install Helm
curl -fsSL https://get.helm.sh/helm-v3.18.6-linux-amd64.tar.gz | tar -xz
mv linux-amd64/helm ~/.local/bin/
export PATH=$PATH:~/.local/bin
```

#### 2. Create K3d Cluster

```bash
cd k3d
k3d cluster create -c k3d-config.yaml
kubectl get nodes
```

#### 3. Install Volcano Scheduler

```bash
# Add Volcano repository
helm repo add volcano https://volcano-sh.github.io/helm-charts
helm repo update

# Install Volcano
helm install volcano volcano/volcano \
  --namespace volcano-system \
  --create-namespace \
  --set basic.image.tag=v1.8.2

# Verify installation
kubectl get pods -n volcano-system
```

#### 4. Setup Teams and Resources (Consolidated Approach)

```bash
# Create all namespaces (6 teams)
kubectl apply -f k8s-platform/namespaces/all-teams.yaml

# Apply RBAC for all teams
kubectl apply -f k8s-platform/rbac/all-teams-rbac.yaml

# Configure all Volcano queues
kubectl apply -f k8s-platform/queues/all-queues.yaml

# Set resource quotas (only for 4 teams)
kubectl apply -f k8s-platform/resource-quotas/all-teams-quotas.yaml
```

#### 5. Install Spark Operator

```bash
# Add Spark Operator repository
helm repo add spark-operator https://kubeflow.github.io/spark-operator

# Install with Volcano support (watches all 6 teams)
helm install spark-operator spark-operator/spark-operator \
  --namespace spark-operator \
  --create-namespace \
  -f k8s-platform/spark-operator/values-volcano.yaml

# Verify installation
kubectl get pods -n spark-operator
kubectl logs -n spark-operator deployment/spark-operator-controller | head -5
```

## 🚀 Submitting Spark Jobs

### Bulk Job Submission

```bash
# Submit all team jobs at once (6 teams)
kubectl apply -f k8s-platform/jobs/all-team-jobs.yaml
kubectl get sparkapplications -A -w

# Submit by scheduler type
kubectl apply -f k8s-platform/jobs/default-scheduler/    # Alpha, Beta
kubectl apply -f k8s-platform/jobs/volcano-scheduler/   # Theta, Delta, DS, DE
```

### Individual Team Jobs

#### Default Scheduler Teams
```bash
# Team Alpha - PySpark
kubectl apply -f k8s-platform/jobs/default-scheduler/team-alpha-pyspark-test.yaml
kubectl get sparkapplication -n team-alpha -w

# Team Beta - Scala
kubectl apply -f k8s-platform/jobs/default-scheduler/team-beta-spark-test.yaml
kubectl get sparkapplication -n team-beta -w
```

#### Volcano Scheduler Teams
```bash
# Team Theta - Scala with Volcano (individual queue)
kubectl apply -f k8s-platform/jobs/volcano-scheduler/team-theta-spark-volcano.yaml
kubectl get sparkapplication -n team-theta -w

# Team Delta - PySpark with Volcano (individual queue)
kubectl apply -f k8s-platform/jobs/volcano-scheduler/team-delta-spark-volcano.yaml
kubectl get sparkapplication -n team-delta -w

# DS Team - Data Science with Volcano (shared queue)
kubectl apply -f k8s-platform/jobs/volcano-scheduler/ds-team-pyspark-volcano.yaml
kubectl get sparkapplication -n ds-team-ns -w

# DE Team - Data Engineering with Volcano (shared queue)
kubectl apply -f k8s-platform/jobs/volcano-scheduler/de-team-spark-volcano.yaml
kubectl get sparkapplication -n de-team-ns -w
```

## 📊 Monitoring

### Check Application Status

```bash
# All applications
kubectl get sparkapplications -A

# Specific team
kubectl describe sparkapplication <app-name> -n <team-namespace>

# Application logs
kubectl logs <driver-pod> -n <team-namespace>
```

### Verify Schedulers

```bash
# Check scheduler assignment
kubectl get pod <pod-name> -n <namespace> -o jsonpath='{.spec.schedulerName}'

# Volcano queues status
kubectl get queues
kubectl describe queue queue-theta
kubectl describe queue queue-delta
```

### Resource Monitoring

```bash
# Resource quotas
kubectl describe quota -A | grep -A5 team-

# Pod status
kubectl get pods -A | grep team-

# Volcano podgroups
kubectl get podgroups -A
```

### System Logs

```bash
# Spark Operator logs
kubectl logs -n spark-operator deployment/spark-operator-controller

# Volcano scheduler logs
kubectl logs -n volcano-system deployment/volcano-scheduler
```

## 🔧 Configuration Details

### Spark Application Requirements

When submitting Spark applications, ensure:

1. **Service Account**: Specify the team's service account
2. **Resource Limits**: Include `coreLimit` for driver and executors
3. **Scheduler Selection**:
   - Default teams: No additional configuration
   - Volcano teams: Set `batchScheduler: volcano` and `queue` in batchSchedulerOptions

### Example: Volcano-Scheduled Application

```yaml
spec:
  batchScheduler: volcano
  batchSchedulerOptions:
    queue: queue-theta
    priorityClassName: normal
  driver:
    annotations:
      scheduling.volcano.sh/queue-name: queue-theta
```

## 🚨 Troubleshooting

### Common Issues

#### Image Pull Errors
- Verify image: `apache/spark:3.5.0`
- Check network connectivity
- Ensure no typos in image name

#### Resource Quota Violations
```bash
# Check quota usage
kubectl describe quota -n <namespace>

# Ensure limits are specified
# Add coreLimit to driver/executor specs
```

#### Scheduling Issues
```bash
# For Volcano teams - check queue status
kubectl describe queue <queue-name>

# Check for pending pods
kubectl get pods -A | grep Pending

# Verify scheduler logs
kubectl logs -n volcano-system deployment/volcano-scheduler
```

#### Spark Operator Not Watching Namespace
```bash
# Verify watched namespaces
kubectl logs -n spark-operator deployment/spark-operator-controller | grep namespace
# Should show: --namespaces=team-alpha,team-beta,team-theta,team-delta
```

## 🧹 Cleanup

### Delete Applications
```bash
kubectl delete sparkapplication --all -n team-alpha
kubectl delete sparkapplication --all -n team-beta
kubectl delete sparkapplication --all -n team-theta
kubectl delete sparkapplication --all -n team-delta
```

### Uninstall Components
```bash
# Uninstall Spark Operator
helm uninstall spark-operator -n spark-operator

# Uninstall Volcano
helm uninstall volcano -n volcano-system

# Delete namespaces
kubectl delete namespace team-alpha team-beta team-theta team-delta
kubectl delete namespace spark-operator volcano-system
```

### Delete Cluster
```bash
k3d cluster delete data-platform-cluster
```

## 📈 Performance Metrics

Current benchmarks for Pi calculation (2000 iterations for Theta, 1500 for Delta):

| Team | Type | Scheduler | Executors | Duration |
|------|------|-----------|-----------|----------|
| Alpha | PySpark | Default | 2 | ~11s |
| Beta | Scala | Default | 2 | ~12s |
| Theta | Scala | Volcano | 2 | ~15s |
| Delta | PySpark | Volcano | 3 | ~49s |

*Note: Volcano scheduling adds overhead but provides better resource isolation and queue management.*

## 🔮 Roadmap

### Near Term
- [x] Multi-tenant support with 4 teams
- [x] Volcano scheduler integration
- [x] Queue-based resource management
- [ ] MinIO for S3-compatible storage
- [ ] Prometheus + Grafana monitoring

### Long Term
- [ ] Spark History Server
- [ ] Autoscaling with HPA/VPA
- [ ] Network policies for security
- [ ] CI/CD pipeline for Spark jobs
- [ ] Cost tracking per team
- [ ] Data lineage tracking

## 📚 References

- [K3d Documentation](https://k3d.io/)
- [Spark Operator](https://github.com/kubeflow/spark-operator)
- [Volcano Scheduler](https://volcano.sh/)
- [Apache Spark on Kubernetes](https://spark.apache.org/docs/latest/running-on-kubernetes.html)
- [Kubernetes Resource Quotas](https://kubernetes.io/docs/concepts/policy/resource-quotas/)

## 🤝 Contributing

1. Fork the repository
2. Create your feature branch
3. Test changes in local k3d cluster
4. Submit pull request with detailed description

## 📝 License

This project is for demonstration and educational purposes.

---
**Last Updated**: September 4, 2025  
**Status**: ✅ Fully Operational (4 Teams Active)  
**Maintained by**: Data Platform Team