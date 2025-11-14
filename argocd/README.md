# ArgoCD Setup for TechTorque K3s Cluster

This directory contains ArgoCD configuration for GitOps-based continuous deployment of the TechTorque platform.

## Overview

ArgoCD enables:
- **GitOps Workflow**: Git as the single source of truth for deployments
- **Automated Sync**: Automatic deployment when you push to Git
- **Self-Healing**: Automatically reverts manual changes to match Git state
- **Declarative Configuration**: All deployments defined in Git
- **Easy Rollbacks**: Revert to any previous Git commit
- **Better Visibility**: UI dashboard showing deployment status

## Architecture

```
TechTorque ArgoCD Structure:
├── app-of-apps.yaml          # Root application (manages all apps)
├── applications/
│   ├── databases.yaml        # Database deployments
│   ├── configmaps.yaml       # ConfigMaps
│   ├── services.yaml         # All microservices
│   └── autoscaling.yaml      # HPA configuration
└── install-argocd.sh         # Installation script
```

## Prerequisites

1. **K3s cluster** running (already done ✓)
2. **Git repository** with k8s manifests pushed to GitHub
3. **kubectl** access to the cluster

## Installation

### Step 1: Install ArgoCD

```bash
# Run the installation script
cd k8s-config/argocd
sudo ./install-argocd.sh
```

This will:
- Create `argocd` namespace
- Install ArgoCD components
- Wait for all pods to be ready

### Step 2: Get ArgoCD Admin Password

```bash
# Get the initial admin password
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d
echo ""
```

Save this password - you'll need it to login.

### Step 3: Access ArgoCD UI

**Option A: Port Forward (Recommended for initial setup)**
```bash
kubectl port-forward svc/argocd-server -n argocd 8080:443
```

Then access: https://localhost:8080
- Username: `admin`
- Password: (from step 2)

**Option B: Expose via Ingress** (for production)
See "Production Setup" section below.

### Step 4: Install ArgoCD CLI (Optional but Recommended)

```bash
# Download ArgoCD CLI
curl -sSL -o argocd https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64

# Install
sudo install -m 555 argocd /usr/local/bin/argocd

# Verify
argocd version

# Login
argocd login localhost:8080 --username admin --password <password-from-step-2>
```

## Configuration

### Step 1: Update Git Repository URL

Before deploying applications, update the repository URL in all application manifests:

```bash
# Edit each file and replace the repoURL
nano applications/app-of-apps.yaml
nano applications/databases.yaml
nano applications/configmaps.yaml
nano applications/services.yaml
nano applications/autoscaling.yaml
```

Change:
```yaml
repoURL: https://github.com/TechTorque-2025/TechTorque-2025.git  # UPDATE THIS
```

To your actual repository URL.

**Important**: If using a private repository, you'll need to configure repository credentials (see below).

### Step 2: Configure Private Repository (if needed)

If your repository is private:

```bash
# Using HTTPS with username/password
argocd repo add https://github.com/YOUR_ORG/TechTorque-2025.git \
  --username YOUR_USERNAME \
  --password YOUR_GITHUB_TOKEN

# Or using SSH
argocd repo add git@github.com:YOUR_ORG/TechTorque-2025.git \
  --ssh-private-key-path ~/.ssh/id_rsa
```

## Deployment

### Deploy Using App of Apps Pattern

The recommended approach is to deploy the root "app of apps":

```bash
# Apply the root application
kubectl apply -f k8s-config/argocd/applications/app-of-apps.yaml

# This will automatically create all child applications:
# - techtorque-databases
# - techtorque-configmaps
# - techtorque-services
# - techtorque-autoscaling
```

### Verify Deployment

```bash
# Check ArgoCD applications
kubectl get applications -n argocd

# Expected output:
# NAME                        SYNC STATUS   HEALTH STATUS
# techtorque-apps            Synced        Healthy
# techtorque-databases       Synced        Healthy
# techtorque-configmaps      Synced        Healthy
# techtorque-services        Synced        Healthy
# techtorque-autoscaling     Synced        Healthy
```

Or using ArgoCD CLI:
```bash
argocd app list
```

Or check the UI at https://localhost:8080

## How It Works

### GitOps Workflow

1. **Make Changes in Git**
   ```bash
   # Edit a deployment
   nano k8s-config/k8s/services/auth-deployment.yaml

   # Commit and push
   git add .
   git commit -m "Update auth service image to v2.0"
   git push
   ```

2. **ArgoCD Automatically Syncs**
   - ArgoCD polls your Git repo every 3 minutes (configurable)
   - Detects changes
   - Applies changes to the cluster
   - Updates deployment status in UI

3. **Self-Healing**
   - If someone manually changes a deployment: `kubectl edit deployment auth-deployment`
   - ArgoCD will revert it back to match Git within a few minutes
   - Ensures Git is always the source of truth

