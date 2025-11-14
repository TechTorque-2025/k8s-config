# ArgoCD Quick Start Guide

Get ArgoCD up and running in 5 minutes!

## Step-by-Step Installation

### 1. Install ArgoCD (2 minutes)

```bash
cd k8s-config/argocd
sudo ./install-argocd.sh
```

Wait for the script to complete.

### 2. Get Admin Password

```bash
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d
echo ""
```

**Copy this password!** You'll need it in the next step.

### 3. Access ArgoCD UI

Open a new terminal and run:
```bash
kubectl port-forward svc/argocd-server -n argocd 8080:443
```

Keep this terminal open. Then:
1. Open browser: https://localhost:8080
2. Login:
   - Username: `admin`
   - Password: (from step 2)

### 4. Update Repository URL

**Important**: Edit these files and replace the GitHub URL with your actual repository:

```bash
# Update all application manifests
nano applications/app-of-apps.yaml
nano applications/databases.yaml
nano applications/configmaps.yaml
nano applications/services.yaml
nano applications/autoscaling.yaml
```

Change this line in each file:
```yaml
repoURL: https://github.com/TechTorque-2025/TechTorque-2025.git
```

To your actual repo URL.

### 5. Push to Git

**Critical**: Ensure all your k8s manifests are pushed to Git:

```bash
cd /home/randitha/Desktop/IT/UoM/TechTorque-2025

# Check status
git status

# Add ArgoCD configs
git add k8s-config/argocd/

# Commit
git commit -m "Add ArgoCD configuration"

# Push to GitHub
git push origin main  # or 'master' depending on your branch
```

### 6. Deploy Applications

```bash
# Deploy the root application (will create all child apps)
kubectl apply -f k8s-config/argocd/applications/app-of-apps.yaml
```

### 7. Verify Deployment

Check in the UI or run:
```bash
# Wait 1-2 minutes, then check status
kubectl get applications -n argocd

# Should show 5 applications:
# - techtorque-apps
# - techtorque-databases
# - techtorque-configmaps
# - techtorque-services
# - techtorque-autoscaling
```

## What Just Happened?

1. ArgoCD is now watching your Git repository
2. Any changes you push to Git will automatically deploy to K8s
3. ArgoCD will keep your cluster in sync with Git
4. Manual changes will be reverted (self-healing)

## Next Steps

### Try Making a Change

1. Edit a deployment:
   ```bash
   nano k8s-config/k8s/services/auth-deployment.yaml
   # Change something (e.g., add a comment)
   ```

2. Commit and push:
   ```bash
   git add k8s-config/k8s/services/auth-deployment.yaml
   git commit -m "Test ArgoCD sync"
   git push
   ```

3. Watch ArgoCD sync (within 3 minutes):
   - Check the UI
   - Or run: `watch kubectl get applications -n argocd`

### Install ArgoCD CLI (Optional)

```bash
curl -sSL -o argocd https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
sudo install -m 555 argocd /usr/local/bin/argocd
argocd version
```

Login:
```bash
argocd login localhost:8080 --username admin --password <your-password>
```

Useful commands:
```bash
# List applications
argocd app list

# Sync manually
argocd app sync techtorque-services

# View status
argocd app get techtorque-services
```

## Troubleshooting

### Can't Access UI

```bash
# Make sure port-forward is running
kubectl port-forward svc/argocd-server -n argocd 8080:443
```

### Application Shows "Unknown" or "OutOfSync"

```bash
# Wait 1-2 minutes for initial sync
# Or manually trigger:
kubectl patch application techtorque-services -n argocd --type merge -p '{"operation":{"initiatedBy":{"automated":true},"sync":{"revision":"main"}}}'
```

### Repository Connection Failed

If using a private repository:
```bash
# Add repository credentials
argocd repo add https://github.com/YOUR_ORG/TechTorque-2025.git \
  --username YOUR_USERNAME \
  --password YOUR_GITHUB_TOKEN
```

### Applications Not Created

```bash
# Check app-of-apps status
kubectl describe application techtorque-apps -n argocd

# Manually create applications
kubectl apply -f applications/databases.yaml
kubectl apply -f applications/configmaps.yaml
kubectl apply -f applications/services.yaml
kubectl apply -f applications/autoscaling.yaml
```

## Migration from kubectl

### Before ArgoCD
```bash
# Manual deployments
kubectl apply -f k8s-config/k8s/services/
kubectl apply -f k8s-config/k8s/autoscaling/hpa-azure-optimized.yaml
```

### With ArgoCD
```bash
# Just push to Git!
git add .
git commit -m "Update services"
git push

# ArgoCD handles the rest
```

## Daily Workflow

### Deploy New Feature
1. Make changes locally
2. Test locally (optional)
3. Commit to Git
4. Push to GitHub
5. ArgoCD automatically deploys within 3 minutes

### Rollback
```bash
# Via Git
git revert <commit-hash>
git push

# Or via ArgoCD
argocd app history techtorque-services
argocd app rollback techtorque-services <revision>
```

### Check Deployment Status
- Open UI: https://localhost:8080
- Or: `argocd app list`

## What's Configured

Your ArgoCD setup includes:

✅ **Auto-Sync**: Changes in Git automatically deploy
✅ **Self-Heal**: Manual changes reverted to match Git
✅ **Retry Logic**: Failed deployments retry automatically
✅ **Prune**: Deleted resources in Git are deleted in cluster
✅ **Health Checks**: ArgoCD monitors pod health
✅ **App of Apps**: Single root app manages all applications

**Databases**: Auto-sync enabled, but prune disabled (safety)
**Services**: Full automation (sync, heal, prune)
**Autoscaling**: Only deploys Azure-optimized HPA

## Next Reading

- Full documentation: [README.md](README.md)
- ArgoCD docs: https://argo-cd.readthedocs.io/
- Best practices: https://argo-cd.readthedocs.io/en/stable/user-guide/best_practices/

## Quick Commands Reference

```bash
# Access UI
kubectl port-forward svc/argocd-server -n argocd 8080:443

# Get password
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d

# List apps
kubectl get applications -n argocd

# Sync app
kubectl patch application techtorque-services -n argocd --type merge -p '{"operation":{"initiatedBy":{"automated":true}}}'

# Or with CLI
argocd app sync techtorque-services

# Check status
argocd app get techtorque-services
```

---
**You're all set!** ArgoCD is now managing your deployments via GitOps. 🚀
