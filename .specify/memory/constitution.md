<!--
  ============================================================
  SYNC IMPACT REPORT
  ============================================================
  Version change: (new) → 1.0.0
  This is the initial ratification — no prior version exists.

  Added Principles:
    I.   Freshness & Validation
    II.  Security Baseline
    III. Supply Chain & Policy
    IV.  Reliability & Scaling
    V.   Observability & Ops
    VI.  Networking & Ingress
    VII. Data & Governance
    VIII.MLOps & Model Governance
    IX.  CI/CD & GitOps
    X.   Packaging & Manifests
    XI.  Cost & Efficiency
    XII. Docs & Auditability

  Added Sections:
    - Scope (includes/excludes)
    - Defaults & Tooling
    - Response Schema
    - Self-Checklist for Every Output
    - Anti-Patterns
    - Governance & Compliance
    - Outputs Style
    - Contex7 Usage Notes
    - Success Criteria

  Removed Sections: (none — initial population)

  Templates requiring updates:
    - .specify/templates/plan-template.md         ⚠ pending
      (Constitution Check section references generic
      "[Gates determined based on constitution file]" —
      update with principle names on next /speckit.plan run)
    - .specify/templates/spec-template.md          ✅ no update needed
      (Generic template; constitution principles applied
      at plan/task time, not spec time)
    - .specify/templates/tasks-template.md          ⚠ pending
      (Phase N: Polish section should reference
      security, observability, cost, and policy
      principle-driven tasks on next /speckit.tasks run)

  Follow-up TODOs: none
  ============================================================
-->

# Infrastructure, Data & AI on Kubernetes — Cloud-Native & DevOps Constitution

**Owner**: Platform Engineering & MLOps Guild

## Objectives

- Build and operate reliable, secure, observable, and
  cost-aware platforms for data and AI workloads on
  Kubernetes using cloud-native services.
- Standardize GitOps-first delivery, IaC, and
  policy-as-code to minimize drift and enforce compliance.
- Ensure model, data, and pipeline lifecycle integrity
  (train -> evaluate -> deploy -> monitor -> retrain).
- Always reflect **current** best practices and stable
  releases by consulting **contex7** prior to generating
  outputs.

## Scope

### Includes

- Kubernetes (managed or self-managed): infra, platform
  services, controllers, workloads.
- Data platforms (batch, streaming, feature stores), ML
  pipelines, training & inference.
- CI/CD, GitOps, IaC, policy, security, networking,
  observability, SRE practices.

### Excludes

- One-off, non-repeatable scripting without codification
  or documentation.
- Deployments bypassing review, policy checks, or
  traceability.

## Core Principles

### I. Freshness & Validation

- Before generating code, manifests, or commands, agents
  MUST use **contex7** to verify versions, APIs, flags,
  and deprecations.
- Agents MUST prefer LTS/stable versions and clearly
  annotate version constraints and migration notes.
- If information conflicts, agents MUST default to the
  most recent stable provider documentation and cite
  sources in comments where applicable.

### II. Security Baseline

- Default deny. Enforce Kubernetes **Pod Security
  Standards (restricted)**, **NetworkPolicy**, and
  least-privilege **RBAC**.
- Run containers as non-root, drop unnecessary
  capabilities, use **distroless** or minimal base images.
- Generate **SBOM** (CycloneDX/SPDX) and sign artifacts
  with **Sigstore cosign**; verify at admission with
  **Kyverno** or **OPA Gatekeeper**.
- Manage secrets with **External Secrets Operator** backed
  by **KMS/Key Vault/Cloud KMS**; never inline secrets.
- Encrypt data in transit (mTLS via service mesh where
  applicable) and at rest (provider-managed keys or CMEK).

### III. Supply Chain & Policy

- Enforce **policy-as-code** (OPA/Conftest/Kyverno) for
  IaC and manifests in CI and at admission.
- Require image provenance (SLSA-aligned) and tag pinning
  or digest pinning for production.
- Block `:latest` images; require semantic versioning and
  release notes.

### IV. Reliability & Scaling

- Use **HPA** (CPU/memory/custom metrics), **PDBs**,
  **startup/liveness/readiness** probes, **ResourceQuota**
  and **LimitRange**.
- Isolate workloads via namespaces, node pools,
  taints/tolerations, and topology spread constraints.
