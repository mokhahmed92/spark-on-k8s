# Tutorial 02: Spark on Kubernetes with S3 Storage

**Storage**: S3 (MinIO)
**Modes**: Client and Cluster
**Difficulty**: Intermediate

## Overview

In this tutorial you will run a PySpark word count application using **S3 direct access** via MinIO. This is the **cloud-native pattern** for working with object storage - no PersistentVolumes for data access.

You'll learn both deployment modes:

- **Client mode**: Driver runs locally, requires port-forward to MinIO
- **Cluster mode**: Everything runs in-cluster (**production-recommended**)

## Prerequisites

| Tool | Version | Purpose |
|------|---------|---------|
| Docker | 24.x | Container runtime |
| k3d | v5.8.3 | Local Kubernetes |
| kubectl | v1.31.x | Kubernetes CLI |
| Spark | 3.5.4 | `spark-submit` CLI |
| mc | Latest | MinIO Client |

## Quick Start

```bash
cd tutorials/02-s3-storage

./scripts/setup-cluster.sh
./scripts/build-image.sh
./scripts/setup-minio.sh
./scripts/setup-spark-rbac.sh
./scripts/setup-history-server.sh
```

## Verify MinIO

```bash
kubectl -n minio port-forward svc/minio 9000:9000 &
mc alias set local http://localhost:9000 minioadmin minioadmin123
mc ls local/spark-data/input/
```

---

## Option A: Client Mode

In client mode, the driver runs on your local machine and needs direct access to MinIO via port-forward.

### Setup

Set credentials for the local driver:

```bash
export AWS_ACCESS_KEY_ID=minioadmin
export AWS_SECRET_ACCESS_KEY=minioadmin123
```

Ensure MinIO port-forward is active:

```bash
kubectl -n minio port-forward svc/minio 9000:9000 &
```

### Submit the Job

```bash
$SPARK_HOME/bin/spark-submit \
  --master k8s://https://127.0.0.1:6443 \
  --deploy-mode client \
  --name wordcount-client-s3 \
  --conf spark.kubernetes.namespace=spark \
  --conf spark.kubernetes.authenticate.driver.serviceAccountName=spark \
  --conf spark.kubernetes.container.image=spark-registry:5111/spark-custom:v1.0 \
  --conf spark.kubernetes.container.image.pullPolicy=IfNotPresent \
  --conf spark.executor.instances=2 \
  --conf spark.executor.memory=512m \
  --conf spark.executor.cores=1 \
  --conf spark.driver.memory=512m \
  --conf spark.driver.host=$(hostname -I | awk '{print $1}') \
  --conf spark.driver.port=7078 \
  --conf spark.hadoop.fs.s3a.impl=org.apache.hadoop.fs.s3a.S3AFileSystem \
  --conf spark.hadoop.fs.s3a.endpoint=http://localhost:9000 \
  --conf spark.hadoop.fs.s3a.path.style.access=true \
  --conf spark.hadoop.fs.s3a.connection.ssl.enabled=false \
  --conf spark.kubernetes.executor.conf.spark.hadoop.fs.s3a.endpoint=http://minio.minio.svc.cluster.local:9000 \
  --conf spark.kubernetes.executor.secretKeyRef.AWS_ACCESS_KEY_ID=minio-credentials:AWS_ACCESS_KEY_ID \
  --conf spark.kubernetes.executor.secretKeyRef.AWS_SECRET_ACCESS_KEY=minio-credentials:AWS_SECRET_ACCESS_KEY \
  --conf spark.eventLog.enabled=true \
  --conf spark.eventLog.dir=s3a://spark-logs/event-logs/ \
  /opt/spark-apps/wordcount.py \
  s3a://spark-data/input/sample-input.txt \
  s3a://spark-data/output/wordcount-client-s3
```

---

## Option B: Cluster Mode (Production)

In cluster mode, both driver and executors run as Kubernetes pods. No port-forwards or local environment variables needed.

**Critical difference**: In cluster mode, both driver AND executor pods need credentials injected via Kubernetes Secrets.

### Submit the Job

