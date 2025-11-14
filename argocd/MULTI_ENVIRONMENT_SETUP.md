# Multi-Environment Setup with ArgoCD

This guide shows you how to run separate **Production** and **Development** environments using ArgoCD with Git branches.

## Architecture Overview

### Environment Separation

| Environment | Git Branch | Namespace | Domains |
|------------|------------|-----------|---------|
| **Production** | `main` | `default` | techtorque.randitha.net<br>api.techtorque.randitha.net |
| **Development** | `dev` | `dev` | dev.techtorque.randitha.net<br>api-dev.techtorque.randitha.net |

### How It Works

```
┌─────────────────────────────────────────────────────────┐
│  Git Repository                                         │
├─────────────────────────────────────────────────────────┤
│                                                          │
│  main branch  ──────────► Production Deployment         │
│  (stable)                 namespace: default            │
│                           domain: techtorque.randitha.net│
│                                                          │
│  dev branch   ──────────► Development Deployment        │
│  (testing)                namespace: dev                │
│                           domain: dev.techtorque.randitha.net│
│                                                          │
└─────────────────────────────────────────────────────────┘
```

### Benefits

✅ **Isolated Environments**: Dev and prod don't interfere with each other
✅ **Test Before Release**: Test changes in dev before merging to main
✅ **Same Cluster**: Both environments on one K3s cluster (cost-effective)
✅ **Branch-Based Deployment**: Push to dev branch → dev deploys, merge to main → prod deploys
✅ **Independent Scaling**: Dev can have fewer replicas than prod

## Directory Structure

```
k8s-config/argocd/
├── environments/
│   ├── dev/                           # Dev environment apps
│   │   ├── app-of-apps-dev.yaml      # Root app for dev
│   │   ├── services-dev.yaml          # Microservices (dev)
│   │   ├── databases-dev.yaml         # Databases (dev)
│   │   ├── configmaps-dev.yaml        # ConfigMaps (dev)
│   │   └── autoscaling-dev.yaml       # HPA (dev)
│   ├── prod/                          # Production environment apps
│   │   ├── app-of-apps-prod.yaml     # Root app for prod
│   │   ├── services-prod.yaml         # Microservices (prod)
│   │   ├── databases-prod.yaml        # Databases (prod)
│   │   ├── configmaps-prod.yaml       # ConfigMaps (prod)
│   │   └── autoscaling-prod.yaml      # HPA (prod)
│   └── dev-ingress.yaml               # Ingress for dev environment
└── applications/                       # Legacy (single environment)
```

## Prerequisites

1. ✅ ArgoCD installed
2. ✅ K3s cluster running
3. ✅ Two Git branches: `main` and `dev`

## Setup Instructions

### Step 1: Create Dev Branch

If you don't have a dev branch yet:

```bash
cd /home/randitha/Desktop/IT/UoM/TechTorque-2025

# Create dev branch from main
git checkout main
git pull
git checkout -b dev
git push -u origin dev
```

### Step 2: Update Repository URLs

Update the repository URL in all application manifests:

**Dev Environment**:
```bash
# Edit dev applications
nano k8s-config/argocd/environments/dev/app-of-apps-dev.yaml
nano k8s-config/argocd/environments/dev/services-dev.yaml
nano k8s-config/argocd/environments/dev/databases-dev.yaml
nano k8s-config/argocd/environments/dev/configmaps-dev.yaml
nano k8s-config/argocd/environments/dev/autoscaling-dev.yaml
```

**Production Environment**:
```bash
# Edit prod applications
nano k8s-config/argocd/environments/prod/app-of-apps-prod.yaml
nano k8s-config/argocd/environments/prod/services-prod.yaml
nano k8s-config/argocd/environments/prod/databases-prod.yaml
nano k8s-config/argocd/environments/prod/configmaps-prod.yaml
nano k8s-config/argocd/environments/prod/autoscaling-prod.yaml
```

In each file, change:
```yaml
repoURL: https://github.com/TechTorque-2025/TechTorque-2025.git
```

To your actual repository URL.

### Step 3: Deploy Production Environment

```bash
# Deploy production (from main branch)
kubectl apply -f k8s-config/argocd/environments/prod/app-of-apps-prod.yaml

# Verify
kubectl get applications -n argocd | grep prod
```

Expected output:
```
techtorque-prod-apps         Synced  Healthy
techtorque-services-prod     Synced  Healthy
techtorque-databases-prod    Synced  Healthy
techtorque-configmaps-prod   Synced  Healthy
techtorque-autoscaling-prod  Synced  Healthy
```

### Step 4: Deploy Development Environment

```bash
# Deploy dev (from dev branch)
kubectl apply -f k8s-config/argocd/environments/dev/app-of-apps-dev.yaml

# Verify
kubectl get applications -n argocd | grep dev
```

