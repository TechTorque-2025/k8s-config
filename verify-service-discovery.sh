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

# Check gateway configmap
GATEWAY_AUTH_CFG=$(kubectl get configmap gateway-config -o jsonpath='{.data.AUTH_SERVICE_URL}' 2>/dev/null)
if [[ "$GATEWAY_AUTH_CFG" == "http://auth-service:80" ]]; then
    print_check 0 "Gateway Config AUTH_SERVICE_URL: $GATEWAY_AUTH_CFG"
else
    print_check 1 "Gateway Config AUTH_SERVICE_URL INCORRECT: $GATEWAY_AUTH_CFG (expected: http://auth-service:80)"
fi

GATEWAY_VEH_CFG=$(kubectl get configmap gateway-config -o jsonpath='{.data.VEHICLES_SERVICE_URL}' 2>/dev/null)
if [[ "$GATEWAY_VEH_CFG" == "http://vehicle-service:80" ]]; then
    print_check 0 "Gateway Config VEHICLES_SERVICE_URL: $GATEWAY_VEH_CFG"
else
    print_check 1 "Gateway Config VEHICLES_SERVICE_URL INCORRECT: $GATEWAY_VEH_CFG"
fi

GATEWAY_APPT_CFG=$(kubectl get configmap gateway-config -o jsonpath='{.data.APPOINTMENTS_SERVICE_URL}' 2>/dev/null)
if [[ "$GATEWAY_APPT_CFG" == "http://appointment-service:80" ]]; then
    print_check 0 "Gateway Config APPOINTMENTS_SERVICE_URL: $GATEWAY_APPT_CFG"
else
    print_check 1 "Gateway Config APPOINTMENTS_SERVICE_URL INCORRECT: $GATEWAY_APPT_CFG"
fi

GATEWAY_PROJ_CFG=$(kubectl get configmap gateway-config -o jsonpath='{.data.PROJECT_SERVICE_URL}' 2>/dev/null)
if [[ "$GATEWAY_PROJ_CFG" == "http://project-service:80" ]]; then
    print_check 0 "Gateway Config PROJECT_SERVICE_URL: $GATEWAY_PROJ_CFG"
else
    print_check 1 "Gateway Config PROJECT_SERVICE_URL INCORRECT: $GATEWAY_PROJ_CFG"
fi

GATEWAY_TIME_CFG=$(kubectl get configmap gateway-config -o jsonpath='{.data.TIME_LOGS_SERVICE_URL}' 2>/dev/null)
if [[ "$GATEWAY_TIME_CFG" == "http://time-logging-service:80" ]]; then
    print_check 0 "Gateway Config TIME_LOGS_SERVICE_URL: $GATEWAY_TIME_CFG"
else
    print_check 1 "Gateway Config TIME_LOGS_SERVICE_URL INCORRECT: $GATEWAY_TIME_CFG"
fi

GATEWAY_PAY_CFG=$(kubectl get configmap gateway-config -o jsonpath='{.data.PAYMENT_SERVICE_URL}' 2>/dev/null)
if [[ "$GATEWAY_PAY_CFG" == "http://payment-service:80" ]]; then
    print_check 0 "Gateway Config PAYMENT_SERVICE_URL: $GATEWAY_PAY_CFG"
else
    print_check 1 "Gateway Config PAYMENT_SERVICE_URL INCORRECT: $GATEWAY_PAY_CFG"
fi

GATEWAY_ADMIN_CFG=$(kubectl get configmap gateway-config -o jsonpath='{.data.ADMIN_SERVICE_URL}' 2>/dev/null)
if [[ "$GATEWAY_ADMIN_CFG" == "http://admin-service:80" ]]; then
    print_check 0 "Gateway Config ADMIN_SERVICE_URL: $GATEWAY_ADMIN_CFG"
else
    print_check 1 "Gateway Config ADMIN_SERVICE_URL INCORRECT: $GATEWAY_ADMIN_CFG"
fi

GATEWAY_NOTIF_CFG=$(kubectl get configmap gateway-config -o jsonpath='{.data.NOTIFICATIONS_SERVICE_URL}' 2>/dev/null)
if [[ "$GATEWAY_NOTIF_CFG" == "http://notification-service:80" ]]; then
    print_check 0 "Gateway Config NOTIFICATIONS_SERVICE_URL: $GATEWAY_NOTIF_CFG"
