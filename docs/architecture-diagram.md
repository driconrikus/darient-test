# SaaS Architecture Diagram

## High-Level Architecture

```mermaid
graph TB
    subgraph "Internet"
        Users[Enterprise Users]
        Admin[Platform Admins]
    end
    
    subgraph "AWS Cloud - us-east-1"
        subgraph "VPC - 10.0.0.0/16"
            subgraph "Public Subnet - 10.0.1.0/24"
                ALB[Application Load Balancer]
                NLB[Network Load Balancer]
                NAT[NAT Gateway]
            end
            
            subgraph "Private Subnet AZ-A - 10.0.2.0/24"
                subgraph "EKS Cluster"
                    subgraph "CPU Node Group"
                        CPU1[CPU Node 1]
                        CPU2[CPU Node 2]
                        CPU3[CPU Node 3]
                    end
                    
                    subgraph "GPU Node Group"
                        GPU1[GPU Node 1]
                        GPU2[GPU Node 2]
                        GPU3[GPU Node 3]
                    end
                    
                    subgraph "Control Plane"
                        API[Kubernetes API]
                        Scheduler[Kubernetes Scheduler]
                    end
                end
            end
            
            subgraph "Private Subnet AZ-B - 10.0.3.0/24"
                subgraph "EKS Cluster AZ-B"
                    CPUB1[CPU Node AZ-B]
                    CPUB2[CPU Node AZ-B]
                    GPUB1[GPU Node AZ-B]
                end
            end
            
            subgraph "Private Subnet AZ-C - 10.0.4.0/24"
                subgraph "EKS Cluster AZ-C"
                    CPUC1[CPU Node AZ-C]
                    CPUC2[CPU Node AZ-C]
                    GPUC1[GPU Node AZ-C]
                end
            end
            
            subgraph "Database Subnet Group"
                RDS[(RDS PostgreSQL<br/>Multi-AZ)]
                RDSRead[(Read Replica)]
            end
            
            subgraph "Storage"
                EFS[(Amazon EFS<br/>Model Storage)]
                S3[(Amazon S3<br/>Backup & Models)]
            end
            
            subgraph "Caching"
                Redis[(ElastiCache Redis<br/>Session Cache)]
            end
            
            subgraph "Monitoring"
                Prometheus[Prometheus]
                Grafana[Grafana]
                CloudWatch[CloudWatch]
            end
        end
        
        subgraph "AWS Services"
            Secrets[Secrets Manager]
            IAM[IAM Roles]
            KMS[KMS Encryption]
        end
    end
    
    subgraph "AWS Cloud - us-west-2 (DR)"
        subgraph "DR VPC"
            RDSDR[(RDS Read Replica)]
            S3DR[(S3 Cross-Region)]
            EFSDR[(EFS Replication)]
        end
    end
    
    %% Connections
    Users --> ALB
    Admin --> ALB
    ALB --> CPU1
    ALB --> CPU2
    ALB --> CPU3
    ALB --> GPU1
    ALB --> GPU2
    ALB --> GPU3
    
    CPU1 --> RDS
    CPU2 --> RDS
    CPU3 --> RDS
    GPU1 --> RDS
    GPU2 --> RDS
    GPU3 --> RDS
    
    CPU1 --> EFS
    CPU2 --> EFS
    CPU3 --> EFS
    GPU1 --> EFS
    GPU2 --> EFS
    GPU3 --> EFS
    
    CPU1 --> Redis
    CPU2 --> Redis
    CPU3 --> Redis
    GPU1 --> Redis
    GPU2 --> Redis
    GPU3 --> Redis
    
    Prometheus --> CPU1
    Prometheus --> CPU2
    Prometheus --> CPU3
    Prometheus --> GPU1
    Prometheus --> GPU2
    Prometheus --> GPU3
    
    RDS --> RDSRead
    RDS --> RDSDR
    S3 --> S3DR
    EFS --> EFSDR
    
    %% Styling
    classDef aws fill:#ff9900,stroke:#232f3e,stroke-width:2px,color:#fff
    classDef k8s fill:#326ce5,stroke:#fff,stroke-width:2px,color:#fff
    classDef database fill:#336791,stroke:#fff,stroke-width:2px,color:#fff
    classDef storage fill:#ff6b35,stroke:#fff,stroke-width:2px,color:#fff
    classDef monitoring fill:#ff6b6b,stroke:#fff,stroke-width:2px,color:#fff
    
    class ALB,NLB,NAT,RDS,RDSRead,RDSDR,S3,S3DR,EFS,EFSDR,Redis,Secrets,IAM,KMS,CloudWatch aws
    class CPU1,CPU2,CPU3,GPU1,GPU2,GPU3,API,Scheduler,CPUB1,CPUB2,GPUB1,CPUC1,CPUC2,GPUC1 k8s
    class Prometheus,Grafana monitoring
```

