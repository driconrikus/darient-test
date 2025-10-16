# Complete Testing Guide for OpenWebUI + Ollama Deployment

## 🧪 Testing Overview

This guide provides comprehensive testing strategies for both pre-deployment validation and post-deployment verification of the OpenWebUI + Ollama platform.

## 📋 Testing Phases

### Phase 1: Pre-Deployment Testing ✅

**Purpose**: Validate all configuration files and server readiness before deployment.

**Tests Included**:
- ✅ Required files existence
- ✅ SSH key permissions (600)
- ✅ Ansible playbook syntax
- ✅ Kubernetes manifests YAML syntax
- ✅ GitHub Actions workflow syntax
- ✅ Server connectivity and resources

**Run Command**:
```bash
./scripts/test-everything.sh
```

**Expected Results**: All pre-deployment tests should pass before proceeding.

### Phase 2: Deployment Testing

**Purpose**: Verify the deployment process and infrastructure setup.

**Manual Steps**:
1. **Deploy the application**:
   ```bash
   ./scripts/deploy.sh
   ```

2. **Monitor deployment progress**:
   ```bash
   # In another terminal, watch the deployment
   ssh -i ansible/ssh_key root@157.180.80.91 "kubectl get pods -A -w"
   ```

3. **Check deployment status**:
   ```bash
   ./scripts/verify-deployment.sh
   ```

### Phase 3: Post-Deployment Testing

**Purpose**: Verify all services are running and accessible.

**Automated Tests**:
```bash
# Run comprehensive test suite
./scripts/test-everything.sh
```

**Manual Verification Steps**:

#### 3.1 Application Access Tests

**OpenWebUI Access**:
```bash
# Test HTTP redirect
curl -I http://devops-ricardovaldez.darienc.com
# Should redirect to HTTPS

# Test HTTPS access
curl -I https://devops-ricardovaldez.darienc.com
# Should return 200 OK

# Test login page
curl -s https://devops-ricardovaldez.darienc.com | grep -i "login\|sign"
```

**Monitoring Access**:
```bash
# Test Grafana access
curl -I https://devops-monitor-ricardovaldez.darienc.com/grafana

# Test Prometheus access
curl -I https://devops-monitor-ricardovaldez.darienc.com/prometheus
```

#### 3.2 SSL Certificate Tests

```bash
# Check SSL certificate validity
openssl s_client -connect devops-ricardovaldez.darienc.com:443 -servername devops-ricardovaldez.darienc.com < /dev/null 2>/dev/null | openssl x509 -noout -dates

# Check certificate chain
echo | openssl s_client -connect devops-ricardovaldez.darienc.com:443 -servername devops-ricardovaldez.darienc.com 2>/dev/null | openssl x509 -noout -issuer -subject
```

#### 3.3 Kubernetes Cluster Tests

```bash
# SSH to server and run cluster tests
ssh -i ansible/ssh_key root@157.180.80.91

# Check cluster status
kubectl get nodes
kubectl get pods -A
kubectl get services -A
kubectl get ingress -A
kubectl get certificates -A

# Check resource usage
kubectl top nodes
kubectl top pods -A

# Check logs for any errors
kubectl logs -n openwebui deployment/openwebui
kubectl logs -n ollama deployment/ollama
kubectl logs -n database deployment/postgres
```

### Phase 4: Functional Testing

#### 4.1 OpenWebUI Login Test

1. **Open browser** and navigate to: `https://devops-ricardovaldez.darienc.com`
2. **Login credentials**:
   - Username: `admin`
   - Password: `Darient123`
3. **Verify features**:
   - ✅ Login successful
   - ✅ Dashboard loads
   - ✅ Model selection available
   - ✅ Chat interface functional

#### 4.2 Ollama Model Test

1. **Access OpenWebUI** and login
2. **Select a model** (Llama3-8B should be available)
3. **Start a chat** and send a test message
4. **Verify response**:
   - ✅ Model loads successfully
   - ✅ Response generated within reasonable time (< 30 seconds)
   - ✅ Response is coherent and relevant

#### 4.3 Database Connectivity Test

```bash
# Test database connection from within cluster
ssh -i ansible/ssh_key root@157.180.80.91
kubectl exec -it -n database deployment/postgres -- psql -U openwebui -d openwebui -c "SELECT version();"

# Check if tables are created
kubectl exec -it -n database deployment/postgres -- psql -U openwebui -d openwebui -c "\dt"
```

#### 4.4 Monitoring Dashboard Test

1. **Access Grafana**: `https://devops-monitor-ricardovaldez.darienc.com/grafana`
2. **Login credentials**:
   - Username: `admin`
   - Password: `Darient123`
3. **Verify dashboards**:
   - ✅ Kubernetes cluster metrics
   - ✅ Application metrics
   - ✅ Ollama performance metrics
   - ✅ Database metrics

### Phase 5: Performance Testing

#### 5.1 Load Testing

```bash
# Simple load test with curl
for i in {1..10}; do
  echo "Request $i"
  time curl -s https://devops-ricardovaldez.darienc.com > /dev/null
done
```

#### 5.2 Model Inference Testing

```bash
# Test model loading time
ssh -i ansible/ssh_key root@157.180.80.91
kubectl logs -n ollama deployment/ollama | grep -i "model.*loaded\|ready"
```

#### 5.3 Resource Usage Monitoring

```bash
# Monitor resource usage during testing
ssh -i ansible/ssh_key root@157.180.80.91
watch -n 5 'kubectl top pods -A'
```

### Phase 6: Security Testing

#### 6.1 SSL/TLS Security

