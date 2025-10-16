# OpenWebUI + Ollama Deployment

This repository contains a production-ready deployment configuration for OpenWebUI + Ollama with local LLM models, featuring high availability, security, monitoring, and automated CI/CD pipeline.

## 🏗️ Architecture Overview

### Production Deployment Stack
- **Kubernetes**: k3s lightweight distribution (v1.28.2)
- **Ollama**: 2 replicas for high availability with Llama3-8B model (Currently, it is set to 1 due to the instance resource limitations)
- **OpenWebUI**: Web interface with admin authentication
- **PostgreSQL**: Persistent database for chat history and metadata
- **Monitoring**: Prometheus + Grafana observability stack
- **SSL/TLS**: Let's Encrypt certificates with automatic renewal
- **CI/CD**: GitHub Actions with secure SSH key management
- **Security**: SSH keys stored in GitHub Secrets, not in repository

## 🔐 Access Information

### Server Details
- **IP**: 157.180.80.91
- **User**: root
- **OS**: Ubuntu 24.04.3 LTS
- **Specs**: 4GB RAM, 3 vCPU, 75GB storage

### Application URLs
- **OpenWebUI**: https://devops-ricardovaldez.darienc.com
  - Username: `admin@localhost`
  - Password: `Darient123`
- **Monitoring Dashboard**: https://devops-monitor-ricardovaldez.darienc.com
  - Grafana: `/grafana` (admin/Darient123)
  - Prometheus: `/prometheus`

## 🚀 Quick Start

### Automated Deployment (Recommended)
1. **Set up GitHub Secrets**:
   - Go to repository Settings → Secrets and variables → Actions
   - Add secret: `SSH_PRIVATE_KEY` (base64-encoded SSH key)
   - See [SECURITY_SETUP.md](SECURITY_SETUP.md) for detailed instructions

2. **Deploy via GitHub Actions**:
   - Push to `main` branch triggers automatic deployment
   - Monitor progress in Actions tab

### Manual Deployment
1. Clone this repository
2. Set up SSH key: `export SSH_KEY=/path/to/your/ssh/key`
3. Run deployment: `bash scripts/deploy.sh`
4. Verify deployment: `bash scripts/test-everything.sh`

## 📁 Project Structure

```
├── ansible/                 # Ansible playbooks for server setup
│   ├── deploy.yml          # Main deployment playbook
│   └── inventory           # Server configuration
├── kubernetes/             # Kubernetes manifests
│   ├── database/           # PostgreSQL configuration
│   ├── ollama/             # Ollama deployment
│   ├── openwebui/          # OpenWebUI deployment
│   ├── monitoring/         # Prometheus + Grafana
│   └── ingress.yaml        # SSL/TLS ingress configuration
├── scripts/                # Deployment and testing scripts
│   ├── deploy.sh           # Manual deployment script
│   ├── test-everything.sh  # Comprehensive test suite
│   └── verify-deployment.sh # Deployment verification
├── .github/workflows/      # CI/CD pipeline
│   └── deploy.yml          # GitHub Actions workflow
├── docs/                   # Architecture documentation
└── SECURITY_SETUP.md       # SSH key security guide
```

## 🧪 Testing & Verification

The repository includes comprehensive testing:

```bash
# Run full test suite
bash scripts/test-everything.sh

# Quick deployment verification
bash scripts/verify-deployment.sh
```

**Test Coverage**:
- ✅ Pre-deployment validation (files, syntax, connectivity)
- ✅ Infrastructure testing (Kubernetes, SSL certificates)
- ✅ Application accessibility (OpenWebUI, Grafana, Prometheus)
- ✅ Functional testing (database, Ollama pods)
- ✅ Performance testing (response times)
- ✅ Security testing (SSL/TLS, redirects)

## 🔒 Security Features

- **SSH Key Management**: Keys stored in GitHub Secrets, not repository
- **SSL/TLS**: Automatic Let's Encrypt certificate provisioning
- **Firewall**: Configured UFW with minimal required ports
- **Authentication**: Admin access with strong passwords
- **Monitoring**: Full observability with Prometheus metrics

## 📊 Monitoring & Observability

- **Prometheus**: Metrics collection and alerting
- **Grafana**: Dashboards and visualization
- **Kubernetes**: Built-in monitoring with metrics-server
- **Logs**: Centralized logging via kubectl

## 🛠️ Maintenance

### Updating Applications
```bash
# Update via GitHub Actions (recommended)
git push origin main

# Manual update
bash scripts/deploy.sh
```

### Monitoring Health
```bash
# Check all pods
kubectl get pods -A

# View logs
kubectl logs -f deployment/openwebui -n openwebui
```

## 📚 Documentation

- [Security Setup Guide](SECURITY_SETUP.md) - SSH key configuration
- [Architecture Documentation](docs/) - Detailed system design
- [Testing Guide](TESTING_GUIDE.md) - Comprehensive testing procedures

## 🆘 Troubleshooting

### Common Issues
1. **SSH Connection Failed**: Verify SSH key is properly set in GitHub Secrets
2. **SSL Certificate Issues**: Wait 5-10 minutes for Let's Encrypt provisioning
3. **Pod Not Starting**: Check resource limits and node capacity

### Support
- Check GitHub Actions logs for deployment issues
- Review Kubernetes events: `kubectl get events -A`
- Run test suite for comprehensive diagnostics
