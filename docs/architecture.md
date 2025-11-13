# System Architecture - Mermaid Diagrams

These diagrams can be rendered directly in GitHub or any Markdown viewer that supports Mermaid.

## Platform Overview

```mermaid
graph TB
    subgraph "External Access"
        USER[Users/DevOps]
        KUBECTL[kubectl CLI]
        HELM[Helm Package Manager]
    end

    subgraph "K3d Cluster"
        subgraph "Control Plane"
            API[API Server]
            SCHED[Scheduler]
            CTRL[Controller Manager]
            ETCD[etcd]
        end

        subgraph "Platform Services"
            subgraph "spark-operator ns"
                SO[Spark Operator<br/>v2.3.0]
                WH[Webhook<br/>Port: 9443]
            end
            
            subgraph "volcano-system ns"
                VS[Volcano Scheduler<br/>v1.8.2]
                VC[Volcano Controller]
                VA[Volcano Admission]
            end
        end

        subgraph "Team Namespaces"
            subgraph "Default Scheduler"
                ALPHA[team-alpha<br/>PySpark<br/>4-8 CPU]
                BETA[team-beta<br/>Scala<br/>4-8 CPU]
            end
            
            subgraph "Volcano Scheduler"
                THETA[team-theta<br/>Scala<br/>6-8 CPU<br/>queue-theta]
                DELTA[team-delta<br/>PySpark<br/>6-8 CPU<br/>queue-delta]
            end
        end

        subgraph "Worker Nodes"
            W1[k3d-agent-0]
            W2[k3d-agent-1]
        end
    end

    USER --> KUBECTL
    USER --> HELM
    KUBECTL --> API
    HELM --> API
    API --> SO
    SO --> ALPHA
    SO --> BETA
    SO --> THETA
    SO --> DELTA
    VS --> THETA
    VS --> DELTA
    SCHED --> ALPHA
    SCHED --> BETA

    classDef operator fill:#e1f5fe
    classDef volcano fill:#fff3e0
    classDef team fill:#f3e5f5
    classDef worker fill:#e8f5e9
    
    class SO,WH operator
    class VS,VC,VA volcano
    class ALPHA,BETA,THETA,DELTA team
    class W1,W2 worker
```

## Spark Job Execution Flow

```mermaid
sequenceDiagram
    participant U as User
    participant K as Kubectl
    participant SO as Spark Operator
    participant S as Scheduler
    participant D as Driver Pod
    participant E as Executor Pods
    participant N as Worker Node

    U->>K: Submit SparkApplication YAML
    K->>SO: Create SparkApplication CR
    SO->>SO: Validate Specification
    SO->>S: Request Driver Pod Scheduling
    
    alt Default Scheduler (Alpha/Beta)
        S->>N: Schedule to Available Node
    else Volcano Scheduler (Theta/Delta)
        S->>S: Check Queue Capacity
        S->>S: Apply Queue Policy
        S->>N: Schedule with Queue Constraints
    end
    
    N->>D: Start Driver Pod
    D->>D: Initialize Spark Context
    D->>SO: Request Executors
    SO->>S: Schedule Executor Pods
    S->>N: Place Executor Pods
    N->>E: Start Executors
    E->>D: Register with Driver
    D->>E: Distribute Tasks
    E->>E: Process Data
    E->>D: Return Results
    D->>SO: Job Complete
    SO->>K: Update Status
    K->>U: Show Completion
```

## Resource Allocation Hierarchy

```mermaid
graph TD
    subgraph "Cluster Resources"
        TR[Total Resources<br/>8 CPU, 16Gi Memory]
    end

    subgraph "Scheduling Layer"
        DS[Default Scheduler<br/>Direct Resource Access]
        VS[Volcano Scheduler<br/>Queue-Based Allocation]
    end

    subgraph "Volcano Queues"
        QT[queue-theta<br/>40% weight<br/>8 CPU, 16Gi capacity]
        QD[queue-delta<br/>40% weight<br/>8 CPU, 16Gi capacity]
        QDF[default queue<br/>20% weight<br/>4 CPU, 8Gi capacity]
    end

    subgraph "Team Quotas"
        TA[team-alpha<br/>Req: 4 CPU<br/>Limit: 8 CPU]
        TB[team-beta<br/>Req: 4 CPU<br/>Limit: 8 CPU]
        TT[team-theta<br/>Req: 6 CPU<br/>Limit: 8 CPU]
        TD[team-delta<br/>Req: 6 CPU<br/>Limit: 8 CPU]
    end

    TR --> DS
    TR --> VS
    DS --> TA
    DS --> TB
    VS --> QT
    VS --> QD
    VS --> QDF
    QT --> TT
    QD --> TD

    classDef resource fill:#bbdefb
    classDef scheduler fill:#c8e6c9
    classDef queue fill:#ffe0b2
    classDef team fill:#f8bbd0
    
    class TR resource
    class DS,VS scheduler
    class QT,QD,QDF queue
    class TA,TB,TT,TD team
```

## Security & RBAC Model

