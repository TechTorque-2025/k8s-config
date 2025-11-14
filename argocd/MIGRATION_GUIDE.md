# Migration Guide: kubectl → ArgoCD

This guide explains the differences between your current `kubectl apply` workflow and the new ArgoCD GitOps approach.

## Current vs. ArgoCD Workflow

### Current Manual Workflow (kubectl)

```bash
# 1. Edit deployment file locally
nano k8s-config/k8s/services/auth-deployment.yaml

# 2. Apply manually to cluster
kubectl apply -f k8s-config/k8s/services/auth-deployment.yaml

# 3. Commit to Git (optional, often forgotten)
git add k8s-config/k8s/services/auth-deployment.yaml
git commit -m "Update auth service"
git push
```

**Problems:**
- ❌ Git and cluster can be out of sync
- ❌ Manual `kubectl apply` required for every change
- ❌ No audit trail of who deployed what
- ❌ Configuration drift (manual changes not in Git)
- ❌ Difficult to rollback
- ❌ No visibility into deployment status

### ArgoCD GitOps Workflow

```bash
# 1. Edit deployment file locally
nano k8s-config/k8s/services/auth-deployment.yaml

# 2. Commit to Git
git add k8s-config/k8s/services/auth-deployment.yaml
git commit -m "Update auth service"
git push

# 3. ArgoCD automatically deploys (within 3 minutes)
# OR manually trigger: argocd app sync techtorque-services
```

**Benefits:**
- ✅ Git is always the source of truth
- ✅ Automatic deployment on push
- ✅ Full audit trail in Git history
- ✅ Self-healing (manual changes reverted)
- ✅ Easy rollback (git revert)
- ✅ Dashboard shows deployment status

## Side-by-Side Comparison

| Task | kubectl (Current) | ArgoCD (New) |
|------|------------------|-------------|
| Deploy new service | `kubectl apply -f service.yaml` | `git push` (auto-deploys) |
| Update deployment | `kubectl apply -f service.yaml` | `git push` (auto-deploys) |
| Rollback | Manually revert and `kubectl apply` | `git revert && git push` or `argocd app rollback` |
| Check status | `kubectl get deployments` | ArgoCD UI or `argocd app get` |
| Audit trail | None (unless committed to Git) | Full Git history |
| Configuration drift | Can happen (manual changes) | Prevented (self-healing) |
| Multi-cluster | Repeat `kubectl` for each | Single Git repo, multiple ArgoCD instances |
| CI/CD integration | Must script `kubectl` commands | Just push to Git |

## Common Operations

### Deploy a New Service

**Before (kubectl):**
```bash
# Create deployment file
nano k8s-config/k8s/services/new-service-deployment.yaml

# Apply manually
kubectl apply -f k8s-config/k8s/services/new-service-deployment.yaml

# (Maybe) commit to Git
git add k8s-config/k8s/services/new-service-deployment.yaml
git commit -m "Add new service"
git push
```

**After (ArgoCD):**
```bash
# Create deployment file
nano k8s-config/k8s/services/new-service-deployment.yaml

# Commit to Git
git add k8s-config/k8s/services/new-service-deployment.yaml
git commit -m "Add new service"
git push

# ArgoCD deploys automatically within 3 minutes
# Check UI or: argocd app get techtorque-services
```

### Update Container Image

**Before (kubectl):**
```bash
# Edit deployment
nano k8s-config/k8s/services/auth-deployment.yaml
# Change image: ghcr.io/techtorque-2025/auth_service:v1.0
# To:      image: ghcr.io/techtorque-2025/auth_service:v2.0

# Apply
kubectl apply -f k8s-config/k8s/services/auth-deployment.yaml

# Verify
kubectl rollout status deployment/auth-deployment
```

**After (ArgoCD):**
```bash
# Edit deployment
nano k8s-config/k8s/services/auth-deployment.yaml
# Change image tag

# Commit and push
git add k8s-config/k8s/services/auth-deployment.yaml
git commit -m "Update auth service to v2.0"
git push

# ArgoCD syncs automatically
# Watch in UI or: argocd app get techtorque-services --refresh
```

### Rollback to Previous Version

**Before (kubectl):**
```bash
# Option 1: kubectl rollback
kubectl rollout undo deployment/auth-deployment

# Option 2: Revert Git and reapply
git revert <commit-hash>
kubectl apply -f k8s-config/k8s/services/auth-deployment.yaml
```

**After (ArgoCD):**
```bash
# Option 1: Git revert (recommended)
git revert <commit-hash>
git push
# ArgoCD auto-syncs

# Option 2: ArgoCD rollback
argocd app history techtorque-services
argocd app rollback techtorque-services <revision-number>
```