## Application Architecture Detail

```mermaid
graph TB
    subgraph "Tenant A Namespace"
        subgraph "OpenWebUI Pods"
            OWA1[OpenWebUI Pod 1]
            OWA2[OpenWebUI Pod 2]
        end
        subgraph "Ollama Standard Pods"
            OLA1[Ollama Llama3-8B]
            OLA2[Ollama Mistral-7B]
        end
        subgraph "Ollama Premium Pods"
            OLAP1[Ollama Llama3-70B GPU]
        end
    end
    
    subgraph "Tenant B Namespace"
        subgraph "OpenWebUI Pods"
            OWB1[OpenWebUI Pod 1]
            OWB2[OpenWebUI Pod 2]
        end
        subgraph "Ollama Standard Pods"
            OLB1[Ollama Llama3-8B]
            OLB2[Ollama Mistral-7B]
        end
        subgraph "Ollama Premium Pods"
            OLBP1[Ollama Llama3-70B GPU]
        end
    end
    
    subgraph "Shared Services"
        subgraph "Database Layer"
            PG[(PostgreSQL<br/>Multi-AZ)]
            PGR[(Read Replicas)]
        end
        subgraph "Model Storage"
            EFS[(EFS Shared<br/>Model Storage)]
            S3[(S3 Model<br/>Repository)]
        end
        subgraph "Caching Layer"
            Redis[(Redis Cache<br/>Sessions & Responses)]
        end
        subgraph "Security"
            SM[Secrets Manager]
            IAM[IAM Roles]
        end
    end
    
    %% Tenant A Connections
    OWA1 --> OLA1
    OWA1 --> OLA2
    OWA1 --> OLAP1
    OWA2 --> OLA1
    OWA2 --> OLA2
    OWA2 --> OLAP1
    
    OLA1 --> PG
    OLA2 --> PG
    OLAP1 --> PG
    
    OLA1 --> EFS
    OLA2 --> EFS
    OLAP1 --> EFS
    
    OWA1 --> Redis
    OWA2 --> Redis
    
    %% Tenant B Connections
    OWB1 --> OLB1
    OWB1 --> OLB2
    OWB1 --> OLBP1
    OWB2 --> OLB1
    OWB2 --> OLB2
    OWB2 --> OLBP1
    
    OLB1 --> PG
    OLB2 --> PG
    OLBP1 --> PG
    
    OLB1 --> EFS
    OLB2 --> EFS
    OLBP1 --> EFS
    
    OWB1 --> Redis
    OWB2 --> Redis
    
    %% Shared Connections
    PG --> PGR
    EFS --> S3
    
    %% Styling
    classDef tenantA fill:#e1f5fe,stroke:#0277bd,stroke-width:2px
    classDef tenantB fill:#f3e5f5,stroke:#7b1fa2,stroke-width:2px
    classDef shared fill:#fff3e0,stroke:#ef6c00,stroke-width:2px
    classDef database fill:#e8f5e8,stroke:#2e7d32,stroke-width:2px
    
    class OWA1,OWA2,OLA1,OLA2,OLAP1 tenantA
    class OWB1,OWB2,OLB1,OLB2,OLBP1 tenantB
    class EFS,S3,Redis,SM,IAM shared
    class PG,PGR database
```

## Network Architecture

