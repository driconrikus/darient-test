# SaaS Platform Implementation Guide

## Overview

This guide provides step-by-step instructions for implementing the OpenWebUI + Ollama SaaS platform on AWS. The implementation is divided into phases to ensure a systematic and manageable deployment process.

## Prerequisites

### AWS Account Setup
- AWS Account with appropriate permissions
- AWS CLI configured with administrative access
- kubectl and eksctl installed
- Terraform (for infrastructure as code)
- Helm 3.x for Kubernetes package management

### Required AWS Services
- EKS (Elastic Kubernetes Service)
- VPC and Networking
- RDS PostgreSQL
- EFS (Elastic File System)
- ElastiCache Redis
- Secrets Manager
- KMS (Key Management Service)
- CloudWatch
- S3

## Phase 1: Infrastructure Foundation

### 1.1 VPC and Networking Setup

```bash
# Create VPC with Terraform
terraform init
terraform plan -var-file="variables.tfvars"
terraform apply
```

**Key Components:**
- VPC: 10.0.0.0/16
- 3 Public Subnets: 10.0.1.0/24, 10.0.2.0/24, 10.0.3.0/24
- 3 Private Subnets: 10.0.11.0/24, 10.0.12.0/24, 10.0.13.0/24
- 3 Database Subnets: 10.0.21.0/24, 10.0.22.0/24, 10.0.23.0/24
- NAT Gateways for outbound internet access
- Internet Gateway for public access

### 1.2 EKS Cluster Creation

```bash
# Create EKS cluster
eksctl create cluster \
  --name openwebui-saas \
  --version 1.28 \
  --region us-east-1 \
  --nodegroup-name cpu-nodes \
  --node-type c5.2xlarge \
  --nodes 3 \
  --nodes-min 3 \
  --nodes-max 50 \
  --managed \
  --vpc-private-subnets=subnet-xxx,subnet-yyy,subnet-zzz

# Add GPU node group
eksctl create nodegroup \
  --cluster openwebui-saas \
  --name gpu-nodes \
  --node-type g4dn.xlarge \
  --nodes 0 \
  --nodes-min 0 \
  --nodes-max 20 \
  --managed \
  --spot
```

### 1.3 Database Setup

```bash
# Create RDS PostgreSQL Multi-AZ
aws rds create-db-instance \
  --db-instance-identifier openwebui-postgres \
  --db-instance-class db.r5.xlarge \
  --engine postgres \
  --engine-version 15.4 \
  --master-username openwebui \
  --master-user-password $(openssl rand -base64 32) \
  --allocated-storage 100 \
  --storage-type gp2 \
  --multi-az \
  --backup-retention-period 7 \
  --vpc-security-group-ids sg-xxx
```

## Phase 2: Storage and Caching

### 2.1 EFS Setup for Model Storage

```bash
# Create EFS file system
aws efs create-file-system \
  --creation-token openwebui-models-$(date +%s) \
  --performance-mode generalPurpose \
  --throughput-mode provisioned \
  --provisioned-throughput-in-mibps 100

# Create mount targets in each AZ
aws efs create-mount-target \
  --file-system-id fs-xxx \
  --subnet-id subnet-xxx \
  --security-groups sg-xxx
```

### 2.2 ElastiCache Redis Setup

```bash
# Create Redis cluster
aws elasticache create-cache-cluster \
  --cache-cluster-id openwebui-redis \
  --cache-node-type cache.r5.large \
  --engine redis \
  --num-cache-nodes 1 \
  --vpc-security-group-ids sg-xxx \
  --subnet-group-name openwebui-subnet-group
```

## Phase 3: Kubernetes Application Deployment

### 3.1 Namespace and RBAC Setup

```yaml
# namespaces.yaml
apiVersion: v1
kind: Namespace
metadata:
  name: tenant-client-a
  labels:
    tenant: client-a
    tier: standard
---
apiVersion: v1
kind: Namespace
metadata:
  name: tenant-client-b
  labels:
    tenant: client-b
    tier: premium
---
apiVersion: v1
kind: Namespace
metadata:
  name: shared-services
  labels:
    type: shared
```

