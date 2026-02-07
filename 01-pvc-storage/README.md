# Tutorial 01: Spark on Kubernetes with PVC Storage

**Storage**: PVC (Mounted Volume)
**Modes**: Client and Cluster
**Difficulty**: Beginner

## Overview

In this tutorial you will run a PySpark word count job on Kubernetes using **mounted volumes** for data storage. You'll learn both deployment modes:

- **Client mode**: Driver runs on your local machine, executors run as K8s pods
- **Cluster mode**: Both driver and executors run as K8s pods (production-recommended)

The storage pattern uses a **PersistentVolumeClaim (PVC) backed by NFS**. Spark pods mount a shared volume and read/write data as if working with a local directory.

## Prerequisites

| Tool | Minimum Version | Purpose |
|------|----------------|---------|
| Docker | 24.x | Container runtime required by k3d |
| k3d | v5.8.3 | Creates local Kubernetes cluster |
| kubectl | v1.31.x | Kubernetes CLI |
| Apache Spark | 3.5.4 | Provides `spark-submit` binary |

## Quick Start

```bash
# Navigate to this tutorial directory
cd 01-pvc-storage

# 1. Create the k3d cluster
./scripts/setup-cluster.sh

# 2. Build and push the custom Spark image
./scripts/build-image.sh

# 3. Set up Spark RBAC
./scripts/setup-spark-rbac.sh

# 4. Deploy NFS provisioner and create data PVC
kubectl apply -f manifests/storage/nfs-provisioner.yaml
kubectl -n nfs-provisioner wait --for=condition=Ready pod -l app=nfs-provisioner --timeout=120s
kubectl apply -f manifests/storage/spark-data-pvc.yaml

# 5. Deploy History Server
./scripts/setup-history-server.sh
```

## Upload Sample Data

Copy sample data to the PVC:

```bash
kubectl -n spark run data-loader --image=busybox --restart=Never \
  --overrides='{
    "spec": {
      "containers": [{
        "name": "data-loader",
        "image": "busybox",
        "command": ["sleep", "3600"],
        "volumeMounts": [{"name": "data", "mountPath": "/data"}]
      }],
      "volumes": [{"name": "data", "persistentVolumeClaim": {"claimName": "spark-data-pvc"}}]
    }
  }'

kubectl -n spark wait --for=condition=Ready pod/data-loader --timeout=60s
kubectl -n spark exec data-loader -- mkdir -p /data/input /data/output
kubectl cp code/data/sample-input.txt spark/data-loader:/data/input/sample-input.txt
kubectl -n spark delete pod data-loader
```

---

## Option A: Client Mode

In client mode, the Spark driver runs on your local machine while executor pods are created in the cluster.

### Determine Your Host IP

```bash
# Linux
hostname -I | awk '{print $1}'

# macOS/Windows: Use host.docker.internal or your LAN IP
```

### Submit the Job

Replace `YOUR_HOST_IP` with your actual IP:

```bash
$SPARK_HOME/bin/spark-submit \
  --master k8s://https://127.0.0.1:6443 \
  --deploy-mode client \
  --name wordcount-client \
  --conf spark.kubernetes.namespace=spark \
  --conf spark.kubernetes.authenticate.driver.serviceAccountName=spark \
  --conf spark.kubernetes.container.image=spark-registry:5111/spark-custom:v1.0 \
  --conf spark.kubernetes.container.image.pullPolicy=IfNotPresent \
  --conf spark.executor.instances=2 \
  --conf spark.executor.memory=512m \
  --conf spark.executor.cores=1 \
  --conf spark.driver.memory=512m \
  --conf spark.driver.host=YOUR_HOST_IP \
  --conf spark.driver.port=7078 \
  --conf spark.kubernetes.executor.volumes.persistentVolumeClaim.data-vol.options.claimName=spark-data-pvc \
  --conf spark.kubernetes.executor.volumes.persistentVolumeClaim.data-vol.mount.path=/data \
  --conf spark.kubernetes.executor.volumes.persistentVolumeClaim.events-vol.options.claimName=spark-events-pvc \
  --conf spark.kubernetes.executor.volumes.persistentVolumeClaim.events-vol.mount.path=/mnt/spark-events \
  --conf spark.eventLog.enabled=true \
  --conf spark.eventLog.dir=file:///mnt/spark-events \
  /opt/spark-apps/wordcount.py \
  /data/input/sample-input.txt \
  /data/output/wordcount-client-result
```