else
    print_check 1 "Gateway Config NOTIFICATIONS_SERVICE_URL INCORRECT: $GATEWAY_NOTIF_CFG"
fi

GATEWAY_AGENT_CFG=$(kubectl get configmap gateway-config -o jsonpath='{.data.AGENT_BOT_SERVICE_URL}' 2>/dev/null)
if [[ "$GATEWAY_AGENT_CFG" == "http://agent-bot-service:80" ]]; then
    print_check 0 "Gateway Config AGENT_BOT_SERVICE_URL: $GATEWAY_AGENT_CFG"
else
    print_check 1 "Gateway Config AGENT_BOT_SERVICE_URL INCORRECT: $GATEWAY_AGENT_CFG"
fi

# Check vehicle configmap for PROJECT_SERVICE_URL
VEHICLE_PROJECT_CFG=$(kubectl get configmap vehicle-config -o jsonpath='{.data.PROJECT_SERVICE_URL}' 2>/dev/null)
if [[ "$VEHICLE_PROJECT_CFG" == "http://project-service:80" ]]; then
    print_check 0 "Vehicle PROJECT_SERVICE_URL (config): $VEHICLE_PROJECT_CFG"
else
    print_check 1 "Vehicle PROJECT_SERVICE_URL INCORRECT (config): $VEHICLE_PROJECT_CFG"
fi

# Check appointment configmap for inter-service URLs
APPT_ADMIN_URL=$(kubectl get configmap appointment-config -o jsonpath='{.data.ADMIN_SERVICE_URL}' 2>/dev/null)
if [[ "$APPT_ADMIN_URL" == "http://admin-service:80" ]]; then
    print_check 0 "Appointment ADMIN_SERVICE_URL: $APPT_ADMIN_URL"
else
    print_check 1 "Appointment ADMIN_SERVICE_URL INCORRECT: $APPT_ADMIN_URL (expected: http://admin-service:80)"
fi

APPT_NOTIF_URL=$(kubectl get configmap appointment-config -o jsonpath='{.data.NOTIFICATION_SERVICE_URL}' 2>/dev/null)
if [[ "$APPT_NOTIF_URL" == "http://notification-service:80" ]]; then
    print_check 0 "Appointment NOTIFICATION_SERVICE_URL: $APPT_NOTIF_URL"
else
    print_check 1 "Appointment NOTIFICATION_SERVICE_URL INCORRECT: $APPT_NOTIF_URL (expected: http://notification-service:80)"
fi

APPT_TIME_URL=$(kubectl get configmap appointment-config -o jsonpath='{.data.TIME_LOGGING_SERVICE_URL}' 2>/dev/null)
if [[ "$APPT_TIME_URL" == "http://time-logging-service:80" ]]; then
    print_check 0 "Appointment TIME_LOGGING_SERVICE_URL: $APPT_TIME_URL"
else
    print_check 1 "Appointment TIME_LOGGING_SERVICE_URL INCORRECT: $APPT_TIME_URL (expected: http://time-logging-service:80)"
fi

# Check project configmap for appointment & notification
PROJ_APPT_URL=$(kubectl get configmap project-config -o jsonpath='{.data.APPOINTMENT_SERVICE_URL}' 2>/dev/null)
if [[ "$PROJ_APPT_URL" == "http://appointment-service:80" ]]; then
    print_check 0 "Project APPOINTMENT_SERVICE_URL: $PROJ_APPT_URL"
else
    print_check 1 "Project APPOINTMENT_SERVICE_URL INCORRECT: $PROJ_APPT_URL (expected: http://appointment-service:80)"
fi

PROJ_NOTIF_URL=$(kubectl get configmap project-config -o jsonpath='{.data.NOTIFICATION_SERVICE_URL}' 2>/dev/null)
if [[ "$PROJ_NOTIF_URL" == "http://notification-service:80" ]]; then
    print_check 0 "Project NOTIFICATION_SERVICE_URL: $PROJ_NOTIF_URL"