### 3.2 Network Policies

```yaml
# network-policies.yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: tenant-isolation
  namespace: tenant-client-a
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  - Egress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          name: ingress-nginx
  egress:
  - to:
    - namespaceSelector:
        matchLabels:
          name: database
  - to:
    - namespaceSelector:
        matchLabels:
          name: shared-services
```

### 3.3 Resource Quotas

```yaml
# resource-quotas.yaml
apiVersion: v1
kind: ResourceQuota
metadata:
  name: tenant-quota
  namespace: tenant-client-a
spec:
  hard:
    requests.cpu: "4"
    requests.memory: 8Gi
    limits.cpu: "8"
    limits.memory: 16Gi
    persistentvolumeclaims: "4"
    pods: "20"
    services: "10"
```

## Phase 4: Application Components

### 4.1 OpenWebUI Deployment

```yaml
# openwebui-deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: openwebui
  namespace: tenant-client-a
spec:
  replicas: 2
  selector:
    matchLabels:
      app: openwebui
  template:
    metadata:
      labels:
        app: openwebui
      annotations:
        prometheus.io/scrape: "true"
        prometheus.io/port: "8080"
        prometheus.io/path: "/metrics"
    spec:
      containers:
      - name: openwebui
        image: ghcr.io/open-webui/open-webui:main
        ports:
        - containerPort: 8080
        env:
        - name: WEBUI_SECRET_KEY
          valueFrom:
            secretKeyRef:
              name: openwebui-secrets
              key: secret-key
        - name: OLLAMA_BASE_URL
          value: "http://ollama-service.tenant-client-a.svc.cluster.local:11434"
        - name: DATABASE_URL
          value: "postgresql://openwebui:$(POSTGRES_PASSWORD)@rds-endpoint:5432/openwebui"
        - name: POSTGRES_PASSWORD
          valueFrom:
            secretKeyRef:
              name: database-secrets
              key: password
        - name: WEBUI_AUTH
          value: "True"
        - name: WEBUI_NAME
          value: "Client A AI Assistant"
        - name: TENANT_ID
          value: "client-a"
        resources:
          requests:
            memory: "512Mi"
            cpu: "200m"
          limits:
            memory: "1Gi"
            cpu: "1000m"
        livenessProbe:
          httpGet:
            path: /
            port: 8080
          initialDelaySeconds: 30
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /
            port: 8080
          initialDelaySeconds: 10
          periodSeconds: 5
```

### 4.2 Ollama Deployment with GPU Support

```yaml
# ollama-gpu-deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ollama-gpu
  namespace: tenant-client-b
spec:
  replicas: 1
  selector:
    matchLabels:
      app: ollama-gpu
  template:
    metadata:
      labels:
        app: ollama-gpu
      annotations:
        prometheus.io/scrape: "true"
        prometheus.io/port: "11434"
        prometheus.io/path: "/metrics"
    spec:
      nodeSelector:
        accelerator: nvidia-tesla-t4
      tolerations:
      - key: nvidia.com/gpu
        operator: Exists
        effect: NoSchedule
      containers:
      - name: ollama
        image: ollama/ollama:latest
        ports:
        - containerPort: 11434
        env:
        - name: OLLAMA_HOST
          value: "0.0.0.0"
        - name: OLLAMA_ORIGINS
          value: "*"
        - name: OLLAMA_GPU_LAYERS
          value: "-1"
        resources:
          requests:
            memory: "8Gi"
            cpu: "2"
            nvidia.com/gpu: 1
          limits:
            memory: "16Gi"
            cpu: "4"
            nvidia.com/gpu: 1
        volumeMounts:
        - name: ollama-models
          mountPath: /root/.ollama
        - name: shared-models
          mountPath: /models
        livenessProbe:
          httpGet:
            path: /
            port: 11434
          initialDelaySeconds: 60
          periodSeconds: 30
        readinessProbe:
          httpGet:
            path: /
            port: 11434
          initialDelaySeconds: 30
          periodSeconds: 10
      volumes:
      - name: ollama-models
        emptyDir:
          sizeLimit: 50Gi
      - name: shared-models
        persistentVolumeClaim:
          claimName: efs-pvc
      initContainers:
      - name: download-model
        image: ollama/ollama:latest
        command: ["/bin/sh"]
        args:
          - -c
          - |
            # Check if model exists in shared storage
            if [ -f "/models/llama3-70b" ]; then
              echo "Model found in shared storage, copying..."
              cp -r /models/llama3-70b /root/.ollama/
            else
              echo "Downloading model..."
              ollama serve &
              sleep 10
              ollama pull llama3:70b
              pkill ollama
              # Copy to shared storage for other pods
              cp -r /root/.ollama/models /models/
            fi
        volumeMounts:
        - name: ollama-models
          mountPath: /root/.ollama
        - name: shared-models
          mountPath: /models
        resources:
          requests:
            memory: "8Gi"
            cpu: "2"
            nvidia.com/gpu: 1
          limits:
            memory: "16Gi"
            cpu: "4"
            nvidia.com/gpu: 1
```

