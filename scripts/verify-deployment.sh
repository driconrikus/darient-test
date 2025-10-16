#!/bin/bash

# Deployment Verification Script
# This script verifies that all components are running correctly

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
SSH_KEY="ansible/ssh_key"

echo -e "${GREEN}Starting deployment verification...${NC}"

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check prerequisites
echo -e "${YELLOW}Checking prerequisites...${NC}"

if ! command_exists ssh; then
    echo -e "${RED}Error: SSH client not found${NC}"
    exit 1
fi

if ! command_exists curl; then
    echo -e "${RED}Error: curl not found${NC}"
    exit 1
fi

if [ ! -f "$SSH_KEY" ]; then
    echo -e "${RED}Error: SSH key not found at $SSH_KEY${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Prerequisites check passed${NC}"

# Test SSH connection
echo -e "${YELLOW}Testing SSH connection...${NC}"
if ssh -i "$SSH_KEY" -o ConnectTimeout=10 -o StrictHostKeyChecking=no root@"$SERVER_IP" "echo 'SSH connection successful'" >/dev/null 2>&1; then
    echo -e "${GREEN}✓ SSH connection successful${NC}"
else
    echo -e "${RED}✗ SSH connection failed${NC}"
    exit 1
fi

# Check Kubernetes cluster status
echo -e "${YELLOW}Checking Kubernetes cluster...${NC}"
CLUSTER_STATUS=$(ssh -i "$SSH_KEY" root@"$SERVER_IP" "kubectl get nodes --no-headers | wc -l" 2>/dev/null || echo "0")

if [ "$CLUSTER_STATUS" -gt 0 ]; then
    echo -e "${GREEN}✓ Kubernetes cluster is running ($CLUSTER_STATUS nodes)${NC}"
else
    echo -e "${RED}✗ Kubernetes cluster is not running${NC}"
    exit 1
fi

# Check pod status
echo -e "${YELLOW}Checking pod status...${NC}"
POD_STATUS=$(ssh -i "$SSH_KEY" root@"$SERVER_IP" "kubectl get pods -A --field-selector=status.phase!=Running,status.phase!=Succeeded --no-headers | wc -l" 2>/dev/null || echo "999")

if [ "$POD_STATUS" -eq 0 ]; then
    echo -e "${GREEN}✓ All pods are running successfully${NC}"
else
    echo -e "${YELLOW}⚠ Some pods are not running ($POD_STATUS pods with issues)${NC}"
    ssh -i "$SSH_KEY" root@"$SERVER_IP" "kubectl get pods -A --field-selector=status.phase!=Running,status.phase!=Succeeded"
fi

# Check services
echo -e "${YELLOW}Checking services...${NC}"
SERVICES=$(ssh -i "$SSH_KEY" root@"$SERVER_IP" "kubectl get services -A --no-headers | wc -l" 2>/dev/null || echo "0")

if [ "$SERVICES" -gt 0 ]; then
    echo -e "${GREEN}✓ Services are configured ($SERVICES services)${NC}"
else
    echo -e "${RED}✗ No services found${NC}"
fi

# Check ingress
echo -e "${YELLOW}Checking ingress configuration...${NC}"
INGRESS_STATUS=$(ssh -i "$SSH_KEY" root@"$SERVER_IP" "kubectl get ingress -A --no-headers | wc -l" 2>/dev/null || echo "0")

if [ "$INGRESS_STATUS" -gt 0 ]; then
    echo -e "${GREEN}✓ Ingress is configured ($INGRESS_STATUS ingress rules)${NC}"
else
    echo -e "${RED}✗ No ingress found${NC}"
fi

# Test OpenWebUI accessibility
echo -e "${YELLOW}Testing OpenWebUI accessibility...${NC}"
if curl -f -s -o /dev/null --max-time 30 "https://$DOMAIN_OPENWEBUI"; then
    echo -e "${GREEN}✓ OpenWebUI is accessible at https://$DOMAIN_OPENWEBUI${NC}"
else
    echo -e "${YELLOW}⚠ OpenWebUI may not be accessible yet (this is normal during deployment)${NC}"
fi

# Test monitoring accessibility
echo -e "${YELLOW}Testing monitoring accessibility...${NC}"
if curl -f -s -o /dev/null --max-time 30 "https://$DOMAIN_MONITORING/grafana"; then
    echo -e "${GREEN}✓ Grafana is accessible at https://$DOMAIN_MONITORING/grafana${NC}"
else
    echo -e "${YELLOW}⚠ Grafana may not be accessible yet (this is normal during deployment)${NC}"
fi

# Check SSL certificates
echo -e "${YELLOW}Checking SSL certificates...${NC}"
CERT_STATUS=$(ssh -i "$SSH_KEY" root@"$SERVER_IP" "kubectl get certificates -A --no-headers | wc -l" 2>/dev/null || echo "0")

if [ "$CERT_STATUS" -gt 0 ]; then
    echo -e "${GREEN}✓ SSL certificates are configured ($CERT_STATUS certificates)${NC}"
else
    echo -e "${YELLOW}⚠ SSL certificates may still be provisioning${NC}"
fi

# Check disk space
echo -e "${YELLOW}Checking disk space...${NC}"
DISK_USAGE=$(ssh -i "$SSH_KEY" root@"$SERVER_IP" "df -h / | awk 'NR==2 {print \$5}' | sed 's/%//'" 2>/dev/null || echo "100")

if [ "$DISK_USAGE" -lt 90 ]; then
    echo -e "${GREEN}✓ Disk usage is healthy ($DISK_USAGE% used)${NC}"
else
    echo -e "${RED}✗ Disk usage is high ($DISK_USAGE% used)${NC}"
fi

# Check memory usage
echo -e "${YELLOW}Checking memory usage...${NC}"
MEMORY_USAGE=$(ssh -i "$SSH_KEY" root@"$SERVER_IP" "free | awk 'NR==2{printf \"%.0f\", \$3*100/\$2}'" 2>/dev/null || echo "100")

if [ "$MEMORY_USAGE" -lt 90 ]; then
    echo -e "${GREEN}✓ Memory usage is healthy ($MEMORY_USAGE% used)${NC}"
else
    echo -e "${RED}✗ Memory usage is high ($MEMORY_USAGE% used)${NC}"
fi

# Summary
echo -e "\n${GREEN}=== Deployment Verification Summary ===${NC}"
echo -e "Server IP: $SERVER_IP"
echo -e "OpenWebUI: https://$DOMAIN_OPENWEBUI"
echo -e "  Username: admin"
echo -e "  Password: Darient123"
echo -e "Monitoring: https://$DOMAIN_MONITORING/grafana"
echo -e "  Username: admin"
echo -e "  Password: Darient123"

echo -e "\n${YELLOW}Note: If some services show as not accessible, they may still be deploying.${NC}"
echo -e "${YELLOW}SSL certificates can take up to 10 minutes to provision.${NC}"
echo -e "${YELLOW}Wait a few minutes and run this script again if needed.${NC}"

echo -e "\n${GREEN}Verification completed!${NC}"