```mermaid
graph TB
    subgraph "Cluster Level"
        CR[ClusterRole:<br/>spark-operator-controller]
        CRB[ClusterRoleBinding]
        SO_SA[spark-operator SA]
    end

    subgraph "Namespace Level"
        subgraph "team-alpha"
            RA[Role: spark-role]
            RBA[RoleBinding]
            SAA[ServiceAccount:<br/>team-alpha-sa]
            PA[Permissions:<br/>• Pods CRUD<br/>• SparkApps<br/>• ConfigMaps]
        end

        subgraph "team-theta"
            RT[Role: spark-volcano-role]
            RBT[RoleBinding]
            SAT[ServiceAccount:<br/>team-theta-sa]
            PT[Permissions:<br/>• Pods CRUD<br/>• SparkApps<br/>• PodGroups<br/>• Queues]
        end
    end

    CR --> CRB
    CRB --> SO_SA
    RA --> RBA
    RBA --> SAA
    SAA --> PA
    RT --> RBT
    RBT --> SAT
    SAT --> PT

    classDef cluster fill:#e3f2fd
    classDef namespace fill:#f3e5f5
    classDef permission fill:#e8f5e9
    
    class CR,CRB,SO_SA cluster
    class RA,RBA,SAA,RT,RBT,SAT namespace
    class PA,PT permission
```

## Network Architecture

```mermaid
graph LR
    subgraph "External"
        EXT[External Traffic]
    end

    subgraph "Host Ports"
        P1[8080:80]
        P2[8443:443]
        P3[6443:API]
    end

    subgraph "Cluster Services"
        subgraph "ClusterIP Services"
            SVC1[spark-operator-webhook<br/>9443]
            SVC2[volcano-scheduler]
            SVC3[volcano-admission]
        end

        subgraph "Pod Network"
            PN[Pod-to-Pod<br/>Communication]
            SS[Spark Shuffle<br/>Service]
            MS[Metrics<br/>Collection]
        end
    end

    EXT --> P1
    EXT --> P2
    EXT --> P3
    P1 --> SVC1
    P2 --> SVC1
    P3 --> SVC2
    SVC1 --> PN
    SVC2 --> PN
    SVC3 --> PN
    PN --> SS
    PN --> MS

    classDef external fill:#ffebee
    classDef port fill:#e8eaf6
    classDef service fill:#e0f2f1
    classDef network fill:#fff9c4
    
    class EXT external
    class P1,P2,P3 port
    class SVC1,SVC2,SVC3 service
    class PN,SS,MS network
```

## Component Dependencies

```mermaid
graph BT
    subgraph "Infrastructure"
        DOCKER[Docker]
        K3D[k3d]
        K8S[Kubernetes API]
    end

    subgraph "Platform Components"
        HELM[Helm]
        SO[Spark Operator]
        VOL[Volcano]
    end

    subgraph "Team Workloads"
        ALPHA[team-alpha Jobs]
        BETA[team-beta Jobs]
        THETA[team-theta Jobs]
        DELTA[team-delta Jobs]
    end

    K3D --> DOCKER
    K8S --> K3D
    HELM --> K8S
    SO --> HELM
    VOL --> HELM
    ALPHA --> SO
    BETA --> SO
    THETA --> SO
    THETA --> VOL
    DELTA --> SO
    DELTA --> VOL

    classDef infra fill:#e8eaf6
    classDef platform fill:#c5e1a5
    classDef workload fill:#ffccbc
    
    class DOCKER,K3D,K8S infra
    class HELM,SO,VOL platform
    class ALPHA,BETA,THETA,DELTA workload
```

## Data Flow (Future State)

```mermaid
graph LR
    subgraph "Data Sources"
        KAFKA[Kafka Streams]
        FILES[File Storage<br/>S3/GCS]
        API[REST APIs]
    end

    subgraph "Processing Layer"
        subgraph "Spark Jobs"
            ETL[ETL Pipelines]
            ML[ML Training]
            STREAM[Stream Processing]
            BATCH[Batch Analytics]
        end
    end

    subgraph "Storage Layer"
        MINIO[MinIO<br/>Object Storage]
        HDFS[HDFS<br/>Distributed FS]
        PG[PostgreSQL<br/>Metadata Store]
    end

    subgraph "Serving Layer"
        DASH[Dashboards]
        API_OUT[API Services]
        REPORTS[Reports]
    end

    KAFKA --> STREAM
    FILES --> ETL
    API --> BATCH
    ETL --> MINIO
    ML --> MINIO
    STREAM --> HDFS
    BATCH --> PG
    MINIO --> DASH
    HDFS --> API_OUT
    PG --> REPORTS

    classDef source fill:#e1bee7
    classDef process fill:#b3e5fc
    classDef storage fill:#c5e1a5
    classDef serve fill:#ffe0b2
    
    class KAFKA,FILES,API source
    class ETL,ML,STREAM,BATCH process
    class MINIO,HDFS,PG storage
    class DASH,API_OUT,REPORTS serve
```