---

## Option B: Cluster Mode

In cluster mode, both the driver and executors run as Kubernetes pods. This is the **production-recommended** approach.

### Submit the Job

```bash
$SPARK_HOME/bin/spark-submit \
  --master k8s://https://127.0.0.1:6443 \
  --deploy-mode cluster \
  --name wordcount-cluster \
  --conf spark.kubernetes.namespace=spark \
  --conf spark.kubernetes.authenticate.driver.serviceAccountName=spark \
  --conf spark.kubernetes.container.image=spark-registry:5111/spark-custom:v1.0 \
  --conf spark.kubernetes.container.image.pullPolicy=IfNotPresent \
  --conf spark.executor.instances=2 \
  --conf spark.executor.memory=512m \
  --conf spark.executor.cores=1 \
  --conf spark.driver.memory=512m \
  --conf spark.kubernetes.driver.volumes.persistentVolumeClaim.data-vol.options.claimName=spark-data-pvc \
  --conf spark.kubernetes.driver.volumes.persistentVolumeClaim.data-vol.mount.path=/data \
  --conf spark.kubernetes.executor.volumes.persistentVolumeClaim.data-vol.options.claimName=spark-data-pvc \
  --conf spark.kubernetes.executor.volumes.persistentVolumeClaim.data-vol.mount.path=/data \
  --conf spark.kubernetes.driver.volumes.persistentVolumeClaim.events-vol.options.claimName=spark-events-pvc \
  --conf spark.kubernetes.driver.volumes.persistentVolumeClaim.events-vol.mount.path=/mnt/spark-events \
  --conf spark.kubernetes.executor.volumes.persistentVolumeClaim.events-vol.options.claimName=spark-events-pvc \
  --conf spark.kubernetes.executor.volumes.persistentVolumeClaim.events-vol.mount.path=/mnt/spark-events \
  --conf spark.eventLog.enabled=true \
  --conf spark.eventLog.dir=file:///mnt/spark-events \
  local:///opt/spark-apps/wordcount.py \
  /data/input/sample-input.txt \
  /data/output/wordcount-cluster-result
```

---

## Client vs Cluster Mode Comparison

| Aspect | Client Mode | Cluster Mode |
|--------|-------------|--------------|
| `--deploy-mode` | `client` | `cluster` |
| Driver location | Local machine | Kubernetes pod |
| Application path | `/opt/spark-apps/...` | `local:///opt/spark-apps/...` |
| Volume mounts | Executor pods only | Driver AND executor pods |
| `spark.driver.host` | Required | Not needed |
| Driver logs | Terminal output | `kubectl logs` |
| Use case | Development, debugging | Production |

---

## Verification

Monitor pods:

```bash
kubectl -n spark get pods -w
```

View driver logs (cluster mode only):

```bash
kubectl -n spark logs -l spark-role=driver --tail=50
```

Check output:

```bash
kubectl -n spark run output-checker --rm -it --restart=Never \
  --image=busybox \
  --overrides='{
    "spec": {
      "containers": [{
        "name": "output-checker",
        "image": "busybox",
        "command": ["cat", "/data/output/wordcount-client-result/part-00000"],
        "volumeMounts": [{"name": "data", "mountPath": "/data"}]
      }],
      "volumes": [{"name": "data", "persistentVolumeClaim": {"claimName": "spark-data-pvc"}}]
    }
  }'
```

Access History Server:

```bash
kubectl -n spark port-forward svc/spark-history-server 18080:18080
# Open http://localhost:18080
```

## Cleanup

```bash
kubectl -n spark delete pods -l spark-role=driver
kubectl -n spark delete pods -l spark-role=executor
./scripts/cleanup.sh
```

## What's Next

Continue to **Tutorial 02: S3 Storage with MinIO** to learn cloud-native storage patterns using S3A.