else
    print_check 1 "Project NOTIFICATION_SERVICE_URL INCORRECT: $PROJ_NOTIF_URL (expected: http://notification-service:80)"
fi

# Check admin configmap for inter-service urls
ADMIN_AUTH_CFG=$(kubectl get configmap admin-config -o jsonpath='{.data.AUTH_SERVICE_URL}' 2>/dev/null)
if [[ "$ADMIN_AUTH_CFG" == "http://auth-service:80" ]]; then
    print_check 0 "Admin Config AUTH_SERVICE_URL: $ADMIN_AUTH_CFG"
else
    print_check 1 "Admin Config AUTH_SERVICE_URL INCORRECT: $ADMIN_AUTH_CFG"
fi

ADMIN_VEH_CFG=$(kubectl get configmap admin-config -o jsonpath='{.data.VEHICLE_SERVICE_URL}' 2>/dev/null)
if [[ "$ADMIN_VEH_CFG" == "http://vehicle-service:80" ]]; then
    print_check 0 "Admin Config VEHICLE_SERVICE_URL: $ADMIN_VEH_CFG"
else
    print_check 1 "Admin Config VEHICLE_SERVICE_URL INCORRECT: $ADMIN_VEH_CFG"
fi

ADMIN_APPT_CFG=$(kubectl get configmap admin-config -o jsonpath='{.data.APPOINTMENT_SERVICE_URL}' 2>/dev/null)
if [[ "$ADMIN_APPT_CFG" == "http://appointment-service:80" ]]; then
    print_check 0 "Admin Config APPOINTMENT_SERVICE_URL: $ADMIN_APPT_CFG"
else
    print_check 1 "Admin Config APPOINTMENT_SERVICE_URL INCORRECT: $ADMIN_APPT_CFG"
fi

ADMIN_PROJ_CFG=$(kubectl get configmap admin-config -o jsonpath='{.data.PROJECT_SERVICE_URL}' 2>/dev/null)
if [[ "$ADMIN_PROJ_CFG" == "http://project-service:80" ]]; then
    print_check 0 "Admin Config PROJECT_SERVICE_URL: $ADMIN_PROJ_CFG"
else
    print_check 1 "Admin Config PROJECT_SERVICE_URL INCORRECT: $ADMIN_PROJ_CFG"
fi

ADMIN_TIME_CFG=$(kubectl get configmap admin-config -o jsonpath='{.data.TIME_LOGGING_SERVICE_URL}' 2>/dev/null)
if [[ "$ADMIN_TIME_CFG" == "http://time-logging-service:80" ]]; then
    print_check 0 "Admin Config TIME_LOGGING_SERVICE_URL: $ADMIN_TIME_CFG"
else
    print_check 1 "Admin Config TIME_LOGGING_SERVICE_URL INCORRECT: $ADMIN_TIME_CFG"
fi

ADMIN_PAYMENT_CFG=$(kubectl get configmap admin-config -o jsonpath='{.data.PAYMENT_SERVICE_URL}' 2>/dev/null)
if [[ "$ADMIN_PAYMENT_CFG" == "http://payment-service:80" ]]; then
    print_check 0 "Admin Config PAYMENT_SERVICE_URL: $ADMIN_PAYMENT_CFG"
else
    print_check 1 "Admin Config PAYMENT_SERVICE_URL INCORRECT: $ADMIN_PAYMENT_CFG"
fi

ADMIN_NOTIF_CFG=$(kubectl get configmap admin-config -o jsonpath='{.data.NOTIFICATION_SERVICE_URL}' 2>/dev/null)
if [[ "$ADMIN_NOTIF_CFG" == "http://notification-service:80" ]]; then
    print_check 0 "Admin Config NOTIFICATION_SERVICE_URL: $ADMIN_NOTIF_CFG"
else
    print_check 1 "Admin Config NOTIFICATION_SERVICE_URL INCORRECT: $ADMIN_NOTIF_CFG"
fi

# Check payment configmap for notification URL
PAY_CFG_NOTIF=$(kubectl get configmap payment-config -o jsonpath='{.data.NOTIFICATION_SERVICE_URL}' 2>/dev/null)
if [[ "$PAY_CFG_NOTIF" == "http://notification-service:80" ]]; then
    print_check 0 "Payment NOTIFICATION_SERVICE_URL (config): $PAY_CFG_NOTIF"
