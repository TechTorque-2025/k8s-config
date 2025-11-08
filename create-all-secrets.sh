#!/bin/bash
# create-all-secrets.sh
# Script to create all Kubernetes secrets for microservices

echo "================================================"
echo "  TechTorque Microservices - Secret Creation"
echo "================================================"
echo ""
echo "This script will create secrets for all microservices."
echo "You'll be prompted to enter passwords for each service."
echo ""
read -p "Press Enter to continue..."

# Service list
SERVICES=(
  "admin:admin-secrets"
  "appointment:appointment-secrets"
  "payment:payment-secrets"
  "project:project-secrets"
  "timelogging:timelogging-secrets"
  "notification:notification-secrets"
  "vehicle:vehicle-secrets"
)

echo ""
echo "Creating secrets..."
echo ""

for service in "${SERVICES[@]}"; do
  IFS=':' read -r SERVICE_NAME SECRET_NAME <<< "$service"
  
  echo "---"
  echo "Service: ${SERVICE_NAME}"
  read -sp "Enter DB password for ${SERVICE_NAME}: " DB_PASS
  echo ""
  
  kubectl create secret generic ${SECRET_NAME} \
    --from-literal=DB_PASS="${DB_PASS}" \
    --namespace=default \
    --dry-run=client -o yaml | kubectl apply -f -
  
  if [ $? -eq 0 ]; then
    echo "✓ Secret '${SECRET_NAME}' created successfully"
  else
    echo "✗ Failed to create secret '${SECRET_NAME}'"
  fi
  echo ""
done

echo ""
echo "================================================"
echo "  Verification"
echo "================================================"
echo ""
kubectl get secrets | grep -E "admin-secrets|appointment-secrets|payment-secrets|project-secrets|timelogging-secrets|notification-secrets|vehicle-secrets|auth-secrets"

echo ""
echo "All secrets created! You can now deploy the services."