```mermaid
graph TB
    subgraph "Internet Gateway"
        IGW[Internet Gateway]
    end
    
    subgraph "VPC - 10.0.0.0/16"
        subgraph "Public Subnets"
            PubA[Public Subnet A<br/>10.0.1.0/24]
            PubB[Public Subnet B<br/>10.0.2.0/24]
            PubC[Public Subnet C<br/>10.0.3.0/24]
        end
        
        subgraph "Private Subnets"
            PrivA[Private Subnet A<br/>10.0.11.0/24]
            PrivB[Private Subnet B<br/>10.0.12.0/24]
            PrivC[Private Subnet C<br/>10.0.13.0/24]
        end
        
        subgraph "Database Subnets"
            DBA[Database Subnet A<br/>10.0.21.0/24]
            DBB[Database Subnet B<br/>10.0.22.0/24]
            DBC[Database Subnet C<br/>10.0.23.0/24]
        end
        
        subgraph "Load Balancers"
            ALB[Application Load Balancer]
            NLB[Network Load Balancer]
        end
        
        subgraph "NAT Gateways"
            NAT1[NAT Gateway A]
            NAT2[NAT Gateway B]
            NAT3[NAT Gateway C]
        end
        
        subgraph "EKS Nodes"
            EKS1[EKS Node A]
            EKS2[EKS Node B]
            EKS3[EKS Node C]
        end
        
        subgraph "Database"
            RDS[RDS PostgreSQL]
        end
        
        subgraph "Security Groups"
            SG1[ALB Security Group<br/>80,443 from Internet]
            SG2[EKS Security Group<br/>Internal Communication]
            SG3[Database Security Group<br/>5432 from EKS]
            SG4[NAT Security Group<br/>Outbound Internet]
        end
    end
    
    %% Connections
    IGW --> PubA
    IGW --> PubB
    IGW --> PubC
    
    ALB --> EKS1
    ALB --> EKS2
    ALB --> EKS3
    
    EKS1 --> NAT1
    EKS2 --> NAT2
    EKS3 --> NAT3
    
    NAT1 --> IGW
    NAT2 --> IGW
    NAT3 --> IGW
    
    EKS1 --> RDS
    EKS2 --> RDS
    EKS3 --> RDS
    
    %% Security Group Associations
    SG1 -.-> ALB
    SG2 -.-> EKS1
    SG2 -.-> EKS2
    SG2 -.-> EKS3
    SG3 -.-> RDS
    SG4 -.-> NAT1
    SG4 -.-> NAT2
    SG4 -.-> NAT3
    
    %% Styling
    classDef public fill:#ffebee,stroke:#c62828,stroke-width:2px
    classDef private fill:#e8f5e8,stroke:#2e7d32,stroke-width:2px
    classDef database fill:#e3f2fd,stroke:#1565c0,stroke-width:2px
    classDef security fill:#fff3e0,stroke:#ef6c00,stroke-width:2px
    
    class PubA,PubB,PubC,IGW,ALB,NLB,NAT1,NAT2,NAT3 public
    class PrivA,PrivB,PrivC,EKS1,EKS2,EKS3 private
    class DBA,DBB,DBC,RDS database
    class SG1,SG2,SG3,SG4 security
```

## Auto-Scaling Architecture

```mermaid
graph TB
    subgraph "Auto Scaling Components"
        subgraph "Cluster Autoscaler"
            CA[Cluster Autoscaler]
        end
        
        subgraph "Horizontal Pod Autoscaler"
            HPA1[HPA - OpenWebUI]
            HPA2[HPA - Ollama Standard]
            HPA3[HPA - Ollama Premium]
        end
        
        subgraph "Vertical Pod Autoscaler"
            VPA1[VPA - OpenWebUI]
            VPA2[VPA - Ollama Standard]
            VPA3[VPA - Ollama Premium]
        end
        
        subgraph "Custom Metrics"
            CM[Custom Metrics<br/>Ollama Requests/Min]
            PM[Prometheus Metrics]
        end
        
        subgraph "Node Groups"
            subgraph "CPU Node Group"
                CPUNodes[CPU Nodes<br/>c5.2xlarge - c5.9xlarge<br/>Min: 3, Max: 50]
            end
            
            subgraph "GPU Node Group"
                GPUNodes[GPU Nodes<br/>g4dn.xlarge - p3.2xlarge<br/>Min: 0, Max: 20<br/>70% Spot, 30% On-Demand]
            end
        end
        
        subgraph "Scaling Triggers"
            CPU[CPU Utilization > 70%]
            Memory[Memory Utilization > 80%]
            Requests[Requests/Min > 1000]
            Queue[Queue Depth > 50]
        end
        
        subgraph "Scaling Actions"
            ScaleUp[Scale Up Pods]
            ScaleDown[Scale Down Pods]
            AddNodes[Add Nodes]
            RemoveNodes[Remove Nodes]
        end
    end
    
    %% Connections
    CPU --> HPA1
    CPU --> HPA2
    CPU --> HPA3
    
    Memory --> HPA1
    Memory --> HPA2
    Memory --> HPA3
    
    Requests --> HPA2
    Requests --> HPA3
    
    Queue --> HPA1
    
    HPA1 --> ScaleUp
    HPA2 --> ScaleUp
    HPA3 --> ScaleUp
    
    HPA1 --> ScaleDown
    HPA2 --> ScaleDown
    HPA3 --> ScaleDown
    
    ScaleUp --> CA
    ScaleDown --> CA
    
    CA --> AddNodes
    CA --> RemoveNodes
    
    AddNodes --> CPUNodes
    AddNodes --> GPUNodes
    RemoveNodes --> CPUNodes
    RemoveNodes --> GPUNodes
    
    CM --> HPA2
    CM --> HPA3
    PM --> HPA1
    PM --> HPA2
    PM --> HPA3
    
    %% Styling
    classDef scaling fill:#e8f5e8,stroke:#2e7d32,stroke-width:2px
    classDef metrics fill:#fff3e0,stroke:#ef6c00,stroke-width:2px
    classDef nodes fill:#e3f2fd,stroke:#1565c0,stroke-width:2px
    classDef triggers fill:#ffebee,stroke:#c62828,stroke-width:2px
    classDef actions fill:#f3e5f5,stroke:#7b1fa2,stroke-width:2px
    
    class CA,HPA1,HPA2,HPA3,VPA1,VPA2,VPA3 scaling
    class CM,PM metrics
    class CPUNodes,GPUNodes nodes
    class CPU,Memory,Requests,Queue triggers
    class ScaleUp,ScaleDown,AddNodes,RemoveNodes actions
```