```bash
$SPARK_HOME/bin/spark-submit \
  --master k8s://https://127.0.0.1:6443 \
  --deploy-mode cluster \
  --name wordcount-cluster-s3 \
  --conf spark.kubernetes.namespace=spark \
  --conf spark.kubernetes.authenticate.driver.serviceAccountName=spark \
  --conf spark.kubernetes.container.image=spark-registry:5111/spark-custom:v1.0 \
  --conf spark.kubernetes.container.image.pullPolicy=IfNotPresent \
  --conf spark.executor.instances=2 \
  --conf spark.executor.memory=512m \
  --conf spark.executor.cores=1 \
  --conf spark.driver.memory=512m \
  --conf spark.hadoop.fs.s3a.impl=org.apache.hadoop.fs.s3a.S3AFileSystem \
  --conf spark.hadoop.fs.s3a.endpoint=http://minio.minio.svc.cluster.local:9000 \
  --conf spark.hadoop.fs.s3a.path.style.access=true \
  --conf spark.hadoop.fs.s3a.connection.ssl.enabled=false \
  --conf spark.kubernetes.driver.secretKeyRef.AWS_ACCESS_KEY_ID=minio-credentials:AWS_ACCESS_KEY_ID \
  --conf spark.kubernetes.driver.secretKeyRef.AWS_SECRET_ACCESS_KEY=minio-credentials:AWS_SECRET_ACCESS_KEY \
  --conf spark.kubernetes.executor.secretKeyRef.AWS_ACCESS_KEY_ID=minio-credentials:AWS_ACCESS_KEY_ID \
  --conf spark.kubernetes.executor.secretKeyRef.AWS_SECRET_ACCESS_KEY=minio-credentials:AWS_SECRET_ACCESS_KEY \
  --conf spark.eventLog.enabled=true \
  --conf spark.eventLog.dir=s3a://spark-logs/event-logs/ \
  local:///opt/spark-apps/wordcount.py \
  s3a://spark-data/input/sample-input.txt \
  s3a://spark-data/output/wordcount-cluster-s3
```

---

## Client vs Cluster Mode Comparison

| Aspect | Client Mode | Cluster Mode |
|--------|-------------|--------------|
| `--deploy-mode` | `client` | `cluster` |
| Driver location | Local machine | Kubernetes pod |
| Application path | `/opt/spark-apps/...` | `local:///opt/spark-apps/...` |
| MinIO endpoint | `localhost:9000` (port-forward) | `minio.minio.svc.cluster.local:9000` |
| Credential injection | Executors only | **Driver AND executors** |
| `spark.driver.host` | Required | Not needed |
| Port-forward required | Yes | No |
| Use case | Development | **Production** |

---

## S3A Configuration Reference

| Parameter | Purpose |
|-----------|---------|
| `spark.hadoop.fs.s3a.impl` | Registers S3A filesystem |
| `spark.hadoop.fs.s3a.endpoint` | MinIO/S3 endpoint URL |
| `spark.hadoop.fs.s3a.path.style.access=true` | **Required for MinIO** |
| `spark.hadoop.fs.s3a.connection.ssl.enabled` | Set `false` for local MinIO |
| `spark.kubernetes.*.secretKeyRef.*` | Injects credentials into pods |

---

## Verification

Monitor pods:

```bash
kubectl -n spark get pods -w
```

View driver logs (cluster mode):

```bash
kubectl -n spark logs -l spark-role=driver --tail=50
```

Check output in MinIO:

```bash
kubectl -n minio port-forward svc/minio 9000:9000 &
mc alias set local http://localhost:9000 minioadmin minioadmin123
mc ls local/spark-data/output/
mc cat local/spark-data/output/wordcount-cluster-s3/part-00000*
```

Access History Server:

```bash
kubectl -n spark port-forward svc/spark-history-server 18080:18080
# Open http://localhost:18080
```

## Troubleshooting

### 403 Forbidden Error

Ensure all credential secretKeyRef lines are present. In cluster mode, you need **four** lines (driver + executor):

```bash
--conf spark.kubernetes.driver.secretKeyRef.AWS_ACCESS_KEY_ID=minio-credentials:AWS_ACCESS_KEY_ID
--conf spark.kubernetes.driver.secretKeyRef.AWS_SECRET_ACCESS_KEY=minio-credentials:AWS_SECRET_ACCESS_KEY
--conf spark.kubernetes.executor.secretKeyRef.AWS_ACCESS_KEY_ID=minio-credentials:AWS_ACCESS_KEY_ID
--conf spark.kubernetes.executor.secretKeyRef.AWS_SECRET_ACCESS_KEY=minio-credentials:AWS_SECRET_ACCESS_KEY
```

### Application File Not Found (Cluster Mode)

Use `local://` (not `file://`) for the application path:

```bash
local:///opt/spark-apps/wordcount.py   # Correct
file:///opt/spark-apps/wordcount.py    # Wrong
```

## Cleanup

```bash
kubectl -n spark delete pods -l spark-role=driver
kubectl -n spark delete pods -l spark-role=executor
pkill -f "port-forward.*minio.*9000" 2>/dev/null || true
./scripts/cleanup.sh
```

## Summary

You've completed both tutorials:

| Tutorial | Storage | Key Pattern |
|----------|---------|-------------|
| 01 - PVC Storage | NFS Volume | Filesystem mount, simple setup |
| 02 - S3 Storage | MinIO (S3A) | Cloud-native, **production pattern** |

The cluster mode + S3 pattern is what you'd use in production with AWS S3, GCS, or Azure Blob Storage.