## Phase 5: Auto-Scaling Configuration

### 5.1 Horizontal Pod Autoscaler

```yaml
# hpa-config.yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: openwebui-hpa
  namespace: tenant-client-a
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: openwebui
  minReplicas: 2
  maxReplicas: 10
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70
  - type: Resource
    resource:
      name: memory
      target:
        type: Utilization
        averageUtilization: 80
  - type: Pods
    pods:
      metric:
        name: ollama_requests_per_minute
      target:
        type: AverageValue
        averageValue: "100"
  behavior:
    scaleDown:
      stabilizationWindowSeconds: 300
      policies:
      - type: Percent
        value: 50
        periodSeconds: 60
    scaleUp:
      stabilizationWindowSeconds: 60
      policies:
      - type: Percent
        value: 100
        periodSeconds: 60
      - type: Pods
        value: 2
        periodSeconds: 60
      selectPolicy: Max
```

### 5.2 Cluster Autoscaler Configuration

```yaml
# cluster-autoscaler.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: cluster-autoscaler
  namespace: kube-system
spec:
  replicas: 1
  selector:
    matchLabels:
      app: cluster-autoscaler
  template:
    metadata:
      labels:
        app: cluster-autoscaler
    spec:
      serviceAccountName: cluster-autoscaler
      containers:
      - image: k8s.gcr.io/autoscaling/cluster-autoscaler:v1.28.0
        name: cluster-autoscaler
        resources:
          limits:
            cpu: 100m
            memory: 300Mi
          requests:
            cpu: 100m
            memory: 300Mi
        command:
        - ./cluster-autoscaler
        - --v=4
        - --stderrthreshold=info
        - --cloud-provider=aws
        - --skip-nodes-with-local-storage=false
        - --expander=least-waste
        - --node-group-auto-discovery=asg:tag=k8s.io/cluster-autoscaler/enabled,k8s.io/cluster-autoscaler/openwebui-saas
        - --balance-similar-node-groups
        - --scale-down-enabled=true
        - --scale-down-delay-after-add=10m
        - --scale-down-unneeded-time=10m
        env:
        - name: AWS_REGION
          value: us-east-1
```

## Phase 6: Monitoring and Observability

### 6.1 Prometheus Configuration

