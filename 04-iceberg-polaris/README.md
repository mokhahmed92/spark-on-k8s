# Tutorial 04: Spark on Kubernetes with Apache Iceberg and Polaris Catalog

**Storage**: S3 (MinIO) with Iceberg Table Format
**Catalog**: Apache Polaris (REST Catalog)
**Modes**: Client and Cluster
**Difficulty**: Intermediate–Advanced

## Overview

In this tutorial you will deploy a complete **lakehouse environment** on local Kubernetes (k3d): Apache Spark with the **Apache Iceberg** table format, **Apache Polaris** as the Iceberg REST catalog (backed by PostgreSQL), and **MinIO** for S3-compatible object storage.

```python
# Before (Hive Metastore — Tutorial 03)
df.write.saveAsTable("sales_raw")
spark.sql("SELECT * FROM sales_raw")

# After (Iceberg + Polaris REST Catalog)
df.writeTo("polaris.sales.transactions").partitionedBy("sale_date").createOrReplace()
spark.sql("SELECT * FROM polaris.sales.transactions VERSION AS OF 1")  # Time travel!
spark.sql("ALTER TABLE polaris.sales.transactions ADD COLUMNS (region STRING)")  # Schema evolution!
```

**What Iceberg adds over Hive Metastore:**

| Feature | Hive (Tutorial 03) | Iceberg + Polaris (This Tutorial) |
|---------|--------------------|------------------------------------|
| Table format | Hive managed tables (directory-based) | Iceberg (snapshot-based, immutable) |
| Catalog | Hive Metastore (Thrift) | Polaris REST catalog (HTTP/OAuth2) |
| Data storage | NFS PVC (local filesystem) | MinIO S3 (object storage) |
| Time travel | Not supported | Query any previous snapshot |
| Schema evolution | Limited (add columns only, no safety) | Safe column add/drop/rename/reorder |
| Partition evolution | Requires rewrite | Change partitioning without rewrite |

## Architecture

```
 ┌──────────────────┐              ┌──────────────────┐
 │  Host Machine    │  kubectl     │  K8s API Server  │
 │                  │────────────> │                  │
 └──────────────────┘  apply/logs  └────────┬─────────┘
                                            │
  ┌ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─│─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ┐
  │ K8s cluster                             ▼                                    │
  │                                                                              │
  │  ┌─────────────────────────┐  JDBC   ┌──────────────────────────────────┐   │
  │  │ PostgreSQL (polaris)    │◄────────│ Apache Polaris                   │   │
  │  │ Port 5432               │         │ REST API port 8181               │   │
  │  │ PVC: postgres-data      │         │ Management API port 8182         │   │
  │  │ Database: polaris       │         │ Iceberg table metadata           │   │
  │  └─────────────────────────┘         └──────────────┬───────────────────┘   │
  │                                                     │ REST /api/catalog     │
  │  ┌─────────────────────────┐                        │                       │
  │  │ MinIO (S3 storage)      │                        │                       │
  │  │ API port 9000           │◄───── S3FileIO ────────┤                       │
  │  │ Console port 9001       │  (direct credentials)  │                       │
  │  │ Bucket: iceberg-warehouse│                       │                       │
  │  └─────────────────────────┘                        │                       │
  │                                                     │                       │
  │  ┌──────────────────────────────────────────────────┼───────────────────┐   │
  │  │ Spark Submitter Pod (namespace: spark)           ▼                   │   │
  │  │  spark.sql.catalog.polaris = SparkCatalog (type=rest)                │   │
  │  │  spark.sql.catalog.polaris.uri = http://polaris:8181/api/catalog     │   │
  │  │  spark.sql.catalog.polaris.io-impl = S3FileIO                        │   │
  │  └──────────┬───────────────────────────────────────────────────────────┘   │
  │             │ creates executors                                              │
  │             ▼                                                                │
  │  ┌──────────────────┐  ┌──────────────────┐  ┌───────────────────────────┐  │
  │  │  Executor Pod 1  │  │  Executor Pod 2  │  │  NFS PVC                  │  │
  │  │  S3FileIO → MinIO│  │  S3FileIO → MinIO│  │  /opt/spark/work-dir/events│ │
  │  └──────────────────┘  └──────────────────┘  │  (event logs for History  │  │
  │                                               │   Server)                 │  │
  │  ┌──────────────────────────┐                 └───────────────────────────┘  │
  │  │  Spark History Server    │◄──── reads event logs from NFS PVC             │
  │  │  Port 18080              │                                                │
  │  └──────────────────────────┘                                                │
  └ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ┘

 Ports exposed via k3d:
   localhost:18080 → History Server UI
   localhost:9001  → MinIO Console
   localhost:8181  → Polaris REST API
```

