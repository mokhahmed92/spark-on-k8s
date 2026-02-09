# Tutorial 01: Spark on Kubernetes with PVC Storage

**Storage**: PVC (Mounted Volume)
**Modes**: Client and Cluster
**Difficulty**: Beginner

## Overview

In this tutorial you will run a PySpark word count job on Kubernetes using **mounted volumes** for data storage. You'll learn both deployment modes:

- **Client mode**: Driver runs inside a submitter pod, executors run as K8s pods
- **Cluster mode**: Both driver and executors run as K8s pods (production-recommended)

The storage pattern uses a **PersistentVolumeClaim (PVC) backed by NFS**. Spark pods mount a shared volume and read/write data as if working with a local directory.

## Architecture

> Full diagram: [docs/architecture.excalidraw](docs/architecture.excalidraw) (open with [excalidraw.com](https://excalidraw.com))

```
 ┌──────────────────┐            ┌──────────────────┐
 │  Local Machine   │  kubectl   │  K8s API Server  │
 │  (WSL/Terminal)  │──────────▶ │                  │
 └──────────────────┘  apply /   └────────┬─────────┘
                       logs               │
                                  ② creates pods
                                  (ServiceAccount)
                                          │
  ┌ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─│─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ┐
  │ K8s cluster (namespace: spark)        ▼                       │
  │                  ┌──────────────────────────────┐             │
  │                  │ spark-submitter-headless      │             │
  │                  │ (Headless Service — DNS)      │             │
  │                  └──────────────┬───────────────┘             │
  │                    DNS resolves │ driver hostname              │
  │                                ▼                              │
  │       ③ creates  ┌──────────────────────────────┐             │
  │        executors │  spark-submitter Pod          │  ─────┐    │
  │      ┌─────────▶ │  ┌────────────────────────┐  │       │    │
  │      │ via K8s   │  │ Spark Driver Process    │  │       │    │
  │      │ API       │  │ spark-submit --client   │  │       │    │
  │      │           │  └────────────────────────┘  │       │    │
  │      │           │  /data       /mnt/spark-events│       │    │
  │      │           └───────┬──────────────┬───────┘       │    │
  │      │           ④ tasks │              │ tasks         │    │
  │      │            + shuffle             │ + shuffle      │    │
  │      │                  │              │               │    │
  │      │                  ▼              ▼               ▼    │
  │  ┌───┴──────────────┐  ┌──────────────────┐  ┌──────────┐ │
  │  │  Executor Pod 1  │  │  Executor Pod 2  │  │ NFS PVC  │ │
  │  │  /data           │  │  /data           │  │ data +   │ │
  │  │  /mnt/spark-events│  │  /mnt/spark-events│  │ events   │ │
  │  └────────┬─────────┘  └────────┬─────────┘  └──────────┘ │
  │           │      ⑤ shared       │                 ▲        │
  │           └──────── storage ────┘─────────────────┘        │
  └ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ┘
```

**Communication flow:**

1. **User → K8s API** — `kubectl apply` creates the submitter pod; `kubectl logs -f` streams output
2. **K8s API → Submitter Pod** — Pod is created with the `spark` ServiceAccount and PVC mounts
3. **Driver → K8s API** — The driver (running inside the submitter pod) creates executor pods using the ServiceAccount token mounted at `/var/run/secrets/`
4. **Executors ↔ Driver** — Executors connect back to the driver via the headless Service DNS name (`spark-submitter.spark-submitter-headless.spark.svc.cluster.local`). Task scheduling and shuffle data flow over this connection
5. **All pods → NFS PVC** — The driver and all executors mount the same NFS-backed PVCs for shared data (`spark-data-pvc`) and event logs (`spark-events-pvc`)

## Prerequisites

| Tool | Minimum Version | Purpose |
|------|----------------|---------|
| Docker | 24.x | Container runtime required by k3d |
| k3d | v5.8.3 | Creates local Kubernetes cluster |
| kubectl | v1.31.x | Kubernetes CLI |
| Apache Spark | 3.5.4 | Provides `spark-submit` binary (cluster mode only) |

> **Note**: Client mode uses a submitter pod inside the cluster, so a local Spark
> installation is only needed for cluster mode submissions from your host machine.

## Quick Start

```bash
# Navigate to this tutorial directory
cd 01-pvc-storage

# 1. Build the custom k3s node image with NFS client support
#    (k3s default images lack mount.nfs, so NFS-backed PVCs won't mount)
docker build -t k3s-nfs:v1.31.5-k3s1 -f manifests/k3d/Dockerfile.k3s-nfs manifests/k3d/

# 2. Create the k3d cluster (uses k3s-nfs image from step 1)
./scripts/setup-cluster.sh

# 3. Build and push the custom Spark image
./scripts/build-image.sh

# 4. Set up Spark RBAC
./scripts/setup-spark-rbac.sh

# 5. Deploy NFS provisioner and create data PVC
kubectl apply -f manifests/storage/nfs-provisioner.yaml
kubectl -n nfs-provisioner wait --for=condition=Ready pod -l app=nfs-provisioner --timeout=120s
kubectl apply -f manifests/storage/spark-data-pvc.yaml

# 6. Deploy History Server
./scripts/setup-history-server.sh
```

> **Why a custom node image?** k3d runs k3s inside Docker containers. The default k3s
> images are minimal and do not include NFS client utilities (`mount.nfs`, `rpcbind`).
> Without these, the kubelet cannot mount NFS-backed PVCs — you'll see
> `MountVolume.SetUp failed ... Connection refused`. The `Dockerfile.k3s-nfs` image
> adds `nfs-utils` and starts `rpcbind` via a k3d entrypoint hook so NFS mounts work
> out of the box.

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
kubectl -n spark exec data-loader -- chmod 777 /data/output
kubectl cp code/data/sample-input.txt spark/data-loader:/data/input/sample-input.txt
kubectl -n spark delete pod data-loader
```

---

## Option A: Client Mode (Submitter Pod)

In client mode, the Spark driver runs inside a **submitter pod** in the cluster while executor pods are created alongside it. This approach eliminates the need for a local Spark installation and avoids host networking issues.

### Submit the Job

The submitter pod manifest contains the full spark-submit command. Deploy it to run the job:

```bash
kubectl apply -f manifests/spark/spark-submitter.yaml
kubectl -n spark wait --for=condition=Ready pod/spark-submitter --timeout=60s
```

This creates:
- A **headless Service** (`spark-submitter-headless`) for DNS resolution so executors can connect back to the driver
- A **Pod** (`spark-submitter`) that runs spark-submit directly, with data and events PVCs mounted

### Monitor the Job

Follow the driver logs in real time:

```bash
kubectl -n spark logs -f spark-submitter
```

The pod will complete (status `Completed`) when the job finishes. To rerun with different parameters, delete and recreate:

```bash
kubectl -n spark delete pod spark-submitter
kubectl apply -f manifests/spark/spark-submitter.yaml
```

> **Why a submitter pod?** Running spark-submit from your host machine in client mode
> requires a local Spark installation, BouncyCastle JARs (for k3d's EC keys), correct
> host IP configuration, and a local event log directory. The submitter pod avoids all
> of this — it uses in-cluster networking, ServiceAccount authentication, and direct
> PVC access.

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

> **BouncyCastle requirement**: k3d uses EC (elliptic curve) keys in the kubeconfig.
> Spark's Kubernetes client needs BouncyCastle to parse them. Add these JARs to
> `$SPARK_HOME/jars/`:
> ```bash
> cd $SPARK_HOME/jars
> curl -fsSLO https://repo1.maven.org/maven2/org/bouncycastle/bcpkix-jdk18on/1.78.1/bcpkix-jdk18on-1.78.1.jar
> curl -fsSLO https://repo1.maven.org/maven2/org/bouncycastle/bcprov-jdk18on/1.78.1/bcprov-jdk18on-1.78.1.jar
> curl -fsSLO https://repo1.maven.org/maven2/org/bouncycastle/bcutil-jdk18on/1.78.1/bcutil-jdk18on-1.78.1.jar
> ```

---

## Client vs Cluster Mode Comparison

| Aspect | Client Mode (Submitter Pod) | Cluster Mode |
|--------|---------------------------|--------------|
| `--deploy-mode` | `client` | `cluster` |
| Driver location | Submitter pod in cluster | Dedicated K8s pod |
| `--master` | `k8s://https://kubernetes.default.svc:443` | `k8s://https://127.0.0.1:6443` |
| Application path | `local:///opt/spark-apps/...` | `local:///opt/spark-apps/...` |
| Volume mounts | Submitter + executor pods | Driver AND executor pods |
| `spark.driver.host` | Submitter pod FQDN | Not needed |
| Driver logs | Terminal output (kubectl exec) | `kubectl logs` |
| Local Spark install | Not needed | Required |
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
kubectl -n spark exec spark-submitter -- \
  cat /data/output/wordcount-client-result/_SUCCESS

# View the word count results
kubectl -n spark exec spark-submitter -- \
  bash -c "cat /data/output/wordcount-client-result/*.csv | head -20"
```

Access History Server:

```bash
kubectl -n spark port-forward svc/spark-history-server 18080:18080
# Open http://localhost:18080
```

## Cleanup

```bash
kubectl -n spark delete pod spark-submitter
kubectl -n spark delete svc spark-submitter-headless
kubectl -n spark delete pods -l spark-role=driver
kubectl -n spark delete pods -l spark-role=executor
./scripts/cleanup.sh
```

## What's Next

Continue to **Tutorial 02: S3 Storage with MinIO** to learn cloud-native storage patterns using S3A.
