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

# Default namespace is 'default' but you can pass a namespace with -n or --namespace
NAMESPACE="default"

usage() {
  echo "Usage: $0 [-n|--namespace <namespace>]"
  echo "  -n, --namespace    Kubernetes namespace to create secrets in (default: default)"
    echo "  --db-pass <pass>   Use this DB password for all services (non-interactive)"
    echo "  --notification-email-username <username>"
    echo "                     Set notification email username (non-interactive)"
    echo "  --notification-email-password <password>"
    echo "                     Set notification email password (non-interactive)"
  exit 1
}

while [[ "$#" -gt 0 ]]; do
  case "$1" in
    -n|--namespace)
      NAMESPACE="$2"
      shift 2
        ;;
      --db-pass)
        DEFAULT_DB_PASS="$2"
        shift 2
        ;;
      --notification-email-username)
        NOTIF_EMAIL_USER="$2"
        shift 2
        ;;
      --notification-email-password)
        NOTIF_EMAIL_PASS="$2"
        shift 2
      ;;
    -h|--help)
      usage
      ;;
    *)
      echo "Unknown option: $1"
      usage
      ;;
  esac
done

# Service list
SERVICES=(
  "admin:admin-secrets"
  "appointment:appointment-secrets"
  "payment:payment-secrets"
  "project:project-secrets"
  "timelogging:timelogging-secrets"
  "notification:notification-secrets"
  "vehicle:vehicle-secrets"
  "agent-bot:agent-bot-secrets"
)

echo ""
echo "Creating secrets..."
echo ""

