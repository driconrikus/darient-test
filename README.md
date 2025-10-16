# OpenWebUI + Ollama Deployment

This repository contains the deployment configuration for OpenWebUI + Ollama with local LLM models, including high availability, security, monitoring, and CI/CD pipeline.

## Architecture Overview

### Part 1: Single Server Deployment
- **Kubernetes**: k3s lightweight distribution
- **Ollama**: 2 replicas for high availability with Llama3-8B model
- **OpenWebUI**: Web interface with admin access
- **PostgreSQL**: Database for chat history and metadata
- **Monitoring**: Prometheus + Grafana stack
- **SSL**: Let's Encrypt certificates
- **CI/CD**: GitHub Actions pipeline

### Part 2: SaaS Architecture Design
- Multi-tenant architecture for enterprise clients
- GPU-accelerated nodes for premium models
- Cost optimization with Spot instances
- Robust data architecture with managed databases
- Advanced security and governance
- Comprehensive observability stack

## Deployment Credentials

### Server Access
- **IP**: 157.180.80.91
- **User**: root
- **OS**: Ubuntu 24.04 LTS
- **Specs**: 4GB RAM, 3 vCPU

### Application Access
- **OpenWebUI**: https://devops-ricardovaldez.darienc.com
  - User: admin
  - Password: Darient123
- **Monitoring**: https://devops-monitor-ricardovaldez.darienc.com

## Quick Start

1. Clone this repository
2. Update server IP and SSH key in `ansible/inventory`
3. Run deployment: `ansible-playbook -i ansible/inventory ansible/deploy.yml`
4. Access applications via provided domains

## Project Structure

```
├── ansible/                 # Ansible playbooks for server setup
├── kubernetes/             # Kubernetes manifests
├── monitoring/             # Monitoring configurations
├── .github/workflows/      # CI/CD pipeline
├── docs/                   # Documentation
└── scripts/               # Deployment scripts
```
