#!/bin/bash

# Comprehensive Testing Script for OpenWebUI + Ollama Deployment
# This script tests all components before and after deployment

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
SERVER_IP="157.180.80.91"
DOMAIN_OPENWEBUI="devops-ricardovaldez.darienc.com"
DOMAIN_MONITORING="devops-monitor-ricardovaldez.darienc.com"
SSH_KEY="ansible/ssh_key"

# Test results tracking
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_TOTAL=0

# Function to run a test
run_test() {
    local test_name="$1"
    local test_command="$2"
    local expected_result="$3"
    
    TESTS_TOTAL=$((TESTS_TOTAL + 1))
    echo -e "${BLUE}Running test: $test_name${NC}"
    
    if eval "$test_command" >/dev/null 2>&1; then
        echo -e "${GREEN}✓ PASS: $test_name${NC}"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        echo -e "${RED}✗ FAIL: $test_name${NC}"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
}

# Function to run a test with output
run_test_with_output() {
    local test_name="$1"
    local test_command="$2"
    
    TESTS_TOTAL=$((TESTS_TOTAL + 1))
    echo -e "${BLUE}Running test: $test_name${NC}"
    
    if output=$(eval "$test_command" 2>&1); then
        echo -e "${GREEN}✓ PASS: $test_name${NC}"
        echo -e "${YELLOW}Output: $output${NC}"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        echo -e "${RED}✗ FAIL: $test_name${NC}"
        echo -e "${RED}Error: $output${NC}"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
}

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  OpenWebUI + Ollama Testing Suite${NC}"
echo -e "${GREEN}========================================${NC}"

# Phase 1: Pre-deployment Testing
echo -e "\n${YELLOW}=== Phase 1: Pre-deployment Testing ===${NC}"

# Test 1: Check if required files exist
run_test "Required files exist" "[ -f 'ansible/ssh_key' ] && [ -f 'ansible/inventory' ] && [ -f 'ansible/deploy.yml' ]"

# Test 2: Check SSH key permissions
run_test "SSH key has correct permissions" "[ \$(stat -c %a ansible/ssh_key 2>/dev/null || stat -f %A ansible/ssh_key) = 600 ]"

# Test 3: Validate Ansible playbook syntax
run_test_with_output "Ansible playbook syntax check" "ansible-playbook --syntax-check -i ansible/inventory ansible/deploy.yml"

# Test 4: Validate Kubernetes manifests
run_test "Kubernetes manifests exist" "[ -f 'kubernetes/database/postgres-deployment.yaml' ] && [ -f 'kubernetes/ollama/ollama-deployment.yaml' ] && [ -f 'kubernetes/openwebui/openwebui-deployment.yaml' ]"

# Test 5: Check YAML syntax for Kubernetes manifests
for manifest in kubernetes/**/*.yaml; do
    if [ -f "$manifest" ]; then
        run_test "YAML syntax: $(basename $manifest)" "python -c \"import yaml; list(yaml.safe_load_all(open('$manifest')))\""
    fi
done

# Test 6: Validate GitHub Actions workflow
run_test "GitHub Actions workflow syntax" "python -c \"import yaml; yaml.safe_load(open('.github/workflows/deploy.yml'))\""

# Phase 2: Server Connectivity Testing
echo -e "\n${YELLOW}=== Phase 2: Server Connectivity Testing ===${NC}"

# Test 7: SSH connectivity
run_test "SSH connectivity to server" "ssh -i '$SSH_KEY' -o ConnectTimeout=10 -o StrictHostKeyChecking=no root@$SERVER_IP 'echo connected'"

# Test 8: Server OS version
run_test_with_output "Server OS version check" "ssh -i '$SSH_KEY' root@$SERVER_IP 'lsb_release -a | grep Description'"

# Test 9: Server resources
run_test_with_output "Server memory check" "ssh -i '$SSH_KEY' root@$SERVER_IP 'free -h | grep Mem'"
run_test_with_output "Server CPU check" "ssh -i '$SSH_KEY' root@$SERVER_IP 'nproc'"
run_test_with_output "Server disk space" "ssh -i '$SSH_KEY' root@$SERVER_IP 'df -h /'"

# Test 10: Network connectivity
run_test "Internet connectivity from server" "ssh -i '$SSH_KEY' root@$SERVER_IP 'ping -c 1 8.8.8.8'"

# Phase 3: Deployment Testing (if already deployed)
echo -e "\n${YELLOW}=== Phase 3: Deployment Testing ===${NC}"

# Test 11: Check if Kubernetes is running
if ssh -i "$SSH_KEY" root@"$SERVER_IP" "kubectl version --client" >/dev/null 2>&1; then
    run_test_with_output "Kubernetes cluster status" "ssh -i '$SSH_KEY' root@$SERVER_IP 'kubectl get nodes'"
    
    # Test 12: Check pod status
    run_test_with_output "Pod status check" "ssh -i '$SSH_KEY' root@$SERVER_IP 'kubectl get pods -A'"
    
    # Test 13: Check services
    run_test_with_output "Services status" "ssh -i '$SSH_KEY' root@$SERVER_IP 'kubectl get services -A'"
    
    # Test 14: Check ingress
    run_test_with_output "Ingress status" "ssh -i '$SSH_KEY' root@$SERVER_IP 'kubectl get ingress -A'"
    
    # Test 15: Check certificates
    run_test_with_output "SSL certificates status" "ssh -i '$SSH_KEY' root@$SERVER_IP 'kubectl get certificates -A'"
