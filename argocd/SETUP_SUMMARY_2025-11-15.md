# ArgoCD GitOps Setup - Quick Summary

**Date:** 2025-11-15  
**Status:** ✅ ArgoCD installed and configured, workflow templates created

## What We Accomplished Today

### 1. ArgoCD Installation & Configuration ✅
- Installed ArgoCD in `argocd` namespace
- Configured Traefik ingress with Let's Encrypt TLS
- ArgoCD accessible at: https://argocd.techtorque.randitha.net
- Applied dev and prod "app-of-apps" patterns
- Both branches monitored: `main` → prod (default namespace), `dev` → dev namespace

### 2. Namespace Fixes ✅
- Removed hardcoded `namespace: default` from:
  - All configmaps in `k8s/configmaps/*.yaml`
  - Frontend deployment and service
  - All HPAs in `k8s/autoscaling/*.yaml`
- Now ArgoCD Application destination namespace controls where resources are deployed

### 3. CI/CD Workflow Design ✅
- Documented complete GitOps workflow in `argocd/GITOPS_CI_CD_WORKFLOW.md`
- Created reusable templates:
  - `argocd/examples/build-template.yaml` (updated build workflow)
  - `argocd/examples/update-manifest-template.yaml` (replaces old deploy.yaml)
- Created migration guide: `argocd/SERVICE_MIGRATION_GUIDE.md`

## Current State

### ✅ Working
- ArgoCD installed and accessible via web UI and CLI
- DNS and TLS certificates configured
- Dev and prod environments registered
- Namespace separation configured

### ⚠️ Needs Action
- Old workflows still using kubectl directly (bypass ArgoCD)
- Images tagged with `:latest` only (not branch-aware)
- Need to create REPO_ACCESS_TOKEN for CI to update k8s-config
- Need to migrate workflows for all 11 microservices

## Next Steps (Immediate Action Required)

### Step 1: Create GitHub Personal Access Token
```bash
# On GitHub:
# Settings → Developer settings → Personal access tokens → Fine-grained tokens
# Create token with:
# - Repository access: TechTorque-2025/k8s-config
# - Permissions: Contents (Read and write)
# - Name: "microservices-gitops-workflow"
```

### Step 2: Add Token to All Microservice Repos
For each of the 11 microservice repos, add the token as a secret:
```
Settings → Secrets and variables → Actions → New repository secret
Name: REPO_ACCESS_TOKEN
Value: <paste the PAT>
```

### Step 3: Pilot Migration (Time_Logging_Service)
```bash
# In Time_Logging_Service repo:
cd Time_Logging_Service
git checkout -b feat/gitops-workflow

# Copy and customize build template
cp ../k8s-config/argocd/examples/build-template.yaml .github/workflows/build.yaml
# Edit build.yaml: replace SERVICE_MODULE and SERVICE_IMAGE_NAME (see SERVICE_MIGRATION_GUIDE.md)

# Copy and customize update-manifest template
cp ../k8s-config/argocd/examples/update-manifest-template.yaml .github/workflows/update-manifest.yaml
# Edit update-manifest.yaml: replace SERVICE_NAME and DEPLOYMENT_FILE

# Backup old deploy workflow
git mv .github/workflows/deploy.yaml .github/workflows/deploy.yaml.old

# Commit and test
git add .github/workflows/
git commit -m "chore: migrate to GitOps workflow with ArgoCD"
git push origin feat/gitops-workflow

# Merge to dev first, test, then to main
```

### Step 4: Test the Flow
```bash
# On your deployment server:
# Watch ArgoCD
argocd app get techtorque-services-dev --refresh
argocd app sync techtorque-services-dev  # if not auto

# Verify pods
kubectl get pods -n dev
kubectl describe pod <timelogging-pod> -n dev | grep Image:
```

### Step 5: Roll Out to Remaining Services
Follow the same process for:
1. Frontend_Web
2. Authentication  
3. API_Gateway
4. Then batch the rest (Admin, Agent_Bot, Appointment, Notification, Payment, Project, Vehicle)

## Key Files Created

| File | Purpose |
|------|---------|
| `argocd/GITOPS_CI_CD_WORKFLOW.md` | Complete workflow documentation |
| `argocd/SERVICE_MIGRATION_GUIDE.md` | Service-specific migration steps |
| `argocd/examples/build-template.yaml` | Updated build workflow template |
| `argocd/examples/update-manifest-template.yaml` | New manifest update workflow |
| `argocd/SESSION_NOTES_2025-11-15.md` | Today's session notes |

## How the New Workflow Works

```
Developer pushes to microservice/dev
  ↓
GitHub Actions builds image: ghcr.io/.../service:dev-abc1234
  ↓
GitHub Actions updates k8s-config/dev manifest
  ↓
ArgoCD detects Git change
  ↓
ArgoCD deploys to dev namespace (automatic)
  ↓
✅ Service running with new image
```

Same flow for main → prod (default namespace)

## Important Commands

### ArgoCD
```bash
# List all apps
argocd app list

# Get app status
argocd app get techtorque-services-dev
argocd app get techtorque-services-prod

# Force sync
argocd app sync techtorque-services-dev --grpc-web

# View history
argocd app history techtorque-services-dev

# Rollback
argocd app rollback techtorque-services-dev <revision>
```

### Kubernetes
```bash
# Check pods
kubectl get pods -n dev
kubectl get pods -n default

# Check image tags
kubectl describe pod <pod-name> -n dev | grep Image:

# Check events
kubectl get events -n dev --sort-by='.lastTimestamp' | tail -20
```

## Security Improvements

Old way:
- CI had direct kubeconfig access to cluster ❌
- Manual kubectl apply in workflows ❌
- No audit trail ❌

New way:
- CI only updates Git ✅
- ArgoCD controls cluster access ✅
- All changes in Git history ✅
- Easy rollback via Git ✅

## Rollback Strategy

### If workflow migration goes wrong:
```bash
# In microservice repo:
git mv .github/workflows/deploy.yaml.old .github/workflows/deploy.yaml
git commit -m "rollback: restore old deploy workflow"
git push
```

### If deployment fails:
```bash
# ArgoCD rollback:
argocd app history techtorque-services-dev
argocd app rollback techtorque-services-dev <previous-revision>

# Or Git revert:
cd k8s-config
git revert <bad-commit>
git push origin dev  # ArgoCD will auto-sync the revert
```

## Questions to Answer Before Migration

- [ ] Do we have a GitHub PAT ready with repo scope for k8s-config?
- [ ] Are we comfortable testing with dev environment first?
- [ ] Do we want to keep old deploy.yaml as backup initially?
- [ ] Should we migrate one service at a time or batch them?
- [ ] Who will monitor the first deployment and verify it works?

## Success Criteria

✅ Migration successful when:
1. Push to `dev` branch builds image with `dev-<sha>` tag
2. CI updates k8s-config/dev manifest automatically
3. ArgoCD syncs the change without manual intervention
4. New pods running with correct image tag in dev namespace
5. Same flow works for `main` → prod

## Support & Troubleshooting

- Full documentation: `argocd/GITOPS_CI_CD_WORKFLOW.md`
- Migration guide: `argocd/SERVICE_MIGRATION_GUIDE.md`
- ArgoCD UI: https://argocd.techtorque.randitha.net
- ArgoCD docs: https://argo-cd.readthedocs.io/

---

**Ready to proceed?** Start with Step 1 (create PAT) and Step 2 (add to repos), then we can migrate the pilot service together.