```bash
# Test SSL configuration
nmap --script ssl-enum-ciphers -p 443 devops-ricardovaldez.darienc.com

# Test for common vulnerabilities
nmap --script ssl-heartbleed -p 443 devops-ricardovaldez.darienc.com
```

#### 6.2 Security Headers

```bash
# Check security headers
curl -I https://devops-ricardovaldez.darienc.com | grep -E "(Strict-Transport-Security|X-Frame-Options|X-Content-Type-Options|X-XSS-Protection)"
```

#### 6.3 Network Security

```bash
# Check network policies
ssh -i ansible/ssh_key root@157.180.80.91
kubectl get networkpolicies -A
kubectl describe networkpolicy -A
```

### Phase 7: High Availability Testing

#### 7.1 Pod Restart Test

```bash
# Simulate pod failure
ssh -i ansible/ssh_key root@157.180.80.91
kubectl delete pod -n ollama -l app=ollama

# Verify pod restarts
kubectl get pods -n ollama -w
```

#### 7.2 Service Failover Test

```bash
# Check service endpoints
kubectl get endpoints -A
kubectl describe service ollama-service -n ollama
```

## 🔧 Troubleshooting Common Issues

### Issue 1: SSL Certificate Not Ready

**Symptoms**: HTTPS returns certificate errors

**Solution**:
```bash
# Check certificate status
kubectl get certificates -A
kubectl describe certificate openwebui-tls -n openwebui

# Wait for certificate provisioning (up to 10 minutes)
kubectl get pods -n cert-manager
```

### Issue 2: Ollama Model Not Loading

**Symptoms**: No models available in OpenWebUI

**Solution**:
```bash
# Check Ollama logs
kubectl logs -n ollama deployment/ollama

# Check if model download completed
kubectl exec -it -n ollama deployment/ollama -- ls -la /root/.ollama/models/
```

### Issue 3: Database Connection Issues

**Symptoms**: OpenWebUI can't connect to database

**Solution**:
```bash
# Check database pod status
kubectl get pods -n database

# Check database logs
kubectl logs -n database deployment/postgres

# Test database connectivity
kubectl exec -it -n database deployment/postgres -- pg_isready -U openwebui
```

### Issue 4: High Memory Usage

**Symptoms**: Pods being killed due to memory limits

**Solution**:
```bash
# Check resource usage
kubectl top pods -A

# Check resource limits
kubectl describe pod -n ollama -l app=ollama | grep -A 10 "Limits:"
```

## 📊 Test Results Template

### Pre-Deployment Test Results

| Test | Status | Notes |
|------|--------|-------|
| Required files exist | ✅ PASS | All files present |
| SSH key permissions | ✅ PASS | 600 permissions set |
| Ansible syntax | ✅ PASS | Playbook valid |
| YAML syntax | ✅ PASS | All manifests valid |
| Server connectivity | ✅ PASS | SSH working |
| Server resources | ✅ PASS | 4GB RAM, 3 vCPU |

### Post-Deployment Test Results

| Test | Status | Notes |
|------|--------|-------|
| OpenWebUI access | ⏳ PENDING | Run after deployment |
| Monitoring access | ⏳ PENDING | Run after deployment |
| SSL certificates | ⏳ PENDING | Run after deployment |
| Ollama functionality | ⏳ PENDING | Run after deployment |
| Database connectivity | ⏳ PENDING | Run after deployment |

## 🚀 Quick Testing Commands

### Run All Tests
```bash
# Pre-deployment testing
./scripts/test-everything.sh

# Deploy application
./scripts/deploy.sh

# Post-deployment verification
./scripts/verify-deployment.sh
```

### Manual Verification
```bash
# Check application access
curl -I https://devops-ricardovaldez.darienc.com
curl -I https://devops-monitor-ricardovaldez.darienc.com/grafana

# Check cluster status
ssh -i ansible/ssh_key root@157.180.80.91 "kubectl get pods -A"
```

### Performance Monitoring
```bash
# Monitor resources
ssh -i ansible/ssh_key root@157.180.80.91 "watch -n 5 'kubectl top pods -A'"

# Check logs
ssh -i ansible/ssh_key root@157.180.80.91 "kubectl logs -n ollama deployment/ollama --tail=50"
```

## 📝 Testing Checklist

### Before Deployment
- [ ] All configuration files validated
- [ ] SSH connectivity confirmed
- [ ] Server resources adequate
- [ ] Domain DNS configured

### During Deployment
- [ ] Ansible playbook executes successfully
- [ ] Kubernetes cluster initializes
- [ ] All pods start successfully
- [ ] Services are accessible
- [ ] SSL certificates provision

### After Deployment
- [ ] OpenWebUI accessible via HTTPS
- [ ] Login functionality works
- [ ] Ollama models available
- [ ] Chat functionality works
- [ ] Monitoring dashboards accessible
- [ ] Database connectivity confirmed
- [ ] Performance within acceptable limits

## 🎯 Success Criteria

### Minimum Requirements
- ✅ All services running and healthy
- ✅ HTTPS access working with valid certificates
- ✅ Admin login successful
- ✅ At least one model available for chat
- ✅ Basic chat functionality working
- ✅ Monitoring dashboards accessible

### Optimal Performance
- ✅ Response times < 5 seconds for UI
- ✅ Model inference < 30 seconds
- ✅ Memory usage < 80%
- ✅ CPU usage < 70%
- ✅ All pods running without restarts
- ✅ SSL security grade A or better

---

**Next Steps**: Run the pre-deployment tests, then proceed with deployment using the provided scripts. After deployment, run the comprehensive test suite to verify everything is working correctly.
