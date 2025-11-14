# 🚀 Quick Start: Merge & Test Workflows

**Current State:** All 11 services have workflows on `feat/gitops-workflow` branch  
**Next Step:** Start with Time_Logging_Service pilot

---

## ⚡ 5-Minute Merge

### 1. Merge Namespace Fix (k8s-config repo)

```bash
cd ~/Desktop/IT/UoM/TechTorque-2025/k8s-config
git checkout dev && git pull
git checkout main && git merge dev && git push
```

**Why:** k8s-config needs namespace fixes before workflows can deploy properly.

### 2. Merge Time_Logging_Service to Dev

**Via GitHub UI (easiest):**

1. Go to: https://github.com/TechTorque-2025/Time_Logging_Service
2. Open "Pull requests" tab
3. Find PR for `feat/gitops-workflow`
4. **Change base from `main` to `dev`** ← Important!
5. Click "Merge pull request"

**Via CLI (if preferred):**

```bash
cd ~/Desktop/IT/UoM/TechTorque-2025/Time_Logging_Service
git checkout dev && git pull
git merge feat/gitops-workflow
git push origin dev
```

---

## 🔍 Watch the Build (2-3 minutes)

After merge, GitHub Actions runs automatically:

**Go to:** https://github.com/TechTorque-2025/Time_Logging_Service/actions

**Watch for 3 jobs:**

1. **Build and Test** ← Compiles JAR, runs tests
2. **Build & Push Docker Image** ← Creates `dev-<sha>` image
3. **Update K8s Manifest** ← Updates k8s-config/dev

**Success = all 3 jobs show ✅ green**

---

## ⏱️ Verify ArgoCD Synced (5 minutes)

```bash
# SSH to deployment server
ssh azureuser@4.187.182.202

# Check ArgoCD
argocd app get techtorque-services-dev --refresh --grpc-web

# Expected output:
# Status: Synced or Progressing
# Health: Healthy or Progressing
```

**If not synced yet:**

```bash
# Wait 30 seconds, then force sync
argocd app sync techtorque-services-dev --grpc-web
```

---

## ✅ Verify Pods Running (2 minutes)

```bash
# Check pods in dev namespace
sudo kubectl get pods -n dev -l app=timelogging-service

# Expected: Pod showing READY 1/1, STATUS Running

# Check image tag
sudo kubectl describe pod <pod-name> -n dev | grep -A 2 "Image:"

# Expected: Image shows dev-<short-sha> tag (e.g., dev-f4a2b7c)
```

---

## 🎉 If Everything Works

Move to prod:

```bash
# Go back to GitHub: https://github.com/TechTorque-2025/Time_Logging_Service
# Open PR for feat/gitops-workflow again
# Change base from dev to main
# Click "Merge pull request"
```

**Watch:** Same 3 jobs run, but now creating `main-<sha>` image

**Verify:** Same checks in default namespace (prod)

```bash
sudo kubectl get pods -n default -l app=timelogging-service
sudo kubectl describe pod <pod-name> -n default | grep Image:
```

---

## ⚠️ If Something Fails

### Build job failed
- Check: https://github.com/TechTorque-2025/Time_Logging_Service/actions
- See error details in job logs
- Common: Maven build or lint errors (need code fix)

### Docker push failed
- Check: REPO_ACCESS_TOKEN has write access
- Verify image doesn't already exist

### k8s-config update failed
- Check: REPO_ACCESS_TOKEN has repo scope for k8s-config
- Verify branch exists in k8s-config

### ArgoCD not syncing
```bash
argocd app sync techtorque-services-dev --grpc-web
```

### Pod not pulling new image
```bash
# Delete old pod, let deployment recreate with new image
sudo kubectl delete pods -n dev -l app=timelogging-service
```

---

## 📋 Rollout Timeline

**Once Time_Logging_Service works:**

| Service | Est. Time | Priority |
|---------|-----------|----------|
| Frontend_Web | 15-20 min | High (different build) |
| Authentication | 15-20 min | High (critical) |
| API_Gateway | 15-20 min | High (critical) |
| Appointment_Service | 10-15 min | Medium |
| Notification_Service | 10-15 min | Medium |
| Admin_Service | 10-15 min | Medium |
| Payment_Service | 10-15 min | Medium |
| Project_Service | 10-15 min | Medium |
| Vehicle_Service | 10-15 min | Medium |
| Agent_Bot | 15-20 min | Medium (Python) |

**For each:**
1. Merge to dev
2. Wait for workflow (~3 min)
3. Verify in dev namespace (~2 min)
4. Merge to main
5. Verify in prod namespace (~2 min)
6. Move to next

**Total: ~2-3 hours for all 11 services**

---

## 🎯 Success Checklist

- [ ] Namespace fix merged to k8s-config (dev + main)
- [ ] Time_Logging_Service merged to dev
- [ ] Build workflows completed successfully
- [ ] Pod running in dev with `dev-<sha>` image
- [ ] Time_Logging_Service merged to main
- [ ] Pod running in prod with `main-<sha>` image
- [ ] Ready to roll out remaining services

---

**Current Instruction:** Start by running the merge commands above. Let the automation do the rest!

Questions? See: `argocd/MIGRATION_COMPLETE.md` for full details.
