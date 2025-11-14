# 🚀 START HERE - Quick Start Card

**Status:** All 11 services migrated and verified ✅  
**Ready for:** Pilot testing NOW  
**Time to completion:** 3-4 hours from now

---

## 📍 You Are Here

```
✅ ArgoCD installed
✅ All 11 services migrated
✅ Workflows verified
⏳ Ready for pilot test (YOU ARE HERE)
```

---

## ⚡ Next 5 Minutes

### 1. Read This (2 min)
You're reading it! ✅

### 2. Understand the New Workflow (3 min)

**Old (Bad):** `Push → Build → kubectl apply (bypasses ArgoCD)`

**New (Good):** `Push → Build (dev-<sha>) → Update k8s-config → ArgoCD syncs`

Each service now has:
- **build.yaml** - Creates docker image with branch-sha tag
- **update-manifest.yaml** - Updates k8s-config git repo
- Old **deploy.yaml** → backed up as deploy.yaml.old

---

## 🎯 Your Checklist (Next 4 Hours)

### Minute 1-5: Prep
- [ ] Read: FINAL_MIGRATION_SUMMARY.md (5 min)
- [ ] Read: QUICK_MERGE_TEST.md (3 min)

### Minute 5-10: Merge Namespace Fix
- [ ] Go to GitHub k8s-config repo
- [ ] Merge: fix/remove-default-namespace → dev
- [ ] Merge: dev → main

### Minute 10-40: Pilot Test (Time_Logging_Service → dev)
- [ ] Go to Time_Logging_Service repo
- [ ] Merge: feat/gitops-workflow → dev (CHANGE BASE TO DEV!)
- [ ] Watch: GitHub Actions (3 min)
- [ ] Verify: ArgoCD synced to dev namespace (2 min)
- [ ] Check: Pod running with dev-<sha> image (2 min)

### Minute 40-60: Prod Test (Time_Logging_Service → main)
- [ ] Go to Time_Logging_Service repo
- [ ] Merge: feat/gitops-workflow → main
- [ ] Watch: GitHub Actions (3 min)
- [ ] Verify: ArgoCD synced to prod (2 min)
- [ ] Check: Pod running with main-<sha> image (2 min)

### Minute 60-180: Rollout Remaining Services
- [ ] Frontend_Web (15 min - different build type)
- [ ] Authentication (15 min - critical)
- [ ] API_Gateway (15 min - critical)
- [ ] Batch remaining (90 min - 7 services)

### Minute 180-210: Cleanup
- [ ] Delete old deploy.yaml.old files (5 min)
- [ ] Update team docs (10 min)

---

## 🌐 URLs You'll Need

- **Time_Logging_Service PR:** https://github.com/TechTorque-2025/Time_Logging_Service/pull/new/feat/gitops-workflow
- **k8s-config Namespace Fix:** https://github.com/TechTorque-2025/k8s-config/pulls (find the fix/remove-default-namespace PR)
- **All 11 Service PRs:** See SERVICE_MIGRATION_GUIDE.md

---

## ⚙️ Commands You'll Use

```bash
# SSH to deployment server
ssh azureuser@4.187.182.202

# Check ArgoCD
argocd app get techtorque-services-dev --refresh --grpc-web

# Check dev pods
sudo kubectl get pods -n dev

# Check prod pods
sudo kubectl get pods -n default

# Describe pod to see image tag
sudo kubectl describe pod <pod-name> -n dev | grep Image:
```

---

## ✅ Success Indicators

**Dev deployment works when:**
- Pod running in dev namespace
- Image tag shows: `ghcr.io/techtorque-2025/timelogging_service:dev-abc1234`

**Prod deployment works when:**
- Pod running in default namespace
- Image tag shows: `ghcr.io/techtorque-2025/timelogging_service:main-def5678`

---

## ❓ If Something Breaks

1. **Build fails:** Check GitHub Actions logs
2. **k8s-config update fails:** Check REPO_ACCESS_TOKEN scope
3. **ArgoCD not syncing:** Run `argocd app sync <app> --grpc-web`
4. **Pod not updating:** Run `kubectl delete pods -n <namespace> -l app=<service>`

See: QUICK_MERGE_TEST.md → Troubleshooting section for full guide

---

## 📚 Full Documentation

All docs in: `/home/randitha/Desktop/IT/UoM/TechTorque-2025/k8s-config/argocd/`

- **INDEX.md** - Complete navigation
- **FINAL_MIGRATION_SUMMARY.md** - Full summary
- **QUICK_MERGE_TEST.md** - Testing guide
- Other detailed docs available

---

## 🎯 Three Simple Rules

1. **For dev:** Merge PR to `dev` branch (CHANGE BASE TO DEV!)
2. **For prod:** Merge PR to `main` branch
3. **Watch:** GitHub Actions build (3 min), then ArgoCD deploy (1 min)

---

## 🚀 Start NOW

```bash
# Read the full summary
cat ~/Desktop/IT/UoM/TechTorque-2025/k8s-config/argocd/FINAL_MIGRATION_SUMMARY.md

# Read the quick test guide
cat ~/Desktop/IT/UoM/TechTorque-2025/k8s-config/argocd/QUICK_MERGE_TEST.md

# Then go to GitHub and start merging!
```

---

**Time estimate:** 3-4 hours to complete full rollout  
**Difficulty:** Low (mostly clicking merge buttons)  
**Risk:** Very low (can rollback anytime)  
**Status:** READY TO GO! 🚀

Questions? Check INDEX.md or the troubleshooting sections in the detailed guides.