**Components:**

| Component | Namespace | Purpose |
|-----------|-----------|---------|
| PostgreSQL | `polaris` | Stores Polaris catalog metadata (realms, principals, tables) |
| Apache Polaris | `polaris` | Iceberg REST catalog server (OAuth2 authenticated) |
| MinIO | `minio` | S3-compatible object storage for Iceberg data + metadata files |
| NFS Provisioner | `nfs-provisioner` | Enables ReadWriteMany PVCs on k3d (for event logs) |
| Spark RBAC | `spark` | ServiceAccount for executor pod creation |
| History Server | `spark` | Web UI for completed Spark applications |

## Prerequisites

| Tool | Minimum Version | Purpose |
|------|----------------|---------|
| Docker | 24.x | Container runtime required by k3d |
| k3d | v5.8.3 | Creates local Kubernetes cluster |
| kubectl | v1.31.x | Kubernetes CLI |
| jq | 1.6+ | JSON processing in setup scripts |

> **Memory:** This tutorial runs PostgreSQL + Polaris + MinIO + History Server + Spark.
> Recommend allocating **8GB+ memory** to Docker.

> **No local Spark installation required.** Both client and cluster modes use
> submitter pods that run spark-submit from inside the cluster.

## Quick Start

```bash
# Navigate to this tutorial directory
cd 04-iceberg-polaris

# 1. Create k3d cluster with NFS-capable nodes + local registry
./scripts/setup-cluster.sh

# 2. Build custom Spark image (Spark 3.5.4 + Iceberg 1.10.1 JARs)
./scripts/build-image.sh

# 3. Deploy MinIO (S3-compatible storage) + create iceberg-warehouse bucket
./scripts/setup-minio.sh

# 4. Deploy PostgreSQL + Polaris catalog + bootstrap + create spark_warehouse catalog
./scripts/setup-polaris.sh

# 5. Configure Spark RBAC (namespace, service account, roles)
./scripts/setup-spark-rbac.sh

# 6. Deploy Spark History Server (NFS PVC for event logs)
./scripts/setup-history-server.sh
```

> **Why a custom node image?** k3d runs k3s inside Docker containers. The default k3s
> images are minimal and do not include NFS client utilities (`mount.nfs`, `rpcbind`).
> Without these, the kubelet cannot mount NFS-backed PVCs — you'll see
> `MountVolume.SetUp failed ... Connection refused`. The `Dockerfile.k3s-nfs` image
> adds `nfs-utils` and starts `rpcbind` via a k3d entrypoint hook so NFS mounts work
> out of the box.

## Verify Infrastructure

```bash
# Check all pods are running
kubectl get pods -A

# Expected output (all Running/Completed):
# minio     minio-...           1/1   Running
# polaris   postgres-...        1/1   Running
# polaris   polaris-...         1/1   Running
# polaris   polaris-bootstrap   0/1   Completed
# spark     spark-history-...   1/1   Running

# Verify MinIO Console is accessible
# Open http://localhost:9001 (minioadmin/minioadmin)

# Verify Polaris REST API responds
curl -s http://localhost:8181/api/catalog/v1/config | jq .

# Verify History Server
# Open http://localhost:18080
```

---

## Option A: Client Mode (Submitter Pod)