Expected output:
```
techtorque-dev-apps          Synced  Healthy
techtorque-services-dev      Synced  Healthy
techtorque-databases-dev     Synced  Healthy
techtorque-configmaps-dev    Synced  Healthy
techtorque-autoscaling-dev   Synced  Healthy
```

### Step 5: Configure DNS (Namecheap)

Add DNS records for dev environment:

**Via Namecheap Dashboard**:
1. Login to Namecheap
2. Go to Domain List → Manage → Advanced DNS
3. Add these records:

| Type | Host | Value | TTL |
|------|------|-------|-----|
| A Record | dev.techtorque.randitha | YOUR_SERVER_IP | Automatic |
| A Record | api-dev.techtorque.randitha | YOUR_SERVER_IP | Automatic |
| A Record | argocd.techtorque.randitha | YOUR_SERVER_IP | Automatic |

Or if using CNAME (easier):

| Type | Host | Value | TTL |
|------|------|-------|-----|
| CNAME Record | dev.techtorque.randitha | techtorque.randitha.net | Automatic |
| CNAME Record | api-dev.techtorque.randitha | techtorque.randitha.net | Automatic |
| CNAME Record | argocd.techtorque.randitha | techtorque.randitha.net | Automatic |

Get your server IP:
```bash
curl ifconfig.me
```

### Step 6: Apply Dev Ingress

```bash
# Apply dev environment ingress
kubectl apply -f k8s-config/argocd/environments/dev-ingress.yaml

# Wait for certificates (1-2 minutes)
kubectl get certificates -n dev

# Should show:
# NAME                    READY   SECRET                  AGE
# dev-techtorque-tls      True    dev-techtorque-tls      1m
# api-dev-techtorque-tls  True    api-dev-techtorque-tls  1m
```

### Step 7: Apply ArgoCD Ingress

```bash
# Apply ArgoCD ingress
cd k8s-config/argocd
sudo ./configure-ingress.sh
```

## Accessing Your Environments

### Production

| Service | URL | Namespace |
|---------|-----|-----------|
| Frontend | https://techtorque.randitha.net | default |
| API | https://api.techtorque.randitha.net | default |
| ArgoCD | https://argocd.techtorque.randitha.net | argocd |

### Development

| Service | URL | Namespace |
|---------|-----|-----------|
| Frontend | https://dev.techtorque.randitha.net | dev |
| API | https://api-dev.techtorque.randitha.net | dev |
| ArgoCD | https://argocd.techtorque.randitha.net | argocd (shared) |

## Development Workflow

### Making Changes

**For Development (Testing)**:
```bash
# Work on dev branch
git checkout dev

# Make changes
nano k8s-config/k8s/services/auth-deployment.yaml

# Commit and push
git add .
git commit -m "Update auth service"
git push origin dev

# ArgoCD automatically deploys to dev environment within 3 minutes
# Test at: https://dev.techtorque.randitha.net
```

**For Production (Release)**:
```bash
# Once tested in dev, merge to main
git checkout main
git merge dev
git push origin main

# ArgoCD automatically deploys to production within 3 minutes
# Live at: https://techtorque.randitha.net
```

### Workflow Diagram

```
Developer makes change
        ↓
   git checkout dev
        ↓
   git commit & push
        ↓
ArgoCD syncs dev branch
        ↓
Deploy to dev namespace
        ↓
Test at dev.techtorque.randitha.net
        ↓
   If tests pass ✓
        ↓
   git merge dev → main
        ↓
ArgoCD syncs main branch
        ↓
Deploy to production (default namespace)
        ↓
Live at techtorque.randitha.net
```

## Resource Optimization for Dev

### Lower Resource Limits for Dev

You can reduce dev environment resource usage by creating environment-specific overlays.

Create `k8s-config/overlays/dev/kustomization.yaml`:

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
- ../../k8s/services

# Override replicas for dev
replicas:
- name: frontend-deployment
  count: 1  # Instead of 2 in prod
- name: auth-deployment
  count: 1

# Reduce resource limits
patches:
- patch: |-
    - op: replace
      path: /spec/template/spec/containers/0/resources/limits/memory
      value: "256Mi"
  target:
    kind: Deployment
```

Then update dev services application to use overlays:
```yaml
source:
  path: k8s-config/overlays/dev  # Instead of k8s-config/k8s/services
```

## Monitoring Both Environments

### Check All Applications

```bash
# List all applications
kubectl get applications -n argocd

# Filter by environment
kubectl get applications -n argocd | grep prod
kubectl get applications -n argocd | grep dev
```

### Check Pods by Environment

```bash
# Production pods
kubectl get pods -n default

