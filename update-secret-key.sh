#!/usr/bin/env bash
# update-secret-key.sh
# Small helper to add or replace a key inside an existing kubernetes secret
# Usage: update-secret-key.sh -n <namespace> -s <secret-name> -k <key> -v <value>

set -euo pipefail

NAMESPACE=default
SECRET_NAME=""
KEY=""
VALUE=""
SUDO=""
DRY_RUN=false

usage() {
  cat <<EOF
Usage: $0 -n <namespace> -s <secret> -k <key> -v <value> [--sudo] [--dry-run]

Add or replace a key inside a Kubernetes secret via a JSON patch.
If the secret does not exist, a new secret will be created with the given key.

Options:
  -n|--namespace   Kubernetes namespace (default: default)
  -s|--secret      Secret name (required)
  -k|--key         Secret key to add/replace (required)
  -v|--value       Plaintext value for the key (required)
  --sudo           If set, run kubectl with sudo (useful for k3s node with kubeconfig perms)
  --dry-run        Do not run kubectl; print the patch command

Examples:
  # Add DB_PASS to notification secret in dev
  ./update-secret-key.sh -n dev -s notification-secrets -k DB_PASS -v 'techtorque123' --sudo

  # Add EMAIL_PASSWORD
  ./update-secret-key.sh -n dev -s notification-secrets -k EMAIL_PASSWORD -v 'app-password' --sudo
EOF
}

# parse args
while [[ $# -gt 0 ]]; do
  case "$1" in
    -n|--namespace)
      NAMESPACE="$2"
      shift 2
      ;;
    -s|--secret)
      SECRET_NAME="$2"
      shift 2
      ;;
    -k|--key)
      KEY="$2"
      shift 2
      ;;
    -v|--value)
      VALUE="$2"
      shift 2
      ;;
    --sudo)
      SUDO="sudo"
      shift
      ;;
    --dry-run)
      DRY_RUN=true
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1"
      usage
      exit 1
      ;;
  esac
done

if [[ -z "$SECRET_NAME" || -z "$KEY" || -z "$VALUE" ]]; then
  echo "Missing required arguments."
  usage
  exit 2
fi

# base64 encode value (no newline)
VALUE_B64=$(echo -n "$VALUE" | base64 | tr -d '\n')

# Determine op: add or replace
if $DRY_RUN; then
  echo "DRY RUN: will patch secret $SECRET_NAME in $NAMESPACE with key $KEY"
fi

if ${SUDO} kubectl get secret "$SECRET_NAME" -n "$NAMESPACE" >/dev/null 2>&1; then
  if ${SUDO} kubectl get secret "$SECRET_NAME" -n "$NAMESPACE" -o jsonpath="{.data.$KEY}" >/dev/null 2>&1; then
    OP=replace
  else
    OP=add
  fi
  JSON_PATCH="[{\"op\":\"${OP}\",\"path\":\"/data/${KEY}\",\"value\":\"${VALUE_B64}\"}]"
  if $DRY_RUN; then
    echo "${SUDO} kubectl patch secret ${SECRET_NAME} -n ${NAMESPACE} --type=json -p='${JSON_PATCH}'"
  else
    echo "Patching ${SECRET_NAME} in ${NAMESPACE} -> ${OP} ${KEY}"
    ${SUDO} kubectl patch secret ${SECRET_NAME} -n ${NAMESPACE} --type=json -p="${JSON_PATCH}"
  fi
else
  # create new secret
  if $DRY_RUN; then
    echo "${SUDO} kubectl create secret generic ${SECRET_NAME} --from-literal=${KEY}='${VALUE}' -n ${NAMESPACE} --dry-run=client -o yaml | kubectl apply -f -"
  else
    echo "Creating secret ${SECRET_NAME} in ${NAMESPACE} with ${KEY}"
    ${SUDO} kubectl create secret generic ${SECRET_NAME} --from-literal=${KEY}="${VALUE}" -n ${NAMESPACE} --dry-run=client -o yaml | ${SUDO} kubectl apply -f -
  fi
fi

EOF