#!/bin/bash

# OpenWebUI + Ollama Deployment Script
# This script deploys the complete stack to the server

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
SERVER_IP="157.180.80.91"
DOMAIN_OPENWEBUI="devops-ricardovaldez.darienc.com"
DOMAIN_MONITORING="devops-monitor-ricardovaldez.darienc.com"
SSH_KEY="${SSH_KEY:-ansible/ssh_key}"

echo -e "${GREEN}Starting OpenWebUI + Ollama deployment...${NC}"

# Check if SSH key exists
if [ ! -f "$SSH_KEY" ]; then
    echo -e "${RED}Error: SSH key not found at $SSH_KEY${NC}"
    exit 1
fi

# Set proper permissions for SSH key
chmod 600 "$SSH_KEY"

# Test SSH connection
echo -e "${YELLOW}Testing SSH connection...${NC}"
ssh -i "$SSH_KEY" -o ConnectTimeout=10 -o StrictHostKeyChecking=no root@"$SERVER_IP" "echo 'SSH connection successful'"

if [ $? -ne 0 ]; then
    echo -e "${RED}Error: Cannot connect to server${NC}"
    exit 1
fi

# Install Ansible if not present
if ! command -v ansible &> /dev/null; then
    echo -e "${YELLOW}Installing Ansible...${NC}"
    pip install ansible kubernetes
fi

# Run Ansible playbook
echo -e "${YELLOW}Running Ansible deployment...${NC}"
ansible-playbook -i ansible/inventory ansible/deploy.yml \
    --private-key "$SSH_KEY" \
    --extra-vars "domain_openwebui=$DOMAIN_OPENWEBUI" \
    --extra-vars "domain_monitoring=$DOMAIN_MONITORING" \
    --extra-vars "ansible_ssh_private_key_file=$SSH_KEY"

if [ $? -ne 0 ]; then
    echo -e "${RED}Error: Ansible deployment failed${NC}"
    exit 1
fi

# Verify deployment
echo -e "${YELLOW}Verifying deployment...${NC}"
ssh -i "$SSH_KEY" root@"$SERVER_IP" "
    echo 'Checking Kubernetes cluster status...'
    kubectl get nodes
    echo ''
    echo 'Checking pod status...'
    kubectl get pods -A
    echo ''
    echo 'Checking ingress status...'
    kubectl get ingress -A
"

# Health checks
echo -e "${YELLOW}Performing health checks...${NC}"
sleep 30

echo -e "${YELLOW}Checking OpenWebUI accessibility...${NC}"
if curl -f -s "https://$DOMAIN_OPENWEBUI" > /dev/null; then
    echo -e "${GREEN}✓ OpenWebUI is accessible${NC}"
else
    echo -e "${RED}✗ OpenWebUI is not accessible${NC}"
fi

echo -e "${YELLOW}Checking monitoring accessibility...${NC}"
if curl -f -s "https://$DOMAIN_MONITORING/grafana" > /dev/null; then
    echo -e "${GREEN}✓ Grafana is accessible${NC}"
else
    echo -e "${RED}✗ Grafana is not accessible${NC}"
fi

echo -e "${GREEN}Deployment completed!${NC}"
echo -e "${YELLOW}Access URLs:${NC}"
echo -e "OpenWebUI: https://$DOMAIN_OPENWEBUI"
echo -e "  Username: admin"
echo -e "  Password: Darient123"
echo -e "Monitoring: https://$DOMAIN_MONITORING/grafana"
echo -e "  Username: admin"
echo -e "  Password: Darient123"
