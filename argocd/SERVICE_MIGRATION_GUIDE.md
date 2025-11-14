# Service-Specific Configuration for Workflow Migration

## Service Details

| Service Name | Image Name | Deployment File | Module Path (Java) | Build Type |
|-------------|------------|-----------------|-------------------|------------|
| Admin_Service | admin_service | admin-deployment.yaml | admin-service | Java/Maven |
| Agent_Bot | agent_bot | agent-bot-deployment.yaml | Agent_Bot | Python |
| API_Gateway | api_gateway | gateway-deployment.yaml | gateway | Java/Maven |
| Appointment_Service | appointment_service | appointment-deployment.yaml | appointment-service | Java/Maven |
| Authentication | authentication | auth-deployment.yaml | auth-service | Java/Maven |
| Frontend_Web | frontend_web | frontend-deployment.yaml | N/A | Node.js/Next.js |
| Notification_Service | notification_service | notification-deployment.yaml | notification-service | Java/Maven |
| Payment_Service | payment_service | payment-deployment.yaml | payment-service | Java/Maven |
| Project_Service | project_service | project-deployment.yaml | project-service | Java/Maven |
| Time_Logging_Service | timelogging_service | timelogging-deployment.yaml | time-logging-service | Java/Maven |
| Vehicle_Service | vehicle_service | vehicle-deployment.yaml | vehicle-service | Java/Maven |

## Example Replacements for Time_Logging_Service

### In build.yaml:
```yaml
# Replace:
SERVICE_MODULE → time-logging-service
SERVICE_IMAGE_NAME → timelogging_service
```

### In update-manifest.yaml (new file, replaces deploy.yaml):
```yaml
# Replace:
REPLACE_WITH_SERVICE_NAME → timelogging_service
REPLACE_WITH_DEPLOYMENT_FILE → timelogging-deployment.yaml
```

## Example Replacements for Frontend_Web

### In build.yaml:
```yaml
# Replace:
SERVICE_IMAGE_NAME → frontend_web

# Also: comment out Java steps, uncomment Node.js steps
```

### In update-manifest.yaml:
```yaml
# Replace:
REPLACE_WITH_SERVICE_NAME → frontend_web
REPLACE_WITH_DEPLOYMENT_FILE → frontend-deployment.yaml

# Update workflow trigger to match Frontend's build workflow name:
workflows: ["Build, Test, and Package Frontend"]
```

## Example Replacements for Authentication

### In build.yaml:
```yaml
# Replace:
SERVICE_MODULE → auth-service
SERVICE_IMAGE_NAME → authentication
```

### In update-manifest.yaml:
```yaml
# Replace:
REPLACE_WITH_SERVICE_NAME → authentication
REPLACE_WITH_DEPLOYMENT_FILE → auth-deployment.yaml
```

## Quick Migration Steps (Per Service)

1. **In the microservice repo:**
   
   a. Copy `k8s-config/argocd/examples/build-template.yaml` to `.github/workflows/build.yaml`
   
   b. Replace SERVICE_MODULE and SERVICE_IMAGE_NAME with values from table above
   
   c. Commit to a feature branch first:
      ```bash
      git checkout -b feat/gitops-workflow
      cp /path/to/k8s-config/argocd/examples/build-template.yaml .github/workflows/build.yaml
      # Edit build.yaml with replacements
      git add .github/workflows/build.yaml
      git commit -m "chore: update build workflow for GitOps"
      ```
   
   d. Copy `k8s-config/argocd/examples/update-manifest-template.yaml` to `.github/workflows/update-manifest.yaml`
   
   e. Replace SERVICE_NAME and DEPLOYMENT_FILE
   
   f. **Delete or rename** old `deploy.yaml`:
      ```bash
      git mv .github/workflows/deploy.yaml .github/workflows/deploy.yaml.old
      git add .github/workflows/update-manifest.yaml
      git commit -m "chore: replace deploy.yaml with update-manifest.yaml for GitOps"
      ```
   
   g. Push feature branch and test:
      ```bash
      git push origin feat/gitops-workflow
      ```
   
   h. Merge to `dev` first, test, then merge to `main`

2. **In k8s-config repo (already done):**
   
   - Removed hardcoded `namespace: default` ✅
   - Added imagePullPolicy where needed (do this next)

3. **Add imagePullPolicy to deployments:**
   
   ```bash
   cd k8s-config
   # For each deployment in k8s/services/*.yaml, add:
   # imagePullPolicy: Always
   ```

## Pre-Deployment Checklist

- [ ] Create REPO_ACCESS_TOKEN (PAT with repo scope)
- [ ] Add REPO_ACCESS_TOKEN to each microservice repo secrets
- [ ] Verify k8s-config has `dev` and `main` branches
- [ ] Test with one pilot service first (recommend: Time_Logging_Service)
- [ ] Monitor ArgoCD after first deployment
- [ ] Roll out to remaining services

## Testing Strategy

### Pilot Service (Time_Logging_Service):

1. Update workflows in Time_Logging_Service repo
2. Push to `dev` branch
3. Watch GitHub Actions:
   - Build should create image: `ghcr.io/techtorque-2025/timelogging_service:dev-<sha>`
   - Update manifest should commit to k8s-config/dev
4. Watch ArgoCD:
   ```bash
   argocd app get techtorque-services-dev --refresh
   argocd app sync techtorque-services-dev  # if needed
   ```
5. Verify deployment:
   ```bash
   kubectl get pods -n dev -l app=timelogging-service
   kubectl describe pod <pod-name> -n dev | grep Image:
   ```
6. If successful, merge to `main` and test prod flow

### After Pilot Success:

- Roll out to 2-3 more services
- Then batch remaining services

## Rollback Plan

If something goes wrong:

1. **Revert workflow changes:**
   ```bash
   git revert <commit-sha>
   git push
   ```

2. **Manual ArgoCD rollback:**
   ```bash
   argocd app history techtorque-services-dev
   argocd app rollback techtorque-services-dev <revision>
   ```

3. **Emergency: use old deploy.yaml:**
   - Rename `deploy.yaml.old` back to `deploy.yaml`
   - Push

## Common Issues and Fixes

### "Permission denied" when pushing to k8s-config

**Fix:** Verify REPO_ACCESS_TOKEN has `repo` scope and is added to repo secrets

### Image not updating in cluster

**Fix:** 
1. Check imagePullPolicy is set to Always
2. Force ArgoCD refresh: `argocd app get <app> --refresh`
3. Check image exists: `docker pull ghcr.io/techtorque-2025/<service>:<tag>`

### Workflow not triggering

**Fix:**
- Verify `workflow_run` trigger name matches the build workflow name exactly
- Check branches list includes the branch you pushed to

### ArgoCD shows "OutOfSync" but doesn't auto-sync

**Fix:**
- Check if manual sync needed due to warnings
- Run: `argocd app sync <app> --grpc-web`

## Service Update Order (Recommended)

1. ✅ Time_Logging_Service (pilot)
2. Frontend_Web (different build type, good test)
3. Authentication (critical service)
4. API_Gateway (critical service)
5. Batch remaining services in groups of 3-4

---

**Document created:** 2025-11-15  
**Use this with:** GITOPS_CI_CD_WORKFLOW.md  
**Templates:** build-template.yaml, update-manifest-template.yaml
