#!/bin/bash
# Verify migration status across all 11 services

WORKSPACE="/home/randitha/Desktop/IT/UoM/TechTorque-2025"
SERVICES=(
  "Admin_Service"
  "Agent_Bot"
  "API_Gateway"
  "Appointment_Service"
  "Authentication"
  "Frontend_Web"
  "Notification_Service"
  "Payment_Service"
  "Project_Service"
  "Time_Logging_Service"
  "Vehicle_Service"
)

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🔍 GitOps Migration Verification"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

TOTAL=0
READY=0

for service in "${SERVICES[@]}"; do
  SERVICE_DIR="$WORKSPACE/$service"
  
  if [ ! -d "$SERVICE_DIR" ]; then
    echo "⚠️  $service (directory not found)"
    continue
  fi
  
  cd "$SERVICE_DIR" > /dev/null
  TOTAL=$((TOTAL + 1))
  
  # Check if build.yaml exists
  if [ -f ".github/workflows/build.yaml" ]; then
    # Check if it has branch-aware tagging
    if grep -q "type=raw,value={{branch}}-{{sha}}" .github/workflows/build.yaml || grep -q "steps.branch.outputs.name" .github/workflows/build.yaml; then
      # Check if update-manifest.yaml exists
      if [ -f ".github/workflows/update-manifest.yaml" ]; then
        # Check if old deploy.yaml is backed up
        if [ -f ".github/workflows/deploy.yaml.old" ] || [ ! -f ".github/workflows/deploy.yaml" ]; then
          echo "✅ $service"
          READY=$((READY + 1))
        else
          echo "⚠️  $service (old deploy.yaml still present)"
        fi
      else
        echo "⚠️  $service (update-manifest.yaml missing)"
      fi
    else
      echo "⚠️  $service (build.yaml not updated)"
    fi
  else
    echo "❌ $service (build.yaml missing)"
  fi
done

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📊 Migration Status: $READY/$TOTAL services ready"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [ $READY -eq $TOTAL ]; then
  echo "🎉 All services are ready for testing!"
  echo ""
  echo "Next step: Start with Time_Logging_Service pilot"
  echo "  1. Merge feat/gitops-workflow to dev"
  echo "  2. Watch GitHub Actions build"
  echo "  3. Verify ArgoCD deploys to dev namespace"
  exit 0
else
  echo "⚠️  Some services need review"
  exit 1
fi