```yaml
# prometheus-config.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: prometheus-config
  namespace: monitoring
data:
  prometheus.yml: |
    global:
      scrape_interval: 15s
      evaluation_interval: 15s

    rule_files:
      - "alert_rules.yml"

    alerting:
      alertmanagers:
        - static_configs:
            - targets: ['alertmanager-service.monitoring.svc.cluster.local:9093']

    scrape_configs:
      - job_name: 'prometheus'
        static_configs:
          - targets: ['localhost:9090']

      - job_name: 'kubernetes-pods'
        kubernetes_sd_configs:
          - role: pod
        relabel_configs:
          - source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_scrape]
            action: keep
            regex: true
          - source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_path]
            action: replace
            target_label: __metrics_path__
            regex: (.+)

      - job_name: 'ollama-standard'
        kubernetes_sd_configs:
          - role: pod
            namespaces:
              names: ['tenant-client-a']
        relabel_configs:
          - source_labels: [__meta_kubernetes_pod_label_app]
            action: keep
            regex: ollama

      - job_name: 'ollama-gpu'
        kubernetes_sd_configs:
          - role: pod
            namespaces:
              names: ['tenant-client-b']
        relabel_configs:
          - source_labels: [__meta_kubernetes_pod_label_app]
            action: keep
            regex: ollama-gpu

  alert_rules.yml: |
    groups:
      - name: openwebui_alerts
        rules:
          - alert: HighErrorRate
            expr: rate(http_requests_total{status=~"5.."}[5m]) / rate(http_requests_total[5m]) > 0.05
            for: 5m
            labels:
              severity: warning
            annotations:
              summary: "High error rate detected"
              description: "Error rate is above 5% for more than 5 minutes"

          - alert: HighLatency
            expr: histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[5m])) > 30
            for: 5m
            labels:
              severity: warning
            annotations:
              summary: "High latency detected"
              description: "95th percentile latency is above 30 seconds"

      - name: ollama_alerts
        rules:
          - alert: OllamaDown
            expr: up{job=~"ollama.*"} == 0
            for: 1m
            labels:
              severity: critical
            annotations:
              summary: "Ollama service is down"
              description: "Ollama service has been down for more than 1 minute"

          - alert: HighMemoryUsage
            expr: (node_memory_MemTotal_bytes - node_memory_MemAvailable_bytes) / node_memory_MemTotal_bytes > 0.8
            for: 5m
            labels:
              severity: warning
            annotations:
              summary: "High memory usage detected"
              description: "Memory usage is above 80% for more than 5 minutes"

          - alert: GPULowUtilization
            expr: nvidia_smi_utilization_gpu_ratio < 0.1
            for: 10m
            labels:
              severity: info
            annotations:
              summary: "GPU low utilization"
              description: "GPU utilization is below 10% for more than 10 minutes"
```

### 6.2 Grafana Dashboards

```json
{
  "dashboard": {
    "title": "OpenWebUI SaaS Platform",
    "panels": [
      {
        "title": "Request Rate",
        "type": "graph",
        "targets": [
          {
            "expr": "rate(http_requests_total[5m])",
            "legendFormat": "{{namespace}} - {{job}}"
          }
        ]
      },
      {
        "title": "Response Time",
        "type": "graph",
        "targets": [
          {
            "expr": "histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[5m]))",
            "legendFormat": "95th percentile"
          }
        ]
      },
      {
        "title": "GPU Utilization",
        "type": "graph",
        "targets": [
          {
            "expr": "nvidia_smi_utilization_gpu_ratio * 100",
            "legendFormat": "GPU {{instance}}"
          }
        ]
      },
      {
        "title": "Model Loading Time",
        "type": "stat",
        "targets": [
          {
            "expr": "ollama_model_load_duration_seconds",
            "legendFormat": "Load Time"
          }
        ]
      }
    ]
  }
}
```

## Phase 7: Security Implementation

### 7.1 Pod Security Standards

```yaml
# pod-security-policy.yaml
apiVersion: policy/v1beta1
kind: PodSecurityPolicy
metadata:
  name: openwebui-psp
spec:
  privileged: false
  allowPrivilegeEscalation: false
  requiredDropCapabilities:
    - ALL
  volumes:
    - 'configMap'
    - 'emptyDir'
    - 'projected'
    - 'secret'
    - 'downwardAPI'
    - 'persistentVolumeClaim'
  runAsUser:
    rule: 'MustRunAsNonRoot'
  seLinux:
    rule: 'RunAsAny'
  fsGroup:
    rule: 'RunAsAny'
```