### Scale Deployment

**Before (kubectl):**
```bash
# Manual scaling
kubectl scale deployment auth-deployment --replicas=3

# Or edit deployment
nano k8s-config/k8s/services/auth-deployment.yaml
kubectl apply -f k8s-config/k8s/services/auth-deployment.yaml
```

**After (ArgoCD):**
```bash
# Edit deployment in Git
nano k8s-config/k8s/services/auth-deployment.yaml
# Change replicas: 1 to replicas: 3

# Commit and push
git add k8s-config/k8s/services/auth-deployment.yaml
git commit -m "Scale auth service to 3 replicas"
git push

# Note: With HPA enabled, replica count is managed by HPA
# ArgoCD can ignore replica count changes via ignoreDifferences
```

### Delete a Service

**Before (kubectl):**
```bash
# Delete manually
kubectl delete deployment auth-deployment
kubectl delete service auth-service

# (Maybe) remove from Git
git rm k8s-config/k8s/services/auth-deployment.yaml
git commit -m "Remove auth service"
git push
```

**After (ArgoCD):**
```bash
# Remove from Git
git rm k8s-config/k8s/services/auth-deployment.yaml
git commit -m "Remove auth service"
git push

# ArgoCD automatically prunes (deletes) the resources
# (Because prune: true is enabled for services)
```

## Handling Manual Changes

### Scenario: Someone runs kubectl edit

**Before (kubectl):**
```bash
# Developer runs:
kubectl edit deployment auth-deployment
# Changes replica count from 1 to 3

# Problem: Change is NOT in Git
# Next time someone runs kubectl apply from Git:
kubectl apply -f k8s-config/k8s/services/auth-deployment.yaml
# Replicas revert to 1 (from Git)
# Loss of manual change, confusion ensues
```

**After (ArgoCD):**
```bash
# Developer runs:
kubectl edit deployment auth-deployment
# Changes replica count from 1 to 3

# ArgoCD detects drift
# - Shows "OutOfSync" in UI
# - With selfHeal: true, automatically reverts within minutes
# - Deployment goes back to replicas: 1 (from Git)

# The RIGHT way:
# 1. Edit in Git
# 2. Commit and push
# 3. ArgoCD deploys
```

## Migration Strategy

### Phase 1: Install ArgoCD (Day 1)

```bash
# Install ArgoCD
cd k8s-config/argocd
sudo ./install-argocd.sh

# Access UI and verify it works
kubectl port-forward svc/argocd-server -n argocd 8080:443
```

### Phase 2: Deploy Applications (Day 1-2)

```bash
# Update repository URLs in application manifests
nano applications/*.yaml

# Ensure Git is up to date
git add .
git commit -m "Add ArgoCD configuration"
git push

# Deploy root application
kubectl apply -f applications/app-of-apps.yaml

# Verify in UI
```

### Phase 3: Coexistence (Week 1)

During this phase:
- ArgoCD is managing deployments
- You can still use `kubectl` if needed
- ArgoCD will show "OutOfSync" after manual kubectl changes
- Use this week to get familiar with ArgoCD

```bash
# Still using kubectl (old way)
kubectl apply -f k8s-config/k8s/services/auth-deployment.yaml

# ArgoCD detects drift, shows "OutOfSync"
# You can see what changed in the UI

# Sync to Git state
argocd app sync techtorque-services
```

### Phase 4: Full GitOps (Week 2+)

After Week 1:
- Stop using `kubectl apply` for deployments
- All changes via Git push
- ArgoCD auto-syncs (self-healing enabled)
- Use ArgoCD UI/CLI for operations

```bash
# New workflow
nano k8s-config/k8s/services/auth-deployment.yaml
git add .
git commit -m "Update auth service"
git push

# That's it! ArgoCD handles deployment
```

## Troubleshooting Migration Issues

### Issue: Application stuck "OutOfSync"

**Cause:** Manual changes were made via kubectl

**Solution:**
```bash
# Option 1: Sync to Git state (recommended)
argocd app sync techtorque-services

# Option 2: Commit current cluster state to Git
kubectl get deployment auth-deployment -o yaml > k8s-config/k8s/services/auth-deployment.yaml
git add .
git commit -m "Update auth deployment from cluster state"
git push
```

### Issue: ArgoCD and kubectl fighting

**Cause:** Both trying to manage the same resources

