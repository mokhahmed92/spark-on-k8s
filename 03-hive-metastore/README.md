# Tutorial 03: Spark on Kubernetes with Hive Metastore

**Storage**: S3 (MinIO) with Hive Managed Tables
**Modes**: Client and Cluster
**Difficulty**: Intermediate

## Overview

In this tutorial you will add a **Hive Metastore** to the Spark-on-Kubernetes setup. Instead of reading and writing files with hard-coded paths, your PySpark jobs will use **named tables**:

```python
# Before (file-based)
df = spark.read.csv("s3a://spark-data/input/sales.csv")
df.write.parquet("s3a://spark-data/output/result")

# After (table-based with Hive Metastore)
df.write.saveAsTable("sales_raw")
spark.sql("SELECT * FROM sales_raw")
```

The metastore stores table metadata (schemas, file locations) in PostgreSQL. Spark pods read/write the actual Parquet data files on MinIO via S3A — the metastore never touches the data files.

## Architecture

```
 ┌──────────────────┐              ┌──────────────────┐
 │  Host Machine    │  kubectl     │  K8s API Server  │
 │                  │────────────> │                  │
 └──────────────────┘  apply/logs  └────────┬─────────┘
                                            │
  ┌ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─│─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ┐
  │ K8s cluster                             ▼                           │
  │                                                                     │
  │  ┌─────────────────────────┐  JDBC   ┌──────────────────────────┐  │
  │  │ PostgreSQL (metastore)  │◄────────│ Hive Metastore           │  │
  │  │ Port 5432               │         │ Thrift port 9083         │  │
  │  │ PVC: postgres-data      │         │ Schema init: schematool  │  │
  │  │ Database: metastore_db  │         │ (metadata only, no data) │  │
  │  └─────────────────────────┘         └────────────┬─────────────┘  │
  │                                                   │ thrift://      │
  │                                                   │                │
  │  ┌────────────────────────────────────────────────┼────────────┐   │
  │  │ Spark Submitter Pod (namespace: spark)         ▼            │   │
  │  │  spark.sql.catalogImplementation=hive                       │   │
  │  │  spark.hadoop.hive.metastore.uris=thrift://...:9083         │   │
  │  │  spark.sql.warehouse.dir=s3a://spark-data/warehouse         │   │
  │  └──────────┬──────────────────────────────────────────────────┘   │
  │             │ creates executors                                     │
  │             ▼                                                       │
  │  ┌──────────────────┐  ┌──────────────────┐  ┌──────────────────┐  │
  │  │  Executor Pod 1  │  │  Executor Pod 2  │  │  MinIO (S3)      │  │
  │  │  S3A ──────────────────────────────────────► spark-data/     │  │
  │  │                  │  │                  │  │   warehouse/      │  │
  │  └──────────────────┘  └──────────────────┘  │   input/         │  │
  │                                              │  spark-logs/     │  │
  │                                              │   event-logs/    │  │
  │                                              └──────────────────┘  │
  └ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ┘
```

**Key insight:** The Hive Metastore is metadata-only. It stores table schemas and file locations in PostgreSQL. It does NOT access the actual data files. Spark pods read/write Parquet files on MinIO via S3A directly.

**Components:**

| Component | Namespace | Purpose |
|-----------|-----------|---------|
| MinIO | `minio` | S3-compatible object storage for data and event logs |
| PostgreSQL | `metastore` | Stores Hive metadata (schemas, table locations) |
| Hive Metastore | `metastore` | Thrift service that Spark connects to |
| Spark RBAC | `spark` | ServiceAccount for executor pod creation |
| History Server | `spark` | Web UI for completed Spark applications |

## Prerequisites

| Tool | Minimum Version | Purpose |
|------|----------------|---------|
| Docker | 24.x | Container runtime required by k3d |
| k3d | v5.8.3 | Creates local Kubernetes cluster |
| kubectl | v1.31.x | Kubernetes CLI |
| mc | latest | MinIO Client for bucket management |

> **Memory:** This tutorial runs MinIO + PostgreSQL + Hive Metastore + History Server + Spark.
> Recommend allocating **8GB+ memory** to Docker.

> **No local Spark installation required.** Both client and cluster modes use
> submitter pods that run spark-submit from inside the cluster.

## Quick Start

```bash
# Navigate to this tutorial directory
cd 03-hive-metastore

# 1. Create the k3d cluster
./scripts/setup-cluster.sh

# 2. Build and push the custom Spark image (includes S3A + Hive JARs)
./scripts/build-image.sh

# 3. Deploy MinIO and create buckets (spark-data, spark-logs)
./scripts/setup-minio.sh

# 4. Set up Spark RBAC + MinIO credentials
./scripts/setup-spark-rbac.sh

# 5. Deploy PostgreSQL + Hive Metastore
./scripts/setup-metastore.sh

# 6. Deploy History Server (S3-backed)
./scripts/setup-history-server.sh
```

## Option A: Client Mode (Submitter Pod)

In client mode, the Spark driver runs inside a **submitter pod** in the cluster while executor pods are created alongside it.

### Submit the Job