### 7.2 Network Policies

```yaml
# comprehensive-network-policies.yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: deny-all-ingress
  namespace: tenant-client-a
spec:
  podSelector: {}
  policyTypes:
  - Ingress
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-ingress-controller
  namespace: tenant-client-a
spec:
  podSelector:
    matchLabels:
      app: openwebui
  policyTypes:
  - Ingress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          name: ingress-nginx
    ports:
    - protocol: TCP
      port: 8080
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-ollama-communication
  namespace: tenant-client-a
spec:
  podSelector:
    matchLabels:
      app: openwebui
  policyTypes:
  - Egress
  egress:
  - to:
    - podSelector:
        matchLabels:
          app: ollama
    ports:
    - protocol: TCP
      port: 11434
  - to:
    - namespaceSelector:
        matchLabels:
          name: database
    ports:
    - protocol: TCP
      port: 5432
```

## Phase 8: Cost Optimization

### 8.1 Spot Instance Configuration

```yaml
# spot-instance-config.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: spot-instance-config
  namespace: kube-system
data:
  spot-instance-config.yaml: |
    spotInstanceTypes:
      - g4dn.xlarge
      - g4dn.2xlarge
      - p3.2xlarge
    onDemandInstanceTypes:
      - g4dn.xlarge
      - p3.2xlarge
    spotPercentage: 70
    onDemandPercentage: 30
    interruptionHandling:
      gracefulShutdownTimeout: 120s
      preemptionPolicy: "Terminate"
```

### 8.2 Cost Monitoring

```yaml
# cost-monitoring.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: cost-monitor
  namespace: monitoring
spec:
  replicas: 1
  selector:
    matchLabels:
      app: cost-monitor
  template:
    metadata:
      labels:
        app: cost-monitor
    spec:
      containers:
      - name: cost-monitor
        image: amazon/aws-cli:latest
        command: ["/bin/sh"]
        args:
          - -c
          - |
            while true; do
              # Get current costs
              aws ce get-cost-and-usage \
                --time-period Start=$(date -d '1 day ago' +%Y-%m-%d),End=$(date +%Y-%m-%d) \
                --granularity DAILY \
                --metrics BlendedCost \
                --group-by Type=DIMENSION,Key=SERVICE
              
              # Alert if cost exceeds threshold
              COST=$(aws ce get-cost-and-usage --time-period Start=$(date -d '1 day ago' +%Y-%m-%d),End=$(date +%Y-%m-%d) --granularity DAILY --metrics BlendedCost --query 'ResultsByTime[0].Total.BlendedCost.Amount' --output text)
              
              if (( $(echo "$COST > 1000" | bc -l) )); then
                echo "Daily cost exceeds $1000: $COST"
                # Send alert
              fi
              
              sleep 3600  # Check every hour
            done
        env:
        - name: AWS_REGION
          value: us-east-1
```

## Phase 9: Disaster Recovery

### 9.1 Cross-Region Replication

```yaml
# cross-region-backup.yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: cross-region-backup
  namespace: shared-services
spec:
  schedule: "0 2 * * *"  # Daily at 2 AM
  jobTemplate:
    spec:
      template:
        spec:
          containers:
          - name: backup
            image: amazon/aws-cli:latest
            command: ["/bin/sh"]
            args:
              - -c
              - |
                # Backup RDS
                aws rds create-db-snapshot \
                  --db-instance-identifier openwebui-postgres \
                  --db-snapshot-identifier openwebui-postgres-$(date +%Y%m%d)
                
                # Sync EFS to S3
                aws s3 sync /mnt/efs s3://openwebui-backups/efs/$(date +%Y/%m/%d)
                
                # Sync to DR region
                aws s3 sync s3://openwebui-backups s3://openwebui-backups-dr --delete
            volumeMounts:
            - name: efs-volume
              mountPath: /mnt/efs
          volumes:
          - name: efs-volume
            persistentVolumeClaim:
              claimName: efs-backup-pvc
          restartPolicy: OnFailure
```