## Monitoring and Observability

```mermaid
graph TB
    subgraph "Data Collection"
        subgraph "Application Metrics"
            AppMetrics[OpenWebUI Metrics<br/>- Request latency<br/>- Error rates<br/>- User sessions]
            OllamaMetrics[Ollama Metrics<br/>- Model loading time<br/>- Inference latency<br/>- GPU utilization<br/>- Memory usage]
        end
        
        subgraph "Infrastructure Metrics"
            K8sMetrics[Kubernetes Metrics<br/>- Pod status<br/>- Node resources<br/>- Network traffic]
            AWSMetrics[AWS Metrics<br/>- EC2 instances<br/>- RDS performance<br/>- EFS usage<br/>- ElastiCache stats]
        end
        
        subgraph "Business Metrics"
            TenantMetrics[Tenant Usage<br/>- Active users<br/>- API calls<br/>- Model requests<br/>- Resource consumption]
        end
    end
    
    subgraph "Data Processing"
        Prometheus[Prometheus<br/>Metrics Collection]
        Fluentd[Fluentd<br/>Log Aggregation]
        Jaeger[Jaeger<br/>Distributed Tracing]
    end
    
    subgraph "Storage"
        TSDB[Prometheus TSDB]
        Elasticsearch[Elasticsearch<br/>Log Storage]
        S3[S3<br/>Long-term Storage]
    end
    
    subgraph "Visualization"
        Grafana[Grafana<br/>Dashboards]
        Kibana[Kibana<br/>Log Analysis]
        JaegerUI[Jaeger UI<br/>Trace Analysis]
    end
    
    subgraph "Alerting"
        AlertManager[Alert Manager]
        PagerDuty[PagerDuty]
        Slack[Slack Notifications]
        Email[Email Alerts]
    end
    
    subgraph "CloudWatch"
        CloudWatch[CloudWatch<br/>AWS Native Monitoring]
        XRay[X-Ray<br/>AWS Distributed Tracing]
    end
    
    %% Data Flow
    AppMetrics --> Prometheus
    OllamaMetrics --> Prometheus
    K8sMetrics --> Prometheus
    AWSMetrics --> CloudWatch
    TenantMetrics --> Prometheus
    
    Prometheus --> TSDB
    Fluentd --> Elasticsearch
    Jaeger --> S3
    
    TSDB --> Grafana
    Elasticsearch --> Kibana
    S3 --> JaegerUI
    CloudWatch --> Grafana
    XRay --> JaegerUI
    
    Prometheus --> AlertManager
    CloudWatch --> AlertManager
    
    AlertManager --> PagerDuty
    AlertManager --> Slack
    AlertManager --> Email
    
    %% Styling
    classDef collection fill:#e8f5e8,stroke:#2e7d32,stroke-width:2px
    classDef processing fill:#e3f2fd,stroke:#1565c0,stroke-width:2px
    classDef storage fill:#fff3e0,stroke:#ef6c00,stroke-width:2px
    classDef visualization fill:#f3e5f5,stroke:#7b1fa2,stroke-width:2px
    classDef alerting fill:#ffebee,stroke:#c62828,stroke-width:2px
    classDef aws fill:#ff9900,stroke:#232f3e,stroke-width:2px,color:#fff
    
    class AppMetrics,OllamaMetrics,K8sMetrics,AWSMetrics,TenantMetrics collection
    class Prometheus,Fluentd,Jaeger processing
    class TSDB,Elasticsearch,S3 storage
    class Grafana,Kibana,JaegerUI visualization
    class AlertManager,PagerDuty,Slack,Email alerting
    class CloudWatch,XRay aws
```