In client mode, the Spark driver runs inside a **submitter pod** in the cluster while executor pods are created alongside it.

### Submit the Job

```bash
kubectl apply -f manifests/spark/spark-submitter-client.yaml
kubectl -n spark wait --for=condition=Ready pod/spark-submitter --timeout=120s
```

### Monitor the Job

```bash
kubectl -n spark logs -f spark-submitter
```

Expected output includes:

```
PHASE 1: Basic ETL — CSV to Iceberg Tables
  Loaded 10 rows from sales.csv
  Written 10 rows to polaris.sales.transactions
  Written 2 rows to polaris.sales.sales_summary

PHASE 2: Iceberg Features Demo
  Feature 1: After append: 13 total rows (expected 13)
  Feature 2: Snapshot #1 row count: 10 (expected 10)
  Feature 3: Column 'region' added successfully.

VERIFICATION SUMMARY
  Transactions table:  13 rows (expected 13)
  Sales summary table: 2 rows (expected 2)
  Has 'region' column: True
  ALL CHECKS PASSED
```

To rerun with different parameters:

```bash
kubectl -n spark delete pod spark-submitter --ignore-not-found
kubectl -n spark delete svc spark-submitter-headless --ignore-not-found
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
kubectl -n spark delete pod spark-submitter-cluster --ignore-not-found
kubectl -n spark delete pods -l spark-role=driver --ignore-not-found
kubectl apply -f manifests/spark/spark-submitter-cluster.yaml
```

---

## How the Iceberg Lakehouse Works

### Data Flow

```
sales.csv → PySpark ETL → Polaris Catalog (metadata) → MinIO S3 (data files)
```

1. **Read CSV** — Spark reads `/opt/spark-data/sales.csv` baked into the Docker image
2. **Transform** — Adds computed `total_amount = amount * quantity` column
3. **Write Iceberg table** — `df.writeTo("polaris.sales.transactions")` calls:
   - Polaris REST API to register table metadata (schema, partitioning, snapshot)
   - MinIO S3 via S3FileIO to write Parquet data files
4. **Iceberg features** — Append (new snapshot), time travel (query old snapshot), schema evolution (add column)

### Spark Configuration

All catalog configuration is passed via `--conf` flags in the submitter manifests:

```
# Iceberg SQL extensions (enables MERGE INTO, time travel, schema evolution)
--conf spark.sql.extensions=org.apache.iceberg.spark.extensions.IcebergSparkSessionExtensions

# Named catalog "polaris" using Iceberg REST protocol
--conf spark.sql.catalog.polaris=org.apache.iceberg.spark.SparkCatalog
--conf spark.sql.catalog.polaris.type=rest
--conf spark.sql.catalog.polaris.uri=http://polaris.polaris.svc.cluster.local:8181/api/catalog
--conf spark.sql.catalog.polaris.warehouse=spark_warehouse

# OAuth2 authentication to Polaris
--conf spark.sql.catalog.polaris.credential=root:s3cr3t

# S3FileIO — Spark reads/writes data files directly to MinIO
--conf spark.sql.catalog.polaris.io-impl=org.apache.iceberg.aws.s3.S3FileIO
--conf spark.sql.catalog.polaris.s3.endpoint=http://minio.minio.svc.cluster.local:9000
```

| Config | Purpose |
|--------|---------|
| `spark.sql.catalog.polaris` | Register Iceberg SparkCatalog under the name "polaris" |
| `polaris.type=rest` | Use the Iceberg REST catalog protocol |
| `polaris.uri` | Polaris REST API endpoint |
| `polaris.warehouse` | Catalog name created in Polaris during setup |
| `polaris.credential` | OAuth2 client credentials (`client_id:client_secret`) |
| `polaris.io-impl` | Use S3FileIO for data file I/O (not HadoopFileIO) |
| `polaris.s3.endpoint` | MinIO S3-compatible endpoint |
| `polaris.s3.path-style-access` | Required for MinIO (not AWS virtual-hosted style) |

### Iceberg Features Demonstrated