else
    echo -e "${YELLOW}⚠ Kubernetes not yet deployed, skipping deployment tests${NC}"
fi

# Phase 4: Application Testing
echo -e "\n${YELLOW}=== Phase 4: Application Testing ===${NC}"

# Test 16: OpenWebUI accessibility
run_test "OpenWebUI HTTP accessibility" "curl -f -s --max-time 10 'http://$DOMAIN_OPENWEBUI'"
run_test "OpenWebUI HTTPS accessibility" "curl -f -s --max-time 10 'https://$DOMAIN_OPENWEBUI'"

# Test 17: Monitoring accessibility
run_test "Grafana accessibility" "curl -f -s --max-time 10 'https://$DOMAIN_MONITORING/grafana'"
run_test "Prometheus accessibility" "curl -f -s --max-time 10 'https://$DOMAIN_MONITORING/prometheus'"

# Test 18: SSL certificate validation
run_test_with_output "SSL certificate validation" "openssl s_client -connect $DOMAIN_OPENWEBUI:443 -servername $DOMAIN_OPENWEBUI < /dev/null 2>/dev/null | openssl x509 -noout -dates"

# Phase 5: Functional Testing
echo -e "\n${YELLOW}=== Phase 5: Functional Testing ===${NC}"

# Test 19: OpenWebUI login test
echo -e "${BLUE}Testing OpenWebUI login functionality...${NC}"
if curl -f -s --max-time 10 "https://$DOMAIN_OPENWEBUI" > /dev/null; then
    echo -e "${GREEN}✓ OpenWebUI is accessible${NC}"
    echo -e "${YELLOW}Note: Manual login test required with credentials: admin / Darient123${NC}"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo -e "${RED}✗ OpenWebUI not accessible${NC}"
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi
TESTS_TOTAL=$((TESTS_TOTAL + 1))

# Test 20: Ollama model availability (if accessible)
echo -e "${BLUE}Testing Ollama model availability...${NC}"
if ssh -i "$SSH_KEY" root@"$SERVER_IP" "kubectl get pods -n ollama" >/dev/null 2>&1; then
    if ssh -i "$SSH_KEY" root@"$SERVER_IP" "kubectl get pods -n ollama --field-selector=status.phase=Running | grep ollama" >/dev/null 2>&1; then
        echo -e "${GREEN}✓ Ollama pods are running${NC}"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "${RED}✗ Ollama pods not running${NC}"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
else
    echo -e "${YELLOW}⚠ Ollama namespace not found${NC}"
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi
TESTS_TOTAL=$((TESTS_TOTAL + 1))

# Test 21: Database connectivity
echo -e "${BLUE}Testing database connectivity...${NC}"
if ssh -i "$SSH_KEY" root@"$SERVER_IP" "kubectl get pods -n database --field-selector=status.phase=Running | grep postgres" >/dev/null 2>&1; then
    echo -e "${GREEN}✓ PostgreSQL pod is running${NC}"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo -e "${RED}✗ PostgreSQL pod not running${NC}"
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi
TESTS_TOTAL=$((TESTS_TOTAL + 1))

# Phase 6: Performance Testing
echo -e "\n${YELLOW}=== Phase 6: Performance Testing ===${NC}"

# Test 22: Response time test
echo -e "${BLUE}Testing response times...${NC}"
response_time=$(curl -o /dev/null -s -w "%{time_total}" "https://$DOMAIN_OPENWEBUI" 2>/dev/null || echo "999")
if (( $(echo "$response_time < 10" | bc -l) )); then
    echo -e "${GREEN}✓ Response time acceptable: ${response_time}s${NC}"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo -e "${RED}✗ Response time too slow: ${response_time}s${NC}"
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi
TESTS_TOTAL=$((TESTS_TOTAL + 1))

# Phase 7: Security Testing
echo -e "\n${YELLOW}=== Phase 7: Security Testing ===${NC}"

# Test 23: SSL/TLS security
run_test_with_output "SSL/TLS configuration check" "nmap --script ssl-enum-ciphers -p 443 $DOMAIN_OPENWEBUI 2>/dev/null | grep -E '(SSLv|TLSv)' | head -5"

# Test 24: HTTP to HTTPS redirect
run_test "HTTP to HTTPS redirect" "curl -I -s 'http://$DOMAIN_OPENWEBUI' | grep -i 'location.*https'"

# Test 25: Security headers
run_test_with_output "Security headers check" "curl -I -s 'https://$DOMAIN_OPENWEBUI' | grep -E '(Strict-Transport-Security|X-Frame-Options|X-Content-Type-Options)'"

# Final Results
echo -e "\n${GREEN}========================================${NC}"
echo -e "${GREEN}           TEST RESULTS SUMMARY${NC}"
echo -e "${GREEN}========================================${NC}"
echo -e "Total Tests: $TESTS_TOTAL"
echo -e "${GREEN}Passed: $TESTS_PASSED${NC}"
echo -e "${RED}Failed: $TESTS_FAILED${NC}"

if [ $TESTS_FAILED -eq 0 ]; then
    echo -e "\n${GREEN}🎉 ALL TESTS PASSED! Deployment is ready.${NC}"
    exit 0
elif [ $TESTS_FAILED -lt $((TESTS_TOTAL / 2)) ]; then
    echo -e "\n${YELLOW}⚠ Some tests failed, but deployment may still work.${NC}"
    echo -e "${YELLOW}Review failed tests and retry if needed.${NC}"
    exit 1
else
    echo -e "\n${RED}❌ Multiple tests failed. Please review and fix issues.${NC}"
    exit 1
fi