**Solution:**
```bash
# Choose one approach:

# Option A: Let ArgoCD manage (recommended)
# - Stop using kubectl apply
# - Make all changes via Git
# - Enable selfHeal in ArgoCD

# Option B: Disable auto-sync temporarily
kubectl patch application techtorque-services -n argocd \
  --type merge -p '{"spec":{"syncPolicy":{"automated":null}}}'

# Make kubectl changes
kubectl apply -f ...

# Re-enable auto-sync
kubectl patch application techtorque-services -n argocd \
  --type merge -p '{"spec":{"syncPolicy":{"automated":{"prune":true,"selfHeal":true}}}}'
```

### Issue: Don't want ArgoCD to manage replicas (HPA is managing)

**Solution:** Configure ArgoCD to ignore replica count

```yaml
# Edit application manifest
spec:
  ignoreDifferences:
  - group: apps
    kind: Deployment
    jsonPointers:
    - /spec/replicas
```

Or via kubectl:
```bash
kubectl patch application techtorque-services -n argocd --type merge -p '{
  "spec": {
    "ignoreDifferences": [
      {
        "group": "apps",
        "kind": "Deployment",
        "jsonPointers": ["/spec/replicas"]
      }
    ]
  }
}'
```

## What Changes in Your Daily Workflow

### For Developers

**Before:**
1. Write code
2. Build Docker image
3. Push to registry
4. Ask DevOps to deploy OR manually run kubectl

**After:**
1. Write code
2. Build Docker image (CI/CD does this)
3. CI/CD updates manifest in Git
4. ArgoCD auto-deploys
5. Check deployment status in ArgoCD UI

### For DevOps

**Before:**
- Manually run kubectl commands
- Troubleshoot "who deployed what?"
- Configuration drift issues
- No easy rollback

**After:**
- Manage via Git (pull requests, code review)
- Full audit trail in Git
- Self-healing prevents drift
- Rollback = git revert

## Benefits You'll See

### Week 1
- ✅ Visibility: See all deployments in one UI
- ✅ Audit trail: Every change in Git history
- ✅ Less manual work: No more kubectl apply

### Week 2
- ✅ Self-healing: Manual changes auto-reverted
- ✅ Automated deployments: Push to Git = deployed
- ✅ Easy rollbacks: git revert works

### Month 1
- ✅ Team efficiency: Developers can deploy via PR
- ✅ Reduced errors: No more forgotten kubectl commands
- ✅ Better compliance: Everything in Git

### Long-term
- ✅ Multi-cluster: Manage multiple clusters from one Git repo
- ✅ Disaster recovery: Rebuild cluster from Git
- ✅ GitOps best practices: Industry standard approach

## FAQ

**Q: Can I still use kubectl get/describe/logs?**
A: Yes! ArgoCD only manages deployments. You can still use kubectl for read operations and debugging.

**Q: What if GitHub is down?**
A: Your cluster keeps running. ArgoCD just won't sync new changes until GitHub is back. You can manually use kubectl in emergencies.

**Q: Can I disable ArgoCD temporarily?**
A: Yes:
```bash
# Disable auto-sync for an app
kubectl patch application techtorque-services -n argocd \
  --type merge -p '{"spec":{"syncPolicy":{"automated":null}}}'

# Or delete the application (keeps resources)
kubectl delete application techtorque-services -n argocd
```

**Q: How do I handle secrets?**
A: Don't commit secrets to Git! Use:
- Sealed Secrets (recommended)
- External Secrets Operator
- HashiCorp Vault
- Keep secrets in Kubernetes, only reference them in manifests

**Q: Does this work with HPA?**
A: Yes! Configure ArgoCD to ignore replica count (HPA manages it). Already configured in the services application.

**Q: Can I deploy from feature branches?**
A: Yes! Create separate ArgoCD applications pointing to different branches:
```yaml
spec:
  source:
    targetRevision: feature-branch-name
```

## Recommended Tools

### CLI Tools

```bash
# ArgoCD CLI (recommended)
curl -sSL -o argocd https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
sudo install -m 555 argocd /usr/local/bin/argocd

# kubectx/kubens (switch contexts easily)
sudo apt install kubectx

# k9s (Kubernetes UI in terminal)
sudo snap install k9s
```

### VS Code Extensions

- **GitLens**: Better Git integration
- **Kubernetes**: YAML syntax and validation
- **YAML**: YAML language support

## Next Steps

1. ✅ Read [QUICKSTART.md](QUICKSTART.md) to install ArgoCD
2. ✅ Read [README.md](README.md) for full documentation
3. ✅ Deploy app-of-apps pattern
4. ✅ Monitor deployments for a week
5. ✅ Transition fully to GitOps workflow

---
**Remember**: Git is now your source of truth. Every change should go through Git!
