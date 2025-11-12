#!/bin/bash

# Quick Service Discovery Verification Script
# Run this after applying the fixes to verify everything is working

set -e

echo "🔍 Service Discovery Verification"
echo "=================================="
echo ""

# Color codes
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

print_check() {
    if [ $1 -eq 0 ]; then
        echo -e "${GREEN}✓${NC} $2"
    else
        echo -e "${RED}✗${NC} $2"
    fi
}

print_info() {
    echo -e "${YELLOW}ℹ${NC} $1"
}

# Check 1: All services exist and are ClusterIP
echo "1. Checking service definitions..."
echo "-----------------------------------"

SERVICES=("auth-service" "vehicle-service" "appointment-service" "project-service" 
          "time-logging-service" "payment-service" "admin-service" 
          "notification-service" "agent-bot-service" "api-gateway-service"
          "notification-service-grpc")

for svc in "${SERVICES[@]}"; do
    if kubectl get service "$svc" &>/dev/null; then
        TYPE=$(kubectl get service "$svc" -o jsonpath='{.spec.type}')
        PORT=$(kubectl get service "$svc" -o jsonpath='{.spec.ports[0].port}')
        print_check 0 "$svc exists ($TYPE, Port: $PORT)"
    else
        print_check 1 "$svc NOT FOUND"
    fi
done

echo ""
echo "2. Checking ConfigMap values..."
echo "--------------------------------"

# Check auth configmap
GRPC_TARGET=$(kubectl get configmap auth-config -o jsonpath='{.data.NOTIFICATION_GRPC_TARGET}' 2>/dev/null)
if [[ "$GRPC_TARGET" == "notification-service-grpc:9090" ]]; then
    print_check 0 "Auth gRPC target: $GRPC_TARGET"
else
    print_check 1 "Auth gRPC target INCORRECT: $GRPC_TARGET (expected: notification-service-grpc:9090)"
fi

# Check agent bot configmap
AGENT_AUTH_URL=$(kubectl get configmap agent-bot-config -o jsonpath='{.data.AUTHENTICATION_SERVICE_URL}' 2>/dev/null)
if [[ "$AGENT_AUTH_URL" == "http://auth-service:80" ]]; then
    print_check 0 "Agent Bot auth URL: $AGENT_AUTH_URL"
else
    print_check 1 "Agent Bot auth URL INCORRECT: $AGENT_AUTH_URL (expected: http://auth-service:80)"
fi

AGENT_VEHICLE_URL=$(kubectl get configmap agent-bot-config -o jsonpath='{.data.VEHICLE_SERVICE_URL}' 2>/dev/null)
if [[ "$AGENT_VEHICLE_URL" == "http://vehicle-service:80" ]]; then
    print_check 0 "Agent Bot vehicle URL: $AGENT_VEHICLE_URL"
else
    print_check 1 "Agent Bot vehicle URL INCORRECT: $AGENT_VEHICLE_URL"
fi

echo ""
echo "3. Checking deployment environment variables..."
echo "------------------------------------------------"