```bash
kubectl apply -f manifests/spark/spark-submitter-client.yaml
kubectl -n spark wait --for=condition=Ready pod/spark-submitter --timeout=60s
```

### Monitor the Job

```bash
kubectl -n spark logs -f spark-submitter
```

Expected output includes:

```
=== Step 1: Reading CSV from s3a://spark-data/input/sales.csv ===
Read 24 rows from CSV
...
=== Step 2: Listing tables in default database ===
Tables in default database: ['sales_raw']
...
=== Step 4: Creating summary table ===
Created managed table: sales_summary
...
=== Step 5: Reading back from sales_summary ===
sales_summary contains 3 rows
```

To rerun with different parameters:

```bash
kubectl -n spark delete pod spark-submitter
kubectl -n spark delete svc spark-submitter-headless
kubectl apply -f manifests/spark/spark-submitter-client.yaml
```

---

## Option B: Cluster Mode (Submitter Pod)

In cluster mode, both the driver and executors run as Kubernetes pods. The submitter pod sends the job to the K8s API and exits immediately (fire-and-forget).

### Submit the Job

```bash
kubectl apply -f manifests/spark/spark-submitter-cluster.yaml
```

### Monitor the Job

```bash
# Watch pods — the submitter completes quickly, then a driver pod appears
kubectl -n spark get pods -w

# Follow the driver logs
kubectl -n spark logs -f -l spark-role=driver --tail=50
```

To rerun:

```bash
kubectl -n spark delete pod spark-submitter-cluster
kubectl -n spark delete pods -l spark-role=driver
kubectl apply -f manifests/spark/spark-submitter-cluster.yaml
```

---

## How the Hive Metastore Works

### Without Metastore (Tutorials 01-02)

```python
# Hard-coded paths — fragile, no schema enforcement
df = spark.read.csv("s3a://spark-data/input/sales.csv")
result.write.parquet("s3a://spark-data/output/sales-summary")
```

### With Metastore (This Tutorial)

```python
# Table names — schema tracked, location managed by metastore
df.write.saveAsTable("sales_raw")          # Creates Parquet at s3a://spark-data/warehouse/sales_raw/
result = spark.sql("SELECT * FROM sales_summary")  # Metastore resolves location
```

**What happens under the hood:**

1. `saveAsTable("sales_raw")` — Spark writes Parquet files to `s3a://spark-data/warehouse/sales_raw/` on MinIO, then registers the table schema and location in the Hive Metastore (via Thrift → PostgreSQL)
2. `spark.sql("SELECT * FROM sales_raw")` — Spark asks the metastore for the table schema and file location, then reads the Parquet files directly from MinIO via S3A
3. The metastore never reads or writes data files — it only stores metadata

### Spark Configuration

```
# S3A configuration for MinIO
--conf spark.hadoop.fs.s3a.impl=org.apache.hadoop.fs.s3a.S3AFileSystem
--conf spark.hadoop.fs.s3a.endpoint=http://minio.minio.svc.cluster.local:9000
--conf spark.hadoop.fs.s3a.path.style.access=true
--conf spark.hadoop.fs.s3a.connection.ssl.enabled=false

# Hive Metastore configuration
--conf spark.sql.catalogImplementation=hive
--conf spark.hadoop.hive.metastore.uris=thrift://hive-metastore.metastore.svc.cluster.local:9083
--conf spark.sql.warehouse.dir=s3a://spark-data/warehouse
```

| Config | Purpose |
|--------|---------|
| `fs.s3a.*` | S3A filesystem settings for MinIO access |
| `catalogImplementation=hive` | Use Hive metastore instead of in-memory catalog |
| `hive.metastore.uris` | Thrift endpoint of the standalone Hive Metastore |
| `warehouse.dir` | Default location for managed table data files (S3) |

---

## Verification

Check metastore pods:

```bash
kubectl -n metastore get pods
```

Check MinIO buckets:

```bash
kubectl -n minio port-forward svc/minio 9000:9000 &
mc alias set local http://localhost:9000 minioadmin minioadmin123
mc ls local/spark-data/warehouse/
# Expected: sales_raw/  sales_summary/
```

Check Spark job output (client mode):

```bash
# Look for table creation confirmation in logs
kubectl -n spark logs spark-submitter | grep "Tables in default database"
```

Access History Server:

```bash
kubectl -n spark port-forward svc/spark-history-server 18080:18080
# Open http://localhost:18080
```

## Cleanup

```bash
# Delete submitter pods
kubectl -n spark delete pod spark-submitter --ignore-not-found
kubectl -n spark delete svc spark-submitter-headless --ignore-not-found
kubectl -n spark delete pod spark-submitter-cluster --ignore-not-found

# Delete Spark driver/executor pods
kubectl -n spark delete pods -l spark-role=driver
kubectl -n spark delete pods -l spark-role=executor

# Tear down the entire cluster
./scripts/cleanup.sh
```

## What's Next

This tutorial introduced the Hive Metastore for table-based data management with S3 storage (MinIO). Future tutorials will replace the Hive Metastore with Apache Iceberg + Polaris for modern lakehouse features.