# Dev pods
kubectl get pods -n dev
```

### Check Resource Usage

```bash
# Overall cluster
kubectl top nodes

# Production namespace
kubectl top pods -n default

# Dev namespace
kubectl top pods -n dev
```

### ArgoCD UI

Access https://argocd.techtorque.randitha.net

You'll see both environments in the same dashboard:
- `techtorque-prod-apps` and children
- `techtorque-dev-apps` and children

## Troubleshooting

### Dev Environment Not Deploying

```bash
# Check application status
kubectl describe application techtorque-dev-apps -n argocd

# Common issues:
# 1. dev branch doesn't exist
git branch -a  # Should show origin/dev

# 2. Repository URL incorrect
kubectl get application techtorque-dev-apps -n argocd -o yaml | grep repoURL

# 3. Sync manually
argocd app sync techtorque-dev-apps --cascade
```

### DNS Not Resolving for Dev Domains

```bash
# Check DNS
nslookup dev.techtorque.randitha.net

# If not resolving:
# 1. Verify DNS records in Namecheap
# 2. Wait 5-10 minutes for propagation
# 3. Clear cache: sudo systemd-resolve --flush-caches
```

### Certificate Pending for Dev

```bash
# Check certificate
kubectl describe certificate dev-techtorque-tls -n dev

# Common causes:
# - DNS not propagated yet (wait)
# - cert-manager not running in dev namespace
kubectl get pods -n cert-manager
```

### Dev and Prod Conflicting

If both environments try to use the same resources:

```bash
# Ensure namespaces are different
kubectl get applications -n argocd -o yaml | grep namespace

# Dev should use: namespace: dev
# Prod should use: namespace: default
```

## Best Practices

### 1. Branch Protection

Protect your main branch:
- Require pull requests
- Require reviews before merge
- Run CI tests on dev branch

### 2. Environment Parity

Keep dev and prod as similar as possible:
- Same service versions (just different data)
- Same configurations (except environment-specific settings)
- Test in dev before prod deployment

### 3. Database Separation

Dev and prod databases are separated by namespace:
- **Prod**: `default` namespace → production data
- **Dev**: `dev` namespace → test data

Never connect dev services to prod databases!

### 4. Resource Limits

Dev can use fewer resources:
- Lower replicas (1 instead of 2-3)
- Smaller memory limits
- Narrower HPA ranges (maxReplicas: 2 instead of 4)

### 5. Monitoring

Set up different alerting for each environment:
- **Prod**: Alert immediately on failures
- **Dev**: Log errors, don't alert (unless severe)

## Advanced: Staging Environment

You can add a third environment:

```bash
# Create staging branch
git checkout main
git checkout -b staging
git push -u origin staging
```

Then create `k8s-config/argocd/environments/staging/` following the same pattern.

Your setup becomes:
- **Dev** (`dev` branch) → Test new features
- **Staging** (`staging` branch) → Pre-production testing
- **Production** (`main` branch) → Live

## Quick Reference

### Deploy Commands

```bash
# Deploy production
kubectl apply -f k8s-config/argocd/environments/prod/app-of-apps-prod.yaml

# Deploy development
kubectl apply -f k8s-config/argocd/environments/dev/app-of-apps-dev.yaml

# Apply dev ingress
kubectl apply -f k8s-config/argocd/environments/dev-ingress.yaml

# Apply ArgoCD ingress
cd k8s-config/argocd && sudo ./configure-ingress.sh
```

### Git Workflow

```bash
# Work on dev
git checkout dev
# Make changes
git add . && git commit -m "Feature X"
git push origin dev
# ArgoCD deploys to dev

# After testing, release to prod
git checkout main
git merge dev
git push origin main
# ArgoCD deploys to production
```

### Check Status

```bash
# All apps
kubectl get applications -n argocd

# Production
kubectl get pods -n default
kubectl top pods -n default

# Development
kubectl get pods -n dev
kubectl top pods -n dev
```

## DNS Summary for Namecheap

| Domain | Type | Value | Environment |
|--------|------|-------|-------------|
| techtorque.randitha.net | A | YOUR_IP | Production Frontend |
| api.techtorque.randitha.net | CNAME | techtorque.randitha.net | Production API |
| dev.techtorque.randitha.net | CNAME | techtorque.randitha.net | Dev Frontend |
| api-dev.techtorque.randitha.net | CNAME | techtorque.randitha.net | Dev API |
| argocd.techtorque.randitha.net | CNAME | techtorque.randitha.net | ArgoCD UI |

All with automatic HTTPS via Let's Encrypt! 🔒

---
**Status**: Ready to deploy multi-environment setup
**Cluster**: Single K3s cluster, multiple namespaces
**Cost**: No additional infrastructure needed