else
    print_check 1 "Payment NOTIFICATION_SERVICE_URL INCORRECT (config): $PAY_CFG_NOTIF"
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
    GATEWAY_ADMIN_URL=$(kubectl exec "$GATEWAY_POD" -- env | grep "ADMIN_SERVICE_URL=" | cut -d'=' -f2 2>/dev/null || echo "")
    if [[ "$GATEWAY_ADMIN_URL" == "http://admin-service:80" ]]; then
        print_check 0 "Gateway ADMIN_SERVICE_URL: $GATEWAY_ADMIN_URL"
    else
        print_check 1 "Gateway ADMIN_SERVICE_URL INCORRECT: $GATEWAY_ADMIN_URL"
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
    ADMIN_VEHICLE_URL=$(kubectl exec "$ADMIN_POD" -- env | grep "VEHICLE_SERVICE_URL=" | cut -d'=' -f2 2>/dev/null || echo "")
    if [[ "$ADMIN_VEHICLE_URL" == "http://vehicle-service:80" ]]; then
        print_check 0 "Admin VEHICLE_SERVICE_URL: $ADMIN_VEHICLE_URL"
    else
        print_check 1 "Admin VEHICLE_SERVICE_URL INCORRECT: $ADMIN_VEHICLE_URL"
    fi

    ADMIN_APPT_URL=$(kubectl exec "$ADMIN_POD" -- env | grep "APPOINTMENT_SERVICE_URL=" | cut -d'=' -f2 2>/dev/null || echo "")
    if [[ "$ADMIN_APPT_URL" == "http://appointment-service:80" ]]; then
        print_check 0 "Admin APPOINTMENT_SERVICE_URL: $ADMIN_APPT_URL"
    else
        print_check 1 "Admin APPOINTMENT_SERVICE_URL INCORRECT: $ADMIN_APPT_URL"
    fi

    ADMIN_PROJECT_URL=$(kubectl exec "$ADMIN_POD" -- env | grep "PROJECT_SERVICE_URL=" | cut -d'=' -f2 2>/dev/null || echo "")
    if [[ "$ADMIN_PROJECT_URL" == "http://project-service:80" ]]; then
        print_check 0 "Admin PROJECT_SERVICE_URL: $ADMIN_PROJECT_URL"
    else
        print_check 1 "Admin PROJECT_SERVICE_URL INCORRECT: $ADMIN_PROJECT_URL"
    fi

    ADMIN_TIMES_URL=$(kubectl exec "$ADMIN_POD" -- env | grep "TIME_LOGGING_SERVICE_URL=" | cut -d'=' -f2 2>/dev/null || echo "")
    if [[ "$ADMIN_TIMES_URL" == "http://time-logging-service:80" ]]; then
        print_check 0 "Admin TIME_LOGGING_SERVICE_URL: $ADMIN_TIMES_URL"
    else
        print_check 1 "Admin TIME_LOGGING_SERVICE_URL INCORRECT: $ADMIN_TIMES_URL"
    fi

    ADMIN_PAYMENT_URL=$(kubectl exec "$ADMIN_POD" -- env | grep "PAYMENT_SERVICE_URL=" | cut -d'=' -f2 2>/dev/null || echo "")
    if [[ "$ADMIN_PAYMENT_URL" == "http://payment-service:80" ]]; then
        print_check 0 "Admin PAYMENT_SERVICE_URL: $ADMIN_PAYMENT_URL"
    else
        print_check 1 "Admin PAYMENT_SERVICE_URL INCORRECT: $ADMIN_PAYMENT_URL"
    fi

    ADMIN_NOTIF_URL=$(kubectl exec "$ADMIN_POD" -- env | grep "NOTIFICATION_SERVICE_URL=" | cut -d'=' -f2 2>/dev/null || echo "")
    if [[ "$ADMIN_NOTIF_URL" == "http://notification-service:80" ]]; then
        print_check 0 "Admin NOTIFICATION_SERVICE_URL: $ADMIN_NOTIF_URL"
    else
        print_check 1 "Admin NOTIFICATION_SERVICE_URL INCORRECT: $ADMIN_NOTIF_URL"
    fi