## Security Architecture

```mermaid
graph TB
    subgraph "External Access"
        Users[Enterprise Users]
        Admins[Platform Administrators]
        DevOps[DevOps Team]
    end
    
    subgraph "Identity and Access Management"
        IAM[IAM Roles & Policies]
        RBAC[Kubernetes RBAC]
        SAML[SAML Integration]
        MFA[Multi-Factor Authentication]
    end
    
    subgraph "Network Security"
        WAF[Web Application Firewall]
        ALB[Application Load Balancer<br/>SSL Termination]
        VPC[VPC with Private Subnets]
        NACL[Network ACLs]
        SG[Security Groups]
        NP[Network Policies]
    end
    
    subgraph "Application Security"
        Secrets[Secrets Manager]
        KMS[KMS Encryption]
        PodSec[Pod Security Standards]
        ImageScan[Container Image Scanning]
    end
    
    subgraph "Data Protection"
        Encryption[Data Encryption<br/>At Rest & In Transit]
        Backup[Automated Backups]
        DLP[Data Loss Prevention]
        Audit[Audit Logging]
    end
    
    subgraph "Compliance"
        SOC[SOC 2 Type II]
        GDPR[GDPR Compliance]
        HIPAA[HIPAA Ready]
        ISO[ISO 27001]
    end
    
    subgraph "Monitoring & Response"
        SIEM[SIEM Integration]
        Threat[Threat Detection]
        Incident[Incident Response]
        Forensics[Forensic Analysis]
    end
    
    %% Access Flow
    Users --> WAF
    Admins --> WAF
    DevOps --> WAF
    
    WAF --> ALB
    ALB --> VPC
    
    %% Identity Flow
    Users --> IAM
    Admins --> IAM
    DevOps --> IAM
    
    IAM --> RBAC
    IAM --> SAML
    IAM --> MFA
    
    %% Security Controls
    VPC --> NACL
    VPC --> SG
    VPC --> NP
    
    RBAC --> Secrets
    RBAC --> KMS
    RBAC --> PodSec
    RBAC --> ImageScan
    
    %% Data Protection
    Secrets --> Encryption
    KMS --> Encryption
    Encryption --> Backup
    Encryption --> DLP
    Encryption --> Audit
    
    %% Compliance
    Audit --> SOC
    Audit --> GDPR
    Audit --> HIPAA
    Audit --> ISO
    
    %% Monitoring
    Audit --> SIEM
    SIEM --> Threat
    Threat --> Incident
    Incident --> Forensics
    
    %% Styling
    classDef access fill:#e8f5e8,stroke:#2e7d32,stroke-width:2px
    classDef identity fill:#e3f2fd,stroke:#1565c0,stroke-width:2px
    classDef network fill:#fff3e0,stroke:#ef6c00,stroke-width:2px
    classDef application fill:#f3e5f5,stroke:#7b1fa2,stroke-width:2px
    classDef data fill:#ffebee,stroke:#c62828,stroke-width:2px
    classDef compliance fill:#e0f2f1,stroke:#00695c,stroke-width:2px
    classDef monitoring fill:#fce4ec,stroke:#ad1457,stroke-width:2px
    
    class Users,Admins,DevOps access
    class IAM,RBAC,SAML,MFA identity
    class WAF,ALB,VPC,NACL,SG,NP network
    class Secrets,KMS,PodSec,ImageScan application
    class Encryption,Backup,DLP,Audit data
    class SOC,GDPR,HIPAA,ISO compliance
    class SIEM,Threat,Incident,Forensics monitoring
```