| Feature | What the ETL Job Does |
|---------|----------------------|
| **Table creation** | `df.writeTo("polaris.sales.transactions").partitionedBy("sale_date").createOrReplace()` |
| **Append** | Adds 3 new rows → creates snapshot #2 (13 total rows) |
| **Time travel** | Queries snapshot #1 via `VERSION AS OF` → returns 10 rows (original data) |
| **Schema evolution** | `ALTER TABLE ... ADD COLUMNS (region STRING)` — no data rewrite needed |
| **Aggregation** | Writes `polaris.sales.sales_summary` with category-level totals |

---

## Verification

Check infrastructure pods:

```bash
kubectl get pods -A
```

Check Iceberg tables in Polaris catalog:

```bash
# Get OAuth2 token
TOKEN=$(kubectl exec -n polaris deploy/polaris -- \
  curl -s http://localhost:8181/api/catalog/v1/oauth/tokens \
  -d "grant_type=client_credentials&client_id=root&client_secret=s3cr3t&scope=PRINCIPAL_ROLE:ALL" \
  | jq -r .access_token)

# List namespaces in spark_warehouse catalog
kubectl exec -n polaris deploy/polaris -- \
  curl -s -H "Authorization: Bearer $TOKEN" \
  http://localhost:8181/api/catalog/v1/spark_warehouse/namespaces | jq .

# List tables in sales namespace
kubectl exec -n polaris deploy/polaris -- \
  curl -s -H "Authorization: Bearer $TOKEN" \
  http://localhost:8181/api/catalog/v1/spark_warehouse/namespaces/sales/tables | jq .
```

Check data files in MinIO:

```bash
kubectl exec -n minio deploy/minio -- \
  mc ls local/iceberg-warehouse/sales/ --recursive
```

Access History Server:

```bash
# Open http://localhost:18080 — completed job should be visible
```

## Cleanup

```bash
# Delete submitter pods
kubectl -n spark delete pod spark-submitter --ignore-not-found
kubectl -n spark delete svc spark-submitter-headless --ignore-not-found
kubectl -n spark delete pod spark-submitter-cluster --ignore-not-found

# Delete Spark driver/executor pods
kubectl -n spark delete pods -l spark-role=driver --ignore-not-found
kubectl -n spark delete pods -l spark-role=executor --ignore-not-found

# Tear down the entire cluster
./scripts/cleanup.sh
```

## Troubleshooting

| Symptom | Likely Cause | Fix |
|---------|-------------|-----|
| Pod `ErrImagePull` | Image not in k3d registry | Re-run `./scripts/build-image.sh` |
| Polaris `Connection refused` | PostgreSQL not ready | Wait 30s, check `kubectl logs -n polaris deploy/postgres` |
| Spark job `REST catalog error` | Polaris not bootstrapped | Re-run `./scripts/setup-polaris.sh` |
| `NoSuchBucket` error | MinIO bucket missing | Re-run `./scripts/setup-minio.sh` |
| `S3Exception: Access Denied` | Wrong MinIO credentials | Verify credentials in spark-submitter YAML match MinIO secret |
| NFS mount failures | k3s node missing NFS utils | Rebuild k3s-nfs image via `./scripts/setup-cluster.sh` |
| History Server empty | Event logs not written | Check PVC mount and `spark.eventLog.dir` config |
| `Table already exists` | Rerunning without cleanup | Delete submitter pod, re-apply — ETL uses `createOrReplace()` |

## What's Next

This tutorial introduced the Iceberg lakehouse pattern with Polaris REST catalog. You've learned how Spark, Iceberg, Polaris, and MinIO work together to provide:

- **Open table format** — Iceberg provides snapshot isolation, time travel, and schema evolution
- **REST catalog** — Polaris exposes an HTTP API (not Thrift) with OAuth2 authentication
- **Object storage** — S3FileIO writes Parquet data directly to MinIO, decoupling compute from storage
- **Production patterns** — The same architecture works with AWS S3, Azure ADLS, or GCS in production
