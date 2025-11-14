#!/bin/bash

# Service Discovery Fix Deployment Script
# This script applies all the fixes for Kubernetes service discovery issues

set -e  # Exit on error

echo "🔧 Starting Service Discovery Fix Deployment..."
echo "================================================"

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}✓${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

# Check if kubectl is available
if ! command -v kubectl &> /dev/null; then
    print_error "kubectl not found. Please install kubectl first."
    exit 1
fi

# Check cluster connectivity
if ! kubectl cluster-info &> /dev/null; then
    print_error "Cannot connect to Kubernetes cluster. Please check your kubeconfig."
    exit 1
fi

print_status "Connected to Kubernetes cluster"

echo ""
echo "Step 1: Backing up current configurations..."
echo "--------------------------------------------"
mkdir -p backup-$(date +%Y%m%d-%H%M%S)
BACKUP_DIR="backup-$(date +%Y%m%d-%H%M%S)"

kubectl get configmap auth-config -o yaml > "$BACKUP_DIR/auth-config-backup.yaml" 2>/dev/null || true
kubectl get configmap agent-bot-config -o yaml > "$BACKUP_DIR/agent-bot-config-backup.yaml" 2>/dev/null || true
kubectl get deployment api-gateway-deployment -o yaml > "$BACKUP_DIR/gateway-deployment-backup.yaml" 2>/dev/null || true
kubectl get deployment admin-deployment -o yaml > "$BACKUP_DIR/admin-deployment-backup.yaml" 2>/dev/null || true

print_status "Backups saved to $BACKUP_DIR/"

echo ""
echo "Step 2: Applying ConfigMap updates..."
echo "--------------------------------------"

# Apply auth configmap (gRPC fix)
kubectl apply -f k8s/configmaps/auth-configmap.yaml
print_status "Applied auth-configmap.yaml (gRPC service discovery fix)"

# Apply agent bot configmap (direct service communication)
kubectl apply -f k8s/configmaps/agent-bot-configmap.yaml
print_status "Applied agent-bot-configmap.yaml (direct service URLs)"

echo ""
echo "Step 3: Applying Deployment updates..."
echo "---------------------------------------"

# Apply gateway deployment (explicit ports)
kubectl apply -f k8s/services/gateway-deployment.yaml
print_status "Applied gateway-deployment.yaml (explicit service ports)"

# Apply admin deployment (explicit auth service port)
kubectl apply -f k8s/services/admin-deployment.yaml
print_status "Applied admin-deployment.yaml (explicit auth service port)"

# Apply agent bot deployment (ensure latest config)
kubectl apply -f k8s/services/agent-bot-deployment.yaml
print_status "Applied agent-bot-deployment.yaml"

# Apply auth deployment (ensure gRPC config is picked up)
kubectl apply -f k8s/services/auth-deployment.yaml
print_status "Applied auth-deployment.yaml"

echo ""
echo "Step 4: Verifying ConfigMap changes..."
echo "---------------------------------------"

# Verify auth config
GRPC_TARGET=$(kubectl get configmap auth-config -o jsonpath='{.data.NOTIFICATION_GRPC_TARGET}')
if [[ "$GRPC_TARGET" == "notification-service-grpc:9090" ]]; then
    print_status "gRPC target correctly set: $GRPC_TARGET"
else
    print_warning "gRPC target may be incorrect: $GRPC_TARGET"
fi

# Verify agent bot config
AUTH_URL=$(kubectl get configmap agent-bot-config -o jsonpath='{.data.AUTHENTICATION_SERVICE_URL}')
if [[ "$AUTH_URL" == "http://auth-service:80" ]]; then
    print_status "Agent Bot auth URL correctly set: $AUTH_URL"
else
    print_warning "Agent Bot auth URL may be incorrect: $AUTH_URL"
fi

echo ""
echo "Step 5: Restarting affected deployments..."
echo "-------------------------------------------"

# Restart deployments to pick up new environment variables
kubectl rollout restart deployment api-gateway-deployment
print_status "Restarted api-gateway-deployment"

kubectl rollout restart deployment admin-deployment
print_status "Restarted admin-deployment"

kubectl rollout restart deployment auth-deployment
print_status "Restarted auth-deployment"

kubectl rollout restart deployment agent-bot-deployment
print_status "Restarted agent-bot-deployment"

echo ""
echo "Step 6: Waiting for rollouts to complete..."
echo "--------------------------------------------"

# Wait for rollouts with timeout
TIMEOUT=300  # 5 minutes

if kubectl rollout status deployment/api-gateway-deployment --timeout=${TIMEOUT}s; then
    print_status "api-gateway-deployment ready"
else
    print_error "api-gateway-deployment rollout timed out"
fi

if kubectl rollout status deployment/admin-deployment --timeout=${TIMEOUT}s; then
    print_status "admin-deployment ready"
else
    print_error "admin-deployment rollout timed out"
fi

if kubectl rollout status deployment/auth-deployment --timeout=${TIMEOUT}s; then
    print_status "auth-deployment ready"
else
    print_error "auth-deployment rollout timed out"
fi

if kubectl rollout status deployment/agent-bot-deployment --timeout=${TIMEOUT}s; then
    print_status "agent-bot-deployment ready"
else
    print_error "agent-bot-deployment rollout timed out"
fi

echo ""
echo "Step 7: Verifying pod status..."
echo "--------------------------------"

# Show pod status
kubectl get pods | grep -E "(api-gateway|admin|auth|agent-bot)" || true

echo ""
echo "Step 8: Running connectivity tests..."
echo "--------------------------------------"

# Get a running pod to test from
TEST_POD=$(kubectl get pods -l app=api-gateway -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)

if [ -n "$TEST_POD" ]; then
    print_status "Testing from pod: $TEST_POD"
    
    # Test auth service connectivity
    if kubectl exec -it "$TEST_POD" -- curl -s -o /dev/null -w "%{http_code}" http://auth-service:80/health 2>/dev/null | grep -q "200\|404"; then
        print_status "Auth service reachable at http://auth-service:80"
    else
        print_warning "Auth service may not be responding"
    fi
    
    # Test vehicle service connectivity
    if kubectl exec -it "$TEST_POD" -- curl -s -o /dev/null -w "%{http_code}" http://vehicle-service:80/health 2>/dev/null | grep -q "200\|404"; then
        print_status "Vehicle service reachable at http://vehicle-service:80"
    else
        print_warning "Vehicle service may not be responding"
    fi
    
    # Test notification service connectivity
    if kubectl exec -it "$TEST_POD" -- curl -s -o /dev/null -w "%{http_code}" http://notification-service:80/health 2>/dev/null | grep -q "200\|404"; then
        print_status "Notification service reachable at http://notification-service:80"
    else
        print_warning "Notification service may not be responding"
    fi
else
    print_warning "No gateway pod found for connectivity testing"
fi

echo ""
echo "Step 9: Checking for errors in logs..."
echo "---------------------------------------"

# Check recent logs for connection errors
print_status "Checking gateway logs..."
kubectl logs deployment/api-gateway-deployment --tail=20 --since=2m 2>/dev/null | grep -i "error\|fail\|refused" || print_status "No connection errors in gateway logs"

print_status "Checking auth logs..."
kubectl logs deployment/auth-deployment --tail=20 --since=2m 2>/dev/null | grep -i "error\|fail\|refused" || print_status "No connection errors in auth logs"

print_status "Checking agent bot logs..."
kubectl logs deployment/agent-bot-deployment --tail=20 --since=2m 2>/dev/null | grep -i "error\|fail\|refused" || print_status "No connection errors in agent bot logs"

echo ""
echo "================================================"
echo "✅ Service Discovery Fix Deployment Complete!"
echo "================================================"
echo ""
echo "📋 Summary of Changes:"
echo "  • Fixed API Gateway: Added explicit :80 port to all service URLs"
echo "  • Fixed Admin Service: Added explicit :80 port to auth service URL"
echo "  • Fixed Auth Service: Simplified gRPC target from FQDN to service name"
echo "  • Fixed Agent Bot: Changed from gateway routing to direct service calls"
echo ""
echo "🔍 Next Steps:"
echo "  1. Monitor logs: kubectl logs -f deployment/<service-name>"
echo "  2. Test critical workflows (registration, appointments, etc.)"
echo "  3. Check application functionality from browser"
echo "  4. Run full integration tests"
echo ""
echo "📖 For detailed information, see: SERVICE_DISCOVERY_FIX.md"
echo ""
echo "💾 Rollback instructions:"
echo "  If issues occur, restore from: $BACKUP_DIR/"
echo "  kubectl apply -f $BACKUP_DIR/<file>.yaml"
echo ""