### Sync Policies

Each application has different sync policies:

**Databases** (`databases.yaml`):
- `automated.prune: false` - Won't auto-delete databases (safety)
- `automated.selfHeal: true` - Will fix configuration drift
- Manual intervention required to delete databases

**Services** (`services.yaml`):
- `automated.prune: true` - Will delete removed services
- `automated.selfHeal: true` - Automatic drift correction
- `retry` policy for failed deployments

**Autoscaling** (`autoscaling.yaml`):
- Only deploys `hpa-azure-optimized.yaml`
- Excludes documentation and alternative configs

## Common Operations

### Check Application Status

```bash
# List all applications
argocd app list

# Get detailed status
argocd app get techtorque-services

# View sync status
argocd app get techtorque-services --refresh
```

### Manual Sync

```bash
# Sync a specific application
argocd app sync techtorque-services

# Sync all applications
argocd app sync techtorque-apps --cascade
```

### View Application Logs

```bash
# View logs for an application
argocd app logs techtorque-services

# Follow logs
argocd app logs techtorque-services --follow
```

### Rollback to Previous Version

```bash
# View deployment history
argocd app history techtorque-services

# Rollback to specific revision
argocd app rollback techtorque-services <REVISION_NUMBER>
```

### Delete an Application

```bash
# Delete application (but keep resources)
argocd app delete techtorque-services --cascade=false

# Delete application AND its resources
argocd app delete techtorque-services --cascade=true
```

## Image Updates

### Automated Image Updates with GitHub Actions

Your current setup already uses GitHub Actions to build and push images. To trigger ArgoCD sync:

**Option 1: ArgoCD Auto-Sync (Current Setup)**
- ArgoCD polls Git every 3 minutes
- Automatically detects image tag changes
- Deploys new images

**Option 2: Webhook (Faster, Recommended)**

1. Get ArgoCD webhook URL:
   ```bash
   echo "https://your-argocd-domain.com/api/webhook"
   ```

2. Add to GitHub Actions workflow:
   ```yaml
   - name: Trigger ArgoCD Sync
     run: |
       curl -X POST https://your-argocd-domain.com/api/webhook \
         -H "Content-Type: application/json" \
         -d '{
           "application": "techtorque-services",
           "revision": "main"
         }'
   ```

**Option 3: ArgoCD Image Updater (Advanced)**

Install ArgoCD Image Updater to automatically update image tags in Git:
```bash
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj-labs/argocd-image-updater/stable/manifests/install.yaml
```

Then annotate your deployments to enable auto-update.

## Monitoring

### Using ArgoCD UI

1. Access UI: https://localhost:8080
2. Dashboard shows:
   - Sync status (Synced/OutOfSync)
   - Health status (Healthy/Progressing/Degraded)
   - Last sync time
   - Resource tree (visual representation)

### Using CLI

```bash
# Watch application status
watch argocd app list

# Get application details
argocd app get techtorque-services

# View events
kubectl get events -n argocd --sort-by='.lastTimestamp'
```

### Prometheus Metrics

ArgoCD exposes Prometheus metrics at:
```
http://argocd-metrics.argocd.svc.cluster.local:8082/metrics
```

Key metrics:
- `argocd_app_sync_total` - Sync count
- `argocd_app_info` - Application info
- `argocd_app_k8s_request_total` - K8s API requests

## Production Setup

### 1. Expose ArgoCD via Ingress

```yaml
# argocd-ingress.yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: argocd-server-ingress
  namespace: argocd
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt-prod
    nginx.ingress.kubernetes.io/ssl-passthrough: "true"
    nginx.ingress.kubernetes.io/backend-protocol: "HTTPS"
spec:
  ingressClassName: nginx
  rules:
  - host: argocd.yourdomain.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: argocd-server
            port:
              number: 443
  tls:
  - hosts:
    - argocd.yourdomain.com
    secretName: argocd-tls
```

### 2. Change Admin Password

```bash
# Login first
argocd login localhost:8080

# Change password
argocd account update-password
```

### 3. Enable SSO (Optional)

ArgoCD supports SSO with:
- GitHub
- GitLab
- Google
- SAML 2.0
- OIDC

See: https://argo-cd.readthedocs.io/en/stable/operator-manual/user-management/

### 4. Configure RBAC

Create role-based access:
```yaml
# argocd-cm ConfigMap
apiVersion: v1
kind: ConfigMap
metadata:
  name: argocd-rbac-cm
  namespace: argocd
data:
  policy.csv: |
    p, role:developers, applications, get, *, allow
    p, role:developers, applications, sync, *, allow
    g, developers-team, role:developers
```

### 5. Setup Notifications

Configure notifications for sync events:
```bash
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj-labs/argocd-notifications/stable/manifests/install.yaml
```

Supports:
- Slack
- Microsoft Teams
- Email
- Webhooks

## Troubleshooting

