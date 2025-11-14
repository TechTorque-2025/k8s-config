# Quick Action Checklist - GitOps Migration

## ✅ Completed Today (2025-11-15)

- [x] Installed ArgoCD
- [x] Configured ingress + TLS (https://argocd.techtorque.randitha.net)
- [x] Applied dev and prod app-of-apps
- [x] Removed hardcoded namespaces from k8s-config manifests
- [x] Created workflow templates and documentation
- [x] Committed namespace fixes to feature branch (fix/remove-default-namespace)
- [x] Created PR: fix/remove-default-namespace → dev

## 🎯 Next Actions (Do These Now)

### 1. Merge namespace fix PR

```bash
# On your local machine
cd k8s-config
git checkout dev
git pull origin dev  # get the merged PR

# Verify the fix is in dev
git log --oneline -n 5

# Then merge dev → main (for prod)
git checkout main
git merge dev
git push origin main
```

### 2. Create GitHub Personal Access Token (5 minutes)

1. Go to: https://github.com/settings/tokens?type=beta
2. Click "Generate new token"
3. Configure:
   - **Token name:** `microservices-gitops-workflow`
   - **Expiration:** 90 days (or longer)
   - **Repository access:** Select "Only select repositories"
     - Choose: `TechTorque-2025/k8s-config`
   - **Permissions:**
     - Repository → Contents: **Read and write** ✅
   - Click "Generate token"
4. **IMPORTANT:** Copy the token immediately (you won't see it again!)

### 3. Add Token to All 11 Microservice Repos (10 minutes)

For each repo below, add the token as a secret:

**Repos:**
- Admin_Service
- Agent_Bot
- API_Gateway
- Appointment_Service
- Authentication
- Frontend_Web
- Notification_Service
- Payment_Service
- Project_Service
- Time_Logging_Service
- Vehicle_Service

**Steps for each:**
1. Go to: `https://github.com/TechTorque-2025/<REPO_NAME>/settings/secrets/actions`
2. Click "New repository secret"
3. Name: `REPO_ACCESS_TOKEN`
4. Value: Paste the PAT you created
5. Click "Add secret"
6. Repeat for next repo

**Shortcut:** Use this script to verify token is added:
```bash
# Check if secret exists (won't show value, just confirms it's there)
# You need GitHub CLI (gh) installed
for repo in Admin_Service Agent_Bot API_Gateway Appointment_Service Authentication Frontend_Web Notification_Service Payment_Service Project_Service Time_Logging_Service Vehicle_Service; do
  echo "Checking $repo..."
  gh secret list -R TechTorque-2025/$repo | grep REPO_ACCESS_TOKEN || echo "  ❌ Missing!"
done
```

### 4. Pilot Migration: Time_Logging_Service (20 minutes)

```bash
# Clone if not already local
cd ~/Desktop/IT/UoM/TechTorque-2025
cd Time_Logging_Service

# Create feature branch
git checkout -b feat/gitops-workflow

# Copy templates from k8s-config
cp ../k8s-config/argocd/examples/build-template.yaml .github/workflows/build.yaml
cp ../k8s-config/argocd/examples/update-manifest-template.yaml .github/workflows/update-manifest.yaml

# Edit build.yaml:
# Replace: SERVICE_MODULE → time-logging-service
# Replace: SERVICE_IMAGE_NAME → timelogging_service
nano .github/workflows/build.yaml

# Edit update-manifest.yaml:
# Replace: REPLACE_WITH_SERVICE_NAME → timelogging_service
# Replace: REPLACE_WITH_DEPLOYMENT_FILE → timelogging-deployment.yaml
nano .github/workflows/update-manifest.yaml

# Backup old deploy
git mv .github/workflows/deploy.yaml .github/workflows/deploy.yaml.old

# Commit
git add .github/workflows/
git commit -m "chore: migrate to GitOps workflow with ArgoCD

- Update build.yaml with branch-aware image tagging
- Add update-manifest.yaml to update k8s-config
- Backup old deploy.yaml
- Refs: k8s-config/argocd/GITOPS_CI_CD_WORKFLOW.md"

# Push and create PR
git push -u origin feat/gitops-workflow
gh pr create --base dev --title "chore: migrate to GitOps workflow" --body "Migrates to ArgoCD GitOps workflow. See k8s-config/argocd/GITOPS_CI_CD_WORKFLOW.md"
```

### 5. Test the Workflow (10 minutes)

**Merge PR and watch:**

```bash
# After PR is merged to dev:
# 1. GitHub Actions will run (check in Actions tab)
# 2. Image will be built: ghcr.io/techtorque-2025/timelogging_service:dev-<sha>
# 3. k8s-config/dev will be updated
# 4. ArgoCD will sync

# On deployment server, monitor:
ssh azureuser@4.187.182.202

# Watch ArgoCD
argocd app get techtorque-services-dev --refresh --grpc-web
argocd app sync techtorque-services-dev --grpc-web  # if not auto

# Check pods
sudo kubectl get pods -n dev -l app=timelogging-service
sudo kubectl describe pod <timelogging-pod> -n dev | grep Image:

# Should see image: ghcr.io/techtorque-2025/timelogging_service:dev-<sha>
```

**If successful:** ✅ Proceed to step 6  
**If issues:** See Troubleshooting section below

### 6. Roll Out to Remaining Services (1-2 hours)

**Batch 1** (critical services, do one-by-one):
1. [ ] Frontend_Web
2. [ ] Authentication
3. [ ] API_Gateway

**Batch 2** (can do in parallel):
4. [ ] Admin_Service
5. [ ] Appointment_Service
6. [ ] Notification_Service

**Batch 3** (can do in parallel):
7. [ ] Payment_Service
8. [ ] Project_Service
9. [ ] Vehicle_Service
10. [ ] Agent_Bot

**For each service:**
- Same process as Time_Logging_Service
- Use SERVICE_MIGRATION_GUIDE.md for service-specific replacements
- Test dev first, then merge to main

### 7. Verify Production Deployment (after merging to main)

```bash
# On deployment server:
argocd app get techtorque-services-prod --refresh --grpc-web
argocd app sync techtorque-services-prod --grpc-web

sudo kubectl get pods -n default
sudo kubectl describe pod <timelogging-pod> -n default | grep Image:

# Should see image: ghcr.io/techtorque-2025/timelogging_service:main-<sha>
```

## 📋 Troubleshooting

### Token permission errors

**Symptom:** GitHub Actions fails with "Permission denied" when pushing to k8s-config

**Fix:**
1. Verify token has "Contents: Read and write" permission
2. Re-generate token if needed
3. Update secret in microservice repo

### Workflow not triggering

**Symptom:** update-manifest.yaml doesn't run after build completes

**Fix:**
1. Verify `workflow_run` name matches build workflow name exactly
2. Check branches list includes the branch you're testing
3. Look at GitHub Actions → All workflows to see if it's queued

### ArgoCD not syncing

**Symptom:** k8s-config updated but pods not changing

**Fix:**
```bash
# Force refresh and sync
argocd app get techtorque-services-dev --refresh --grpc-web
argocd app sync techtorque-services-dev --grpc-web

# Check for errors
argocd app get techtorque-services-dev --grpc-web
```

### Image pull errors

**Symptom:** Pods fail with "ErrImagePull"

**Fix:**
1. Verify image exists: `docker pull ghcr.io/techtorque-2025/timelogging_service:<tag>`
2. Check image is public or credentials configured
3. Verify tag in manifest matches what was built

## 📚 Reference Documents

- `argocd/GITOPS_CI_CD_WORKFLOW.md` - Complete workflow documentation
- `argocd/SERVICE_MIGRATION_GUIDE.md` - Service-specific migration steps
- `argocd/SETUP_SUMMARY_2025-11-15.md` - Today's accomplishments
- `argocd/SESSION_NOTES_2025-11-15.md` - Detailed session log

## ⏱️ Estimated Time

- Steps 1-3: ~20 minutes
- Step 4-5: ~30 minutes (pilot service)
- Step 6: ~2 hours (all services)
- **Total: ~3 hours** for complete migration

## ✅ Success Criteria

You're done when:
- [ ] All 11 services have new workflows
- [ ] Push to `dev` → builds `dev-<sha>` image → updates k8s-config/dev → ArgoCD deploys to dev namespace
- [ ] Merge to `main` → builds `main-<sha>` image → updates k8s-config/main → ArgoCD deploys to default namespace
- [ ] Old deploy.yaml workflows deleted or disabled
- [ ] No manual kubectl in CI workflows
- [ ] All deployments show correct image tags

## 🎉 When Complete

- Remove KUBE_CONFIG_DATA secret from all repos (no longer needed)
- Update team documentation/runbooks
- Consider rotating the PAT in 90 days

---

**Start with Step 1!** Then work through sequentially. Good luck! 🚀