- Design DR: backups (etcd if self-managed, stateful app
  data), restore tests, multi-AZ/region patterns based on
  RTO/RPO.

### V. Observability & Ops

- Standardize **OpenTelemetry** for traces/metrics/logs;
  **Prometheus** + **Alertmanager** for metrics;
  **Loki**/**ELK** for logs.
- Create SLOs/SLIs/Error Budgets; codify runbooks and
  alerts (actionable, deduplicated, with clear ownership).

### VI. Networking & Ingress

- Use cloud load balancers or Ingress Controllers (e.g.,
  NGINX/Contour/ALB/GCLB) with TLS everywhere.
- Mandate **Zero Trust** principles, API authN/Z
  (OIDC/JWT), and per-namespace **NetworkPolicy**.
- For interservice auth and encryption, prefer a **service
  mesh** (Istio/Linkerd) where complexity is justified.

### VII. Data & Governance

- Classify data (public/internal/confidential/regulated).
  Document lineage and access controls; audit all
  privileged access.
- Use managed data stores unless requirements demand
  self-managed. Ensure PITR/backups and schema evolution
  policies.
- Anonymize/mask non-prod data; comply with data
  residency/regulatory constraints.

### VIII. MLOps & Model Governance

- Use pipelines (e.g., **Kubeflow Pipelines**, **Argo
  Workflows**, or **Airflow**) for training/eval with
  artifact tracking (**MLflow**, **Weights & Biases**).
- Maintain a **Model Registry** (stages: Staging ->
  Production) with approval gates and automated checks
  (bias, drift, security).
- Support inference strategies: canary, blue/green,
  shadow. Capture feature/label drift and performance
  metrics.
- Store features in a **Feature Store** (e.g., **Feast**)
  with reproducibility and backfills.

### IX. CI/CD & GitOps

- IaC-first: **Terraform** (remote state + locking) /
  **Bicep**/**Pulumi** as applicable; PR reviews required.
- **GitOps** (Argo CD or Flux) as the source of truth;
  reconcile desired vs. cluster state; no `kubectl` to
  prod.
- Secure CI/CD: OIDC workload identity, short-lived
  creds, SAST/DAST/IaC scans, container scans
  (Trivy/Grype), license checks.

### X. Packaging & Manifests

- Prefer **Helm** or **Kustomize** with environment
  overlays; parameterize via values and sealed secrets.
- Provide environment matrices (dev/stage/prod) and
  version pinning; document checksum/immutable tags for
  prod.

### XI. Cost & Efficiency

- Autoscale clusters (Cluster Autoscaler/Karpenter). Use
  right-sizing, spot where safe, and cost allocation
  (e.g., OpenCost).
- Set TTLs for ephemeral environments; enforce quotas;
  surface unit economics to teams.

### XII. Docs & Auditability

- Docs-as-code in repo: architecture decisions (ADRs),
  runbooks, playbooks, threat models, and data flow
  diagrams.
- Every change traceable: Conventional Commits, signed
  commits, release notes, changelogs.

## Defaults & Tooling

### Cloud Providers

| Provider | Kubernetes | Networking | Storage | Identity |
|----------|-----------|------------|---------|----------|
| AWS | EKS | VPC CNI, NLB/ALB | EBS/EFS/FSx via CSI | IRSA (OIDC) |
| Azure | AKS | Azure CNI/UG, App Gateway | Managed Disks/File | Managed Identity (federated) |
| GCP | GKE | VPC-Native, GLB | PD/Filestore via CSI | Workload Identity |

### Standard Toolchain

| Concern | Tool(s) |
|---------|---------|
| GitOps | Argo CD |
| IaC | Terraform (with policy checks), modules versioned and documented |
| Policy | Kyverno for K8s; OPA/Conftest for IaC |
| Observability | OpenTelemetry, Prometheus, Grafana, Loki |
| Security Scanning | Trivy, Grype, Semgrep, Checkov, tfsec |
| Feature Store | Feast |
| Model Tracking | MLflow |
| Pipelines | Argo Workflows or Kubeflow Pipelines |
| Secrets | External Secrets Operator + cloud KMS |
| Service Mesh | Istio (opt-in with justification) |

## Response Schema

Every generated output MUST follow this structure:

1. **Plan** — what will be created/changed and why.
2. **Version Matrix** — Kubernetes, CRDs/operators, Helm
   charts, CLIs.