### Application Stuck in "OutOfSync"

```bash
# Check application status
argocd app get techtorque-services

# Check for errors
kubectl describe application techtorque-services -n argocd

# Force sync
argocd app sync techtorque-services --force
```

### Application "Progressing" for Too Long

```bash
# Check deployment status
kubectl get deployments

# Check pod status
kubectl get pods

# Check pod logs
kubectl logs -l app=auth-service
```

### "ComparisonError" or "Unknown" Status

```bash
# Refresh application
argocd app get techtorque-services --refresh

# Hard refresh (clear cache)
argocd app get techtorque-services --hard-refresh
```

### Repository Connection Issues

```bash
# List repositories
argocd repo list

# Test repository connection
argocd repo get https://github.com/YOUR_ORG/TechTorque-2025.git

# Remove and re-add repository
argocd repo rm https://github.com/YOUR_ORG/TechTorque-2025.git
argocd repo add https://github.com/YOUR_ORG/TechTorque-2025.git --username YOUR_USERNAME --password YOUR_TOKEN
```

## Migration from kubectl apply

### Current Manual Workflow
```bash
# Old way (manual)
kubectl apply -f k8s-config/k8s/services/
kubectl apply -f k8s-config/k8s/autoscaling/hpa-azure-optimized.yaml
```

### New ArgoCD Workflow
```bash
# New way (GitOps)
git add k8s-config/k8s/services/auth-deployment.yaml
git commit -m "Update auth service"
git push

# ArgoCD automatically syncs within 3 minutes
# Or manually trigger:
argocd app sync techtorque-services
```

### Coexistence Period

You can run both approaches during migration:
1. Keep using `kubectl apply` for manual changes
2. ArgoCD will detect drift and show "OutOfSync"
3. Once confident, enable auto-sync and let ArgoCD manage everything

## Best Practices

1. **Use App of Apps Pattern** (already configured ✓)
   - Single root application manages all apps
   - Easy to deploy entire stack

2. **Enable Auto-Sync for Most Apps**
   - Except databases (keep manual for safety)
   - Reduces manual intervention

3. **Use Self-Heal**
   - Prevents configuration drift
   - Ensures Git is source of truth

4. **Tag Your Images**
   - Don't use `:latest` in production
   - Use semantic versioning: `v1.2.3`
   - Or Git SHA: `sha-abc123`

5. **Prune Old Resources**
   - Enable `prune: true` for services
   - Automatically removes deleted resources

6. **Use Sync Waves** (for complex deployments)
   - Deploy in order: ConfigMaps → Databases → Services
   - Add annotation: `argocd.argoproj.io/sync-wave: "1"`

7. **Monitor Sync Status**
   - Set up notifications
   - Check UI regularly
   - Use Prometheus metrics

## Advanced Features

### Health Checks

ArgoCD automatically checks:
- Deployments: All replicas ready
- StatefulSets: All replicas ready
- Services: Endpoints exist
- Custom health checks available

### Sync Hooks

Run jobs before/after sync:
```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: database-migration
  annotations:
    argocd.argoproj.io/hook: PreSync
```

### Sync Waves

Control deployment order:
```yaml
metadata:
  annotations:
    argocd.argoproj.io/sync-wave: "1"  # Deploy first
```

### Resource Exclusions

Exclude resources from sync:
```yaml
spec:
  ignoreDifferences:
  - group: apps
    kind: Deployment
    jsonPointers:
    - /spec/replicas  # Ignore replica count (let HPA manage)
```

## Resources

- [ArgoCD Documentation](https://argo-cd.readthedocs.io/)
- [ArgoCD Best Practices](https://argo-cd.readthedocs.io/en/stable/user-guide/best_practices/)
- [GitOps Principles](https://www.gitops.tech/)
- [App of Apps Pattern](https://argo-cd.readthedocs.io/en/stable/operator-manual/cluster-bootstrapping/)

## Quick Reference

```bash
# Installation
./install-argocd.sh

# Get password
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d

# Port forward
kubectl port-forward svc/argocd-server -n argocd 8080:443

# Login CLI
argocd login localhost:8080

# Deploy apps
kubectl apply -f applications/app-of-apps.yaml

# List apps
argocd app list

# Sync app
argocd app sync techtorque-services

# View logs
argocd app logs techtorque-services --follow

# Rollback
argocd app history techtorque-services
argocd app rollback techtorque-services <REVISION>
```

## Support

For issues or questions:
1. Check ArgoCD logs: `kubectl logs -n argocd deployment/argocd-server`
2. Check application events: `kubectl describe application -n argocd`
3. Visit ArgoCD Slack: https://argoproj.github.io/community/join-slack/
4. GitHub Issues: https://github.com/argoproj/argo-cd/issues

---
**Status**: Ready to deploy
**Last Updated**: November 14, 2025
**Maintained By**: DevOps Team
