# Spark on Kubernetes Course

A hands-on tutorial series for running Apache Spark on Kubernetes using k3d, MinIO, and PySpark.

## Tutorials

This course covers two storage patterns, each demonstrating both client and cluster deployment modes:

| Tutorial | Storage | Difficulty | Description |
|----------|---------|------------|-------------|
| [01-pvc-storage](tutorials/01-pvc-storage/) | PVC (NFS) | Beginner | Filesystem-based storage with mounted volumes |
| [02-s3-storage](tutorials/02-s3-storage/) | S3 (MinIO) | Intermediate | Cloud-native object storage (**production pattern**) |

Each tutorial covers both deployment modes:
- **Client mode**: Driver runs locally (for development/debugging)
- **Cluster mode**: Driver runs as K8s pod (for production)

## Technology Stack

- **Apache Spark 3.5.4** with PySpark
- **Kubernetes** via k3d (k3s in Docker)
- **NFS Provisioner** for shared volumes (Tutorial 01)
- **MinIO** for S3-compatible object storage (Tutorial 02)
- **Spark History Server** for job observability

## Prerequisites

| Tool | Minimum Version | Required For |
|------|----------------|--------------|
| Docker | 24.x | All tutorials |
| k3d | v5.8.3 | All tutorials |
| kubectl | v1.31.x | All tutorials |
| Apache Spark | 3.5.4 | All tutorials |
| mc (MinIO Client) | Latest | Tutorial 02 only |

## Quick Start

Choose a tutorial and navigate to its directory:

```bash
cd tutorials/01-pvc-storage
```

Each tutorial is **self-contained** with its own:
- `code/` - Dockerfile, PySpark jobs, sample data
- `manifests/` - Kubernetes YAML files
- `scripts/` - Setup and cleanup scripts
- `README.md` - Step-by-step instructions

## Project Structure

```
spark-on-k8s-course/
├── README.md                    # This file
├── tutorials/
│   ├── 01-pvc-storage/          # Tutorial 1: PVC storage (client + cluster modes)
│   └── 02-s3-storage/           # Tutorial 2: S3 storage (client + cluster modes)
├── docs/
│   └── part-1.0-research.md     # Background research and concepts
└── CLAUDE.md                    # Development guidelines
```

## Key Concepts

### Client vs Cluster Mode

| Aspect | Client Mode | Cluster Mode |
|--------|-------------|--------------|
| Driver location | Your local machine | Kubernetes pod |
| Output visibility | Terminal | `kubectl logs` |
| Use case | Development, debugging | Production |

### PVC vs S3 Storage

| Aspect | PVC (Volume) | S3 (Object Storage) |
|--------|--------------|---------------------|
| Access method | Filesystem mount | HTTP API (S3A) |
| Setup complexity | Requires NFS | Requires credentials |
| Production fit | Limited | Cloud-native |

## Reference Documentation

For detailed background on architecture, design decisions, and concepts, see [docs/part-1.0-research.md](docs/part-1.0-research.md).
