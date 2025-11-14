#!/bin/bash
# Batch migration script for all 11 microservices to GitOps workflow
# Reads templates from argocd/examples/ and applies service-specific replacements
# Creates feature branches and updates workflows

set -e

WORKSPACE="/home/randitha/Desktop/IT/UoM/TechTorque-2025"
K8S_CONFIG_DIR="$WORKSPACE/k8s-config"
TEMPLATES_DIR="$K8S_CONFIG_DIR/argocd/examples"
SERVICES=(
  "Admin_Service|admin_service|admin-deployment.yaml|admin-service"
  "Agent_Bot|agent_bot|agent-bot-deployment.yaml|"
  "API_Gateway|api_gateway|gateway-deployment.yaml|gateway"
  "Appointment_Service|appointment_service|appointment-deployment.yaml|appointment-service"
  "Authentication|authentication|auth-deployment.yaml|auth-service"
  "Frontend_Web|frontend_web|frontend-deployment.yaml|"
  "Notification_Service|notification_service|notification-deployment.yaml|notification-service"
  "Payment_Service|payment_service|payment-deployment.yaml|payment-service"
  "Project_Service|project_service|project-deployment.yaml|project-service"
  "Time_Logging_Service|timelogging_service|timelogging-deployment.yaml|time-logging-service"
  "Vehicle_Service|vehicle_service|vehicle-deployment.yaml|vehicle-service"
)

echo "🚀 Starting batch migration of all 11 microservices..."
echo ""

for service_config in "${SERVICES[@]}"; do
  IFS='|' read -r REPO_NAME IMAGE_NAME DEPLOYMENT_FILE MODULE_NAME <<< "$service_config"
  
  SERVICE_DIR="$WORKSPACE/$REPO_NAME"
  
  if [ ! -d "$SERVICE_DIR" ]; then
    echo "⚠️  Skipping $REPO_NAME (directory not found)"
    continue
  fi
  
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "📦 Processing: $REPO_NAME"
  echo "   Image: $IMAGE_NAME"
  echo "   Deployment: $DEPLOYMENT_FILE"
  echo "   Module: ${MODULE_NAME:-N/A}"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  
  cd "$SERVICE_DIR"
  
  # Create or switch to feature branch
  BRANCH="feat/gitops-workflow"
  git checkout -b "$BRANCH" 2>/dev/null || git checkout "$BRANCH"
  git pull origin "$BRANCH" 2>/dev/null || true
  
  # Create .github/workflows directory if it doesn't exist
  mkdir -p .github/workflows
  
  # Copy and customize build.yaml
  echo "  → Creating build.yaml..."
  cp "$TEMPLATES_DIR/build-template.yaml" .github/workflows/build.yaml
  
  # Replace placeholders in build.yaml
  sed -i "s/SERVICE_IMAGE_NAME/$IMAGE_NAME/g" .github/workflows/build.yaml
  
  # For services with MODULE_NAME (Java services), replace it
  if [ -n "$MODULE_NAME" ]; then
    sed -i "s|SERVICE_MODULE|$MODULE_NAME|g" .github/workflows/build.yaml
  fi
  
  # For Frontend_Web: uncomment Node.js steps and comment Java steps
  if [ "$REPO_NAME" == "Frontend_Web" ]; then
    echo "  → Customizing build.yaml for Node.js (Frontend)..."
    # This is a bit complex, so we'll use a more targeted approach
    sed -i '/# For Java\/Spring Boot services:/,/# For Node.js\/Next.js services/{ /^[^#]/{ s/^/# /; } }' .github/workflows/build.yaml
    sed -i '/# For Node.js\/Next.js services:/,/# - name: Build/{s/^# \(.*\)/\1/;}' .github/workflows/build.yaml
  fi
  
  # For Agent_Bot (Python): comment out Java, customize for Python
  if [ "$REPO_NAME" == "Agent_Bot" ]; then
    echo "  → Customizing build.yaml for Python (Agent_Bot)..."
    sed -i '/# For Java\/Spring Boot services:/,/# For Node.js\/Next.js services/{ /^[^#]/{ s/^/# /; } }' .github/workflows/build.yaml
  fi
  
  # Copy and customize update-manifest.yaml
  echo "  → Creating update-manifest.yaml..."
  cp "$TEMPLATES_DIR/update-manifest-template.yaml" .github/workflows/update-manifest.yaml
  
  # Replace placeholders in update-manifest.yaml
  sed -i "s/REPLACE_WITH_SERVICE_NAME/$IMAGE_NAME/g" .github/workflows/update-manifest.yaml
  sed -i "s|REPLACE_WITH_DEPLOYMENT_FILE|$DEPLOYMENT_FILE|g" .github/workflows/update-manifest.yaml
  
  # For Frontend_Web: update workflow trigger name
  if [ "$REPO_NAME" == "Frontend_Web" ]; then
    sed -i 's/"Build and Package Service"/"Build, Test, and Package Frontend"/g' .github/workflows/update-manifest.yaml
  fi
  
  # Backup old deploy.yaml if it exists
  if [ -f .github/workflows/deploy.yaml ]; then
    echo "  → Backing up old deploy.yaml..."
    mv .github/workflows/deploy.yaml .github/workflows/deploy.yaml.old
  fi
  
  # Stage and commit
  git add .github/workflows/build.yaml .github/workflows/update-manifest.yaml
  if [ -f .github/workflows/deploy.yaml.old ]; then
    git add .github/workflows/deploy.yaml.old
  fi
  
  # Check if there are changes to commit
  if git diff --cached --quiet; then
    echo "  ✓ No changes needed (workflows already in place)"
  else
    git commit -m "chore: migrate to GitOps workflow with ArgoCD

- Update build.yaml with branch-aware image tagging (branch-sha format)
- Add update-manifest.yaml to update k8s-config manifests
- Backup old deploy.yaml (no longer needed with GitOps)

Refs:
- k8s-config/argocd/GITOPS_CI_CD_WORKFLOW.md
- k8s-config/argocd/SERVICE_MIGRATION_GUIDE.md"
    
    echo "  ✓ Committed workflow changes"
  fi
  
  # Push feature branch
  git push -u origin "$BRANCH" 2>&1 | grep -E "(remote:|branch|pushing)" || echo "  ✓ Branch pushed/updated"
  
  echo "  ✅ $REPO_NAME migration complete"
  echo ""
done

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🎉 All 11 services migrated to feat/gitops-workflow branch"
echo ""
echo "📝 Next steps:"
echo "  1. Review each service's PR on GitHub"
echo "  2. Start with Time_Logging_Service pilot (merge to dev first)"
echo "  3. Test dev deployment end-to-end"
echo "  4. Then merge remaining services to dev"
echo "  5. Finally merge to main for prod rollout"
echo ""
echo "📊 Quick status check:"
echo "  Run: cd <SERVICE_DIR> && git branch -vv"
echo "  All services should show: feat/gitops-workflow"
