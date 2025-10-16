#!/bin/bash

# Quick Testing Script for OpenWebUI + Ollama
# This script provides quick tests for immediate verification

set -e

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Configuration
SERVER_IP="157.180.80.91"
DOMAIN_OPENWEBUI="devops-ricardovaldez.darienc.com"
DOMAIN_MONITORING="devops-monitor-ricardovaldez.darienc.com"
SSH_KEY="ansible/ssh_key"

echo -e "${GREEN}🚀 Quick Test Suite for OpenWebUI + Ollama${NC}"
echo -e "${GREEN}===============================================${NC}"

# Function to test URL
test_url() {
    local url="$1"
    local name="$2"
    
    echo -n "Testing $name... "
    if curl -f -s --max-time 10 "$url" > /dev/null 2>&1; then
        echo -e "${GREEN}✅ PASS${NC}"
        return 0
    else
        echo -e "${RED}❌ FAIL${NC}"
        return 1
    fi
}

# Function to test SSH command
test_ssh() {
    local command="$1"
    local name="$2"
    
    echo -n "Testing $name... "
    if ssh -i "$SSH_KEY" -o ConnectTimeout=10 -o StrictHostKeyChecking=no root@"$SERVER_IP" "$command" > /dev/null 2>&1; then
        echo -e "${GREEN}✅ PASS${NC}"
        return 0
    else
        echo -e "${RED}❌ FAIL${NC}"
        return 1
    fi
}

echo -e "\n${YELLOW}📋 Pre-Deployment Tests${NC}"
echo -e "========================"

# Test 1: Server connectivity
test_ssh "echo 'Connected'" "Server SSH connectivity"

# Test 2: Server resources
echo -n "Server resources... "
RESOURCES=$(ssh -i "$SSH_KEY" root@"$SERVER_IP" "free -h | grep Mem | awk '{print \$2}' && nproc" 2>/dev/null)
if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ PASS${NC}"
    echo -e "   ${YELLOW}Memory: $(echo $RESOURCES | head -1)${NC}"
    echo -e "   ${YELLOW}CPUs: $(echo $RESOURCES | tail -1)${NC}"
else
    echo -e "${RED}❌ FAIL${NC}"
fi

# Test 3: Configuration files
echo -n "Configuration files... "
if [ -f "ansible/ssh_key" ] && [ -f "ansible/inventory" ] && [ -f "ansible/deploy.yml" ]; then
    echo -e "${GREEN}✅ PASS${NC}"
else
    echo -e "${RED}❌ FAIL${NC}"
fi

echo -e "\n${YELLOW}🚀 Deployment Tests${NC}"
echo -e "===================="

# Test 4: Kubernetes cluster
test_ssh "kubectl get nodes" "Kubernetes cluster"

# Test 5: Pod status
echo -n "Pod status... "
PODS=$(ssh -i "$SSH_KEY" root@"$SERVER_IP" "kubectl get pods -A --no-headers | wc -l" 2>/dev/null)
if [ $? -eq 0 ] && [ "$PODS" -gt 0 ]; then
    echo -e "${GREEN}✅ PASS ($PODS pods)${NC}"
else
    echo -e "${YELLOW}⚠️  No pods found (deployment may be in progress)${NC}"
fi

# Test 6: Services
echo -n "Services... "
SERVICES=$(ssh -i "$SSH_KEY" root@"$SERVER_IP" "kubectl get services -A --no-headers | wc -l" 2>/dev/null)
if [ $? -eq 0 ] && [ "$SERVICES" -gt 0 ]; then
    echo -e "${GREEN}✅ PASS ($SERVICES services)${NC}"
else
    echo -e "${YELLOW}⚠️  No services found${NC}"
fi

echo -e "\n${YELLOW}🌐 Application Tests${NC}"
echo -e "===================="

# Test 7: OpenWebUI HTTP
test_url "http://$DOMAIN_OPENWEBUI" "OpenWebUI HTTP access"

# Test 8: OpenWebUI HTTPS
test_url "https://$DOMAIN_OPENWEBUI" "OpenWebUI HTTPS access"

# Test 9: Monitoring HTTP
test_url "http://$DOMAIN_MONITORING/grafana" "Grafana HTTP access"

# Test 10: Monitoring HTTPS
test_url "https://$DOMAIN_MONITORING/grafana" "Grafana HTTPS access"

# Test 11: SSL Certificate
echo -n "SSL certificate... "
CERT=$(openssl s_client -connect "$DOMAIN_OPENWEBUI:443" -servername "$DOMAIN_OPENWEBUI" < /dev/null 2>/dev/null | openssl x509 -noout -dates 2>/dev/null)
if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ PASS${NC}"
else
    echo -e "${RED}❌ FAIL${NC}"
fi

echo -e "\n${YELLOW}📊 Performance Tests${NC}"
echo -e "===================="

# Test 12: Response time
echo -n "Response time... "
RESPONSE_TIME=$(curl -o /dev/null -s -w "%{time_total}" "https://$DOMAIN_OPENWEBUI" 2>/dev/null || echo "999")
if (( $(echo "$RESPONSE_TIME < 10" | bc -l 2>/dev/null || echo "1") )); then
    echo -e "${GREEN}✅ PASS (${RESPONSE_TIME}s)${NC}"
else
    echo -e "${RED}❌ FAIL (${RESPONSE_TIME}s)${NC}"
fi

# Test 13: Memory usage
echo -n "Memory usage... "
MEMORY_USAGE=$(ssh -i "$SSH_KEY" root@"$SERVER_IP" "free | awk 'NR==2{printf \"%.0f\", \$3*100/\$2}'" 2>/dev/null || echo "100")
if [ "$MEMORY_USAGE" -lt 90 ]; then
    echo -e "${GREEN}✅ PASS (${MEMORY_USAGE}%)${NC}"
else
    echo -e "${RED}❌ FAIL (${MEMORY_USAGE}%)${NC}"
fi

echo -e "\n${YELLOW}🔧 Manual Verification Steps${NC}"
echo -e "=============================="
echo -e "1. Open browser and go to: ${GREEN}https://$DOMAIN_OPENWEBUI${NC}"
echo -e "   Username: ${YELLOW}admin${NC}"
echo -e "   Password: ${YELLOW}Darient123${NC}"
echo -e ""
echo -e "2. Access monitoring at: ${GREEN}https://$DOMAIN_MONITORING/grafana${NC}"
echo -e "   Username: ${YELLOW}admin${NC}"
echo -e "   Password: ${YELLOW}Darient123${NC}"
echo -e ""
echo -e "3. Test chat functionality with Llama3-8B model"

echo -e "\n${YELLOW}📝 Troubleshooting Commands${NC}"
echo -e "=============================="
echo -e "Check pod status:"
echo -e "  ${YELLOW}ssh -i $SSH_KEY root@$SERVER_IP 'kubectl get pods -A'${NC}"
echo -e ""
echo -e "Check logs:"
echo -e "  ${YELLOW}ssh -i $SSH_KEY root@$SERVER_IP 'kubectl logs -n ollama deployment/ollama'${NC}"
echo -e ""
echo -e "Restart deployment:"
echo -e "  ${YELLOW}ssh -i $SSH_KEY root@$SERVER_IP 'kubectl rollout restart deployment/ollama -n ollama'${NC}"

echo -e "\n${GREEN}✅ Quick test completed!${NC}"
echo -e "${GREEN}Run './scripts/test-everything.sh' for comprehensive testing.${NC}"