# Check gateway deployment
GATEWAY_POD=$(kubectl get pods -l app=api-gateway -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
if [ -n "$GATEWAY_POD" ]; then
    AUTH_URL=$(kubectl exec "$GATEWAY_POD" -- env | grep "AUTH_SERVICE_URL=" | cut -d'=' -f2 2>/dev/null || echo "")
    if [[ "$AUTH_URL" == "http://auth-service:80" ]]; then
        print_check 0 "Gateway AUTH_SERVICE_URL: $AUTH_URL"
    else
        print_check 1 "Gateway AUTH_SERVICE_URL INCORRECT: $AUTH_URL"
    fi
else
    print_check 1 "No gateway pod found"
fi

# Check admin deployment
ADMIN_POD=$(kubectl get pods -l app=admin-service -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
if [ -n "$ADMIN_POD" ]; then
    ADMIN_AUTH_URL=$(kubectl exec "$ADMIN_POD" -- env | grep "AUTH_SERVICE_URL=" | cut -d'=' -f2 2>/dev/null || echo "")
    if [[ "$ADMIN_AUTH_URL" == "http://auth-service:80" ]]; then
        print_check 0 "Admin AUTH_SERVICE_URL: $ADMIN_AUTH_URL"
    else
        print_check 1 "Admin AUTH_SERVICE_URL INCORRECT: $ADMIN_AUTH_URL"
    fi
else
    print_check 1 "No admin pod found"
fi

echo ""
echo "4. Checking pod status..."
echo "-------------------------"

# Check if all critical pods are running
DEPLOYMENTS=("api-gateway-deployment" "auth-deployment" "admin-deployment" 
             "agent-bot-deployment" "vehicle-deployment" "notification-deployment")

for deploy in "${DEPLOYMENTS[@]}"; do
    READY=$(kubectl get deployment "$deploy" -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
    DESIRED=$(kubectl get deployment "$deploy" -o jsonpath='{.spec.replicas}' 2>/dev/null || echo "0")
    if [ "$READY" -eq "$DESIRED" ] && [ "$READY" -gt 0 ]; then
        print_check 0 "$deploy: $READY/$DESIRED pods ready"
    else
        print_check 1 "$deploy: $READY/$DESIRED pods ready"
    fi
done

echo ""
echo "5. Testing service connectivity..."
echo "-----------------------------------"

# Get a test pod
TEST_POD=$(kubectl get pods -l app=api-gateway -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)

if [ -n "$TEST_POD" ]; then
    print_info "Testing from pod: $TEST_POD"
    
    # Test DNS resolution
    for svc in "auth-service" "vehicle-service" "notification-service" "notification-service-grpc"; do
        if kubectl exec "$TEST_POD" -- nslookup "$svc" &>/dev/null; then
            print_check 0 "DNS resolution for $svc"
        else
            print_check 1 "DNS resolution for $svc FAILED"
        fi
    done
    
    echo ""
    print_info "Testing HTTP connectivity..."
    
    # Test HTTP connectivity (both 200 and 404 are acceptable - means service is up)
    for svc in "auth-service:80" "vehicle-service:80" "notification-service:80"; do
        HTTP_CODE=$(kubectl exec "$TEST_POD" -- curl -s -o /dev/null -w "%{http_code}" "http://$svc/health" 2>/dev/null || echo "000")
        if [[ "$HTTP_CODE" =~ ^(200|404|401)$ ]]; then
            print_check 0 "HTTP connectivity to $svc (HTTP $HTTP_CODE)"
        else
            print_check 1 "HTTP connectivity to $svc FAILED (HTTP $HTTP_CODE)"
        fi
    done
else
    print_check 1 "No test pod available for connectivity testing"
fi

echo ""
echo "6. Checking recent logs for errors..."
echo "--------------------------------------"

# Check for connection errors in logs
print_info "Scanning gateway logs..."
ERROR_COUNT=$(kubectl logs deployment/api-gateway-deployment --tail=50 2>/dev/null | grep -ic "connection refused\|dial tcp.*no such host\|service.*not found" || echo "0")
if [ "$ERROR_COUNT" -eq 0 ]; then
    print_check 0 "No connection errors in gateway logs"
else
    print_check 1 "Found $ERROR_COUNT connection errors in gateway logs"
fi

print_info "Scanning auth logs..."
ERROR_COUNT=$(kubectl logs deployment/auth-deployment --tail=50 2>/dev/null | grep -ic "connection refused\|grpc.*failed\|notification.*error" || echo "0")
if [ "$ERROR_COUNT" -eq 0 ]; then
    print_check 0 "No connection errors in auth logs"
else
    print_check 1 "Found $ERROR_COUNT connection errors in auth logs"
fi

print_info "Scanning agent bot logs..."
ERROR_COUNT=$(kubectl logs deployment/agent-bot-deployment --tail=50 2>/dev/null | grep -ic "connection refused\|http.*error\|failed to connect" || echo "0")
if [ "$ERROR_COUNT" -eq 0 ]; then
    print_check 0 "No connection errors in agent bot logs"
else
    print_check 1 "Found $ERROR_COUNT connection errors in agent bot logs"
fi

echo ""
echo "=================================="
echo "Verification Complete!"
echo "=================================="
echo ""
echo "💡 Tips:"
echo "  • If DNS resolution fails, check CoreDNS: kubectl get pods -n kube-system -l k8s-app=kube-dns"
echo "  • If HTTP tests fail, check service endpoints: kubectl get endpoints <service-name>"
echo "  • For detailed logs: kubectl logs -f deployment/<deployment-name>"
echo "  • To test from browser: https://api.techtorque.randitha.net/api/v1/..."
echo ""