else
    print_check 1 "No admin pod found"
fi

# Check appointment deployment env variables
APPT_POD=$(kubectl get pods -l app=appointment-service -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
if [ -n "$APPT_POD" ]; then
    APPT_ADMIN_ENV=$(kubectl exec "$APPT_POD" -- env | grep "ADMIN_SERVICE_URL=" | cut -d'=' -f2 2>/dev/null || echo "")
    if [[ "$APPT_ADMIN_ENV" == "http://admin-service:80" ]]; then
        print_check 0 "Appointment ADMIN_SERVICE_URL: $APPT_ADMIN_ENV"
    else
        print_check 1 "Appointment ADMIN_SERVICE_URL INCORRECT: $APPT_ADMIN_ENV"
    fi

    APPT_NOTIF_ENV=$(kubectl exec "$APPT_POD" -- env | grep "NOTIFICATION_SERVICE_URL=" | cut -d'=' -f2 2>/dev/null || echo "")
    if [[ "$APPT_NOTIF_ENV" == "http://notification-service:80" ]]; then
        print_check 0 "Appointment NOTIFICATION_SERVICE_URL: $APPT_NOTIF_ENV"
    else
        print_check 1 "Appointment NOTIFICATION_SERVICE_URL INCORRECT: $APPT_NOTIF_ENV"
    fi

    APPT_TIME_ENV=$(kubectl exec "$APPT_POD" -- env | grep "TIME_LOGGING_SERVICE_URL=" | cut -d'=' -f2 2>/dev/null || echo "")
    if [[ "$APPT_TIME_ENV" == "http://time-logging-service:80" ]]; then
        print_check 0 "Appointment TIME_LOGGING_SERVICE_URL: $APPT_TIME_ENV"
    else
        print_check 1 "Appointment TIME_LOGGING_SERVICE_URL INCORRECT: $APPT_TIME_ENV"
    fi
else
    print_check 1 "No appointment pod found"
fi

# Check project deployment env variables for APPOINTMENT/NOTIFICATION
PROJECT_POD=$(kubectl get pods -l app=project-service -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
if [ -n "$PROJECT_POD" ]; then
    PROJ_APPT=$(kubectl exec "$PROJECT_POD" -- env | grep "APPOINTMENT_SERVICE_URL=" | cut -d'=' -f2 2>/dev/null || echo "")
    if [[ "$PROJ_APPT" == "http://appointment-service:80" ]]; then
        print_check 0 "Project APPOINTMENT_SERVICE_URL: $PROJ_APPT"
    else
        print_check 1 "Project APPOINTMENT_SERVICE_URL INCORRECT: $PROJ_APPT"
    fi

    PROJ_NOTIF=$(kubectl exec "$PROJECT_POD" -- env | grep "NOTIFICATION_SERVICE_URL=" | cut -d'=' -f2 2>/dev/null || echo "")
    if [[ "$PROJ_NOTIF" == "http://notification-service:80" ]]; then
        print_check 0 "Project NOTIFICATION_SERVICE_URL: $PROJ_NOTIF"
    else
        print_check 1 "Project NOTIFICATION_SERVICE_URL INCORRECT: $PROJ_NOTIF"
    fi
else
    print_check 1 "No project pod found"
fi

# Check payment deployment env variable for notifications
PAYMENT_POD=$(kubectl get pods -l app=payment-service -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
if [ -n "$PAYMENT_POD" ]; then
    PAY_NOTIF=$(kubectl exec "$PAYMENT_POD" -- env | grep "NOTIFICATION_SERVICE_URL=" | cut -d'=' -f2 2>/dev/null || echo "")
    if [[ "$PAY_NOTIF" == "http://notification-service:80" ]]; then
        print_check 0 "Payment NOTIFICATION_SERVICE_URL: $PAY_NOTIF"
    else
        print_check 1 "Payment NOTIFICATION_SERVICE_URL INCORRECT: $PAY_NOTIF"
    fi
else
    print_check 1 "No payment pod found"
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