## Phase 10: Performance Testing

### 10.1 Load Testing Configuration

```yaml
# load-test.yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: load-test
  namespace: testing
spec:
  template:
    spec:
      containers:
      - name: load-test
        image: grafana/k6:latest
        command: ["k6"]
        args:
          - run
          - /scripts/load-test.js
        volumeMounts:
        - name: load-test-script
          mountPath: /scripts
      volumes:
      - name: load-test-script
        configMap:
          name: load-test-script
      restartPolicy: Never
```

```javascript
// load-test.js
import http from 'k6/http';
import { check, sleep } from 'k6';

export let options = {
  stages: [
    { duration: '2m', target: 100 }, // Ramp up to 100 users
    { duration: '5m', target: 100 }, // Stay at 100 users
    { duration: '2m', target: 200 }, // Ramp up to 200 users
    { duration: '5m', target: 200 }, // Stay at 200 users
    { duration: '2m', target: 0 },   // Ramp down to 0 users
  ],
  thresholds: {
    http_req_duration: ['p(95)<5000'], // 95% of requests under 5s
    http_req_failed: ['rate<0.1'],     // Error rate under 10%
  },
};

export default function () {
  let response = http.get('https://devops-ricardovaldez.darienc.com');
  check(response, {
    'status is 200': (r) => r.status === 200,
    'response time < 5000ms': (r) => r.timings.duration < 5000,
  });
  sleep(1);
}
```

## Deployment Commands

### Complete Deployment Script

```bash
#!/bin/bash
set -e

echo "Starting SaaS platform deployment..."

# Phase 1: Infrastructure
echo "Phase 1: Setting up infrastructure..."
terraform apply -var-file="variables.tfvars"

# Phase 2: EKS Cluster
echo "Phase 2: Creating EKS cluster..."
eksctl create cluster --config-file=cluster-config.yaml

# Phase 3: Install add-ons
echo "Phase 3: Installing add-ons..."
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

helm install ingress-nginx ingress-nginx/ingress-nginx \
  --namespace ingress-nginx \
  --create-namespace

helm install prometheus prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --create-namespace

# Phase 4: Deploy applications
echo "Phase 4: Deploying applications..."
kubectl apply -f kubernetes/namespaces/
kubectl apply -f kubernetes/network-policies/
kubectl apply -f kubernetes/applications/

# Phase 5: Configure monitoring
echo "Phase 5: Configuring monitoring..."
kubectl apply -f kubernetes/monitoring/

# Phase 6: Security hardening
echo "Phase 6: Applying security policies..."
kubectl apply -f kubernetes/security/

echo "Deployment completed successfully!"
echo "Access URLs:"
echo "OpenWebUI: https://devops-ricardovaldez.darienc.com"
echo "Monitoring: https://devops-monitor-ricardovaldez.darienc.com"
```

## Monitoring and Maintenance

### Health Checks

```bash
# Check cluster health
kubectl get nodes
kubectl get pods -A
kubectl top nodes
kubectl top pods -A

# Check application health
curl -f https://devops-ricardovaldez.darienc.com/health
curl -f https://devops-monitor-ricardovaldez.darienc.com/grafana/api/health

# Check database connectivity
kubectl exec -it deployment/postgres -n database -- psql -U openwebui -d openwebui -c "SELECT 1;"
```

### Backup Verification

```bash
# Verify backups
aws rds describe-db-snapshots --db-instance-identifier openwebui-postgres
aws s3 ls s3://openwebui-backups/

# Test restore procedure
kubectl create job restore-test --from=cronjob/cross-region-backup
```

This implementation guide provides a comprehensive roadmap for deploying the OpenWebUI + Ollama SaaS platform with enterprise-grade features, security, and scalability.