for service in "${SERVICES[@]}"; do
  IFS=':' read -r SERVICE_NAME SECRET_NAME <<< "$service"
  
  echo "---"
  echo "Service: ${SERVICE_NAME}"
  
  # Special handling for agent-bot service
  if [ "${SERVICE_NAME}" == "agent-bot" ]; then
    read -sp "Enter Google API Key (Gemini) for ${SERVICE_NAME}: " GOOGLE_API_KEY
    echo ""
    read -sp "Enter Pinecone API Key for ${SERVICE_NAME}: " PINECONE_API_KEY
    echo ""
    
    kubectl create secret generic ${SECRET_NAME} \
      --from-literal=GOOGLE_API_KEY="${GOOGLE_API_KEY}" \
      --from-literal=PINECONE_API_KEY="${PINECONE_API_KEY}" \
      --namespace=${NAMESPACE} \
      --dry-run=client -o yaml | kubectl apply -f -
  elif [ "${SERVICE_NAME}" == "notification" ]; then
    # Notification service may have additional email creds. Ask for them optionally.
    read -sp "Enter DB password for ${SERVICE_NAME}: " DB_PASS
    if [ -n "${DEFAULT_DB_PASS}" ]; then
      DB_PASS="${DEFAULT_DB_PASS}"
    else
      read -sp "Enter DB password for ${SERVICE_NAME}: " DB_PASS
    fi
    if [ -n "${DEFAULT_DB_PASS}" ]; then
      DB_PASS="${DEFAULT_DB_PASS}"
    else
      read -sp "Enter DB password for ${SERVICE_NAME}: " DB_PASS
    fi
    echo ""
    read -p "Do you want to add email credentials for notification? (y/N): " ADD_EMAIL
    # email creds: if provided via flags, use them; otherwise, optionally prompt
    if [ -n "${NOTIF_EMAIL_USER}" ]; then
      EMAIL_USERNAME="${NOTIF_EMAIL_USER}"
    fi
    if [ -n "${NOTIF_EMAIL_PASS}" ]; then
      EMAIL_PASSWORD="${NOTIF_EMAIL_PASS}"
    fi
    if [ -z "${EMAIL_USERNAME}" ] || [ -z "${EMAIL_PASSWORD}" ]; then
      read -p "Do you want to add email credentials for notification? (y/N): " ADD_EMAIL
      if [[ "$ADD_EMAIL" =~ ^[Yy]$ ]]; then
        read -p "Enter Email username: " EMAIL_USERNAME
        read -sp "Enter Email password: " EMAIL_PASSWORD
        echo ""
      fi
    fi

    # If a secret already exists in the target namespace, patch (add/replace) keys without removing existing keys
    if kubectl get secret ${SECRET_NAME} -n ${NAMESPACE} >/dev/null 2>&1; then
      echo "Secret '${SECRET_NAME}' exists in namespace '${NAMESPACE}' — updating keys"
      ENC_DB_PASS=$(echo -n "${DB_PASS}" | base64 | tr -d '\n')
      # add or replace DB_PASS
      if kubectl get secret ${SECRET_NAME} -n ${NAMESPACE} -o jsonpath="{.data.DB_PASS}" >/dev/null 2>&1; then
        OP=replace
      else
        OP=add
      fi
      PATCH="[{\"op\":\"${OP}\",\"path\":\"/data/DB_PASS\",\"value\":\"${ENC_DB_PASS}\"}]"
      kubectl patch secret ${SECRET_NAME} -n ${NAMESPACE} --type=json -p="${PATCH}"

      # Email keys if provided
      if [[ "$ADD_EMAIL" =~ ^[Yy]$ ]]; then
        ENC_EMAIL_USER=$(echo -n "${EMAIL_USERNAME}" | base64 | tr -d '\n')
        ENC_EMAIL_PASS=$(echo -n "${EMAIL_PASSWORD}" | base64 | tr -d '\n')
        PATCH_EMAIL_USER="[{\"op\":\"add\",\"path\":\"/data/EMAIL_USERNAME\",\"value\":\"${ENC_EMAIL_USER}\"}]"
        PATCH_EMAIL_PASS="[{\"op\":\"add\",\"path\":\"/data/EMAIL_PASSWORD\",\"value\":\"${ENC_EMAIL_PASS}\"}]"
        kubectl patch secret ${SECRET_NAME} -n ${NAMESPACE} --type=json -p="${PATCH_EMAIL_USER}" || kubectl patch secret ${SECRET_NAME} -n ${NAMESPACE} --type=json -p="${PATCH_EMAIL_USER/\"add\"/\"replace\"}"
        kubectl patch secret ${SECRET_NAME} -n ${NAMESPACE} --type=json -p="${PATCH_EMAIL_PASS}" || kubectl patch secret ${SECRET_NAME} -n ${NAMESPACE} --type=json -p="${PATCH_EMAIL_PASS/\"add\"/\"replace\"}"
      fi
    else
      # create new secret with DB_PASS and optionally email creds
      CMD=(kubectl create secret generic ${SECRET_NAME} --from-literal=DB_PASS="${DB_PASS}")
      if [[ "$ADD_EMAIL" =~ ^[Yy]$ ]]; then
        CMD+=(--from-literal=EMAIL_USERNAME="${EMAIL_USERNAME}" --from-literal=EMAIL_PASSWORD="${EMAIL_PASSWORD}")
      fi
      CMD+=(--namespace=${NAMESPACE} --dry-run=client -o yaml)
      "${CMD[@]}" | kubectl apply -f -
    fi
  else
    read -sp "Enter DB password for ${SERVICE_NAME}: " DB_PASS
    echo ""
    
    if kubectl get secret ${SECRET_NAME} -n ${NAMESPACE} >/dev/null 2>&1; then
      echo "Secret '${SECRET_NAME}' exists in namespace '${NAMESPACE}' — only adding/updating DB_PASS"
      ENC_VAL=$(echo -n "${DB_PASS}" | base64 | tr -d '\n')
      if kubectl get secret ${SECRET_NAME} -n ${NAMESPACE} -o jsonpath="{.data.DB_PASS}" >/dev/null 2>&1; then
        OP=replace
      else
        OP=add
      fi
      JSON_PATCH="[{\"op\":\"${OP}\",\"path\":\"/data/DB_PASS\",\"value\":\"${ENC_VAL}\"}]"
      kubectl patch secret ${SECRET_NAME} -n ${NAMESPACE} --type=json -p="${JSON_PATCH}"
    else
      kubectl create secret generic ${SECRET_NAME} \
        --from-literal=DB_PASS="${DB_PASS}" \
        --namespace=${NAMESPACE} \
        --dry-run=client -o yaml | kubectl apply -f -
    fi
  fi
  
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
kubectl get secrets -n ${NAMESPACE} | grep -E "admin-secrets|appointment-secrets|payment-secrets|project-secrets|timelogging-secrets|notification-secrets|vehicle-secrets|auth-secrets|agent-bot-secrets"

echo ""
echo "All secrets created! You can now deploy the services."