3. **Code/Manifests** — with inline comments and security
   notes.
4. **Validation Steps** — linters, policies, tests, and
   rollout/rollback instructions.
5. **Migration/Deprecation** — considerations and notes.
6. **Operational Runbook** — observability, alerts, SLOs,
   and cost implications.

## Self-Checklist for Every Output

- [ ] Ran **contex7**: verified latest stable versions and
  flags; updated links/notes.
- [ ] Security: non-root, PodSecurity, RBAC least-priv,
  secrets externalized, image signed.
- [ ] Reliability: probes, resources, HPA, PDBs, quotas,
  spread, multi-AZ as needed.
- [ ] Policy: Kyverno/OPA constraints satisfied; no
  `:latest` tags; pinned versions.
- [ ] Observability: OTel, metrics, logs, traces,
  dashboards, alerts defined.
- [ ] GitOps/IaC: declarative, PR-reviewed, environment
  overlays; no imperative prod changes.
- [ ] Data/ML: lineage, registry, drift, reproducibility;
  PII controls; backups and retention.
- [ ] Cost: right-sizing, autoscaling, spot (if safe),
  TTLs for ephemeral.

## Anti-Patterns

The following practices are explicitly prohibited:

- Imperative `kubectl` to prod; editing live objects
  without Git reconciliation.
- Embedding secrets in manifests or CI variables without
  a vault/KMS.
- Using `:latest` or mutable tags; skipping SBOM/signing;
  ignoring CVEs.
- Over-permissive RBAC, wide egress, or open Ingress
  without auth/TLS.
- Single-namespace multi-tenant prod; no quotas; no PDBs;
  no probes.
- Untracked datasets in non-prod; cloning prod PII
  without masking.
- Shipping models to prod without bias/security/drift
  checks or rollback plan.

## Outputs Style

- Prefer **YAML** for K8s manifests, **HCL** for
  Terraform, **Helm/Kustomize** patterns for packaging.
- Include comments explaining rationale and tradeoffs.
- Provide minimal, secure defaults; add options for
  advanced scenarios.

## Contex7 Usage Notes

### When Available

- Query latest versions for Kubernetes, CRDs (e.g.,
  External Secrets, Kyverno, Argo CD), Helm charts, and
  CLIs.
- Verify deprecations (APIs like `autoscaling/v2` vs
  `v2beta2`) and provider recommendations.
- Output a brief **Contex7 Check** section listing the
  versions/date verified.

### When Unavailable

- State: "Contex7 unavailable; using last-known stable
  versions."
- Prefer conservative defaults and flag items needing
  manual confirmation.

## Success Criteria

- Outputs are deployable, secure-by-default, observable,
  scalable, and cost-aware.
- Teams can reason about change risk and rollback within
  minutes.
- Compliance and audit artifacts are generated
  automatically where feasible.

## Governance

### Amendment Procedure

1. Any team member MAY propose an amendment via PR to this
   constitution file.
2. Amendments MUST be reviewed by at least one member of
   the Platform Engineering & MLOps Guild.
3. MAJOR changes (principle removals or redefinitions)
   require guild-wide consensus.
4. MINOR changes (new principles, expanded guidance) require
   one approving review.
5. PATCH changes (typos, clarifications) may be merged with
   standard PR approval.

### Versioning Policy

- This constitution follows **Semantic Versioning**:
  - **MAJOR**: Backward-incompatible governance/principle
    removals or redefinitions.
  - **MINOR**: New principle/section added or materially
    expanded guidance.
  - **PATCH**: Clarifications, wording, typo fixes,
    non-semantic refinements.

### Compliance Review

- All PRs and reviews MUST verify compliance with this
  constitution.
- Complexity MUST be justified (see plan-template.md
  Complexity Tracking section).
- The self-checklist MUST be completed for every output
  that produces infrastructure code or manifests.

### Governance & Compliance Mapping

- Map controls to SOC 2/ISO 27001/NIST/PCI/GDPR as
  applicable.
- Log administrative actions; preserve audit trails;
  require break-glass procedures with approvals.
- Data residency MUST be declared for each dataset;
  cross-border transfers documented with DPA/SCC where
  required.

**Version**: 1.0.0 | **Ratified**: 2026-02-06 | **Last Amended**: 2026-02-06
