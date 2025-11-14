# Quick Reference - Multi-Environment ArgoCD

## TL;DR Setup

### 1. Create Dev Branch
```bash
git checkout main
git checkout -b dev
git push -u origin dev
```

### 2. Update Repository URLs
Edit all files in `k8s-config/argocd/environments/` and change:
```yaml
repoURL: https://github.com/YOUR_ORG/TechTorque-2025.git
```

### 3. Deploy Environments
```bash
# Production (main branch → default namespace)
kubectl apply -f k8s-config/argocd/environments/prod/app-of-apps-prod.yaml

# Development (dev branch → dev namespace)
kubectl apply -f k8s-config/argocd/environments/dev/app-of-apps-dev.yaml

# Dev ingress
kubectl apply -f k8s-config/argocd/environments/dev-ingress.yaml

# ArgoCD ingress
cd k8s-config/argocd && sudo ./configure-ingress.sh
```

### 4. Configure DNS (Namecheap)

Add ONE A Record:
- **Host**: `techtorque`
- **Value**: Your server IP

Add FOUR CNAME Records:
- `api.techtorque` → `techtorque.randitha.net.`
- `dev.techtorque` → `techtorque.randitha.net.`
- `api-dev.techtorque` → `techtorque.randitha.net.`
- `argocd.techtorque` → `techtorque.randitha.net.`

---

## Domains

| Domain | Environment | Service |
|--------|-------------|---------|
| techtorque.randitha.net | Production | Frontend |
| api.techtorque.randitha.net | Production | API |
| dev.techtorque.randitha.net | Development | Frontend |
| api-dev.techtorque.randitha.net | Development | API |
| argocd.techtorque.randitha.net | Shared | ArgoCD UI |

---

## Git Workflow

### Develop & Test
```bash
git checkout dev
# Make changes
git add .
git commit -m "New feature"
git push origin dev
# ArgoCD deploys to dev namespace
# Test at: https://dev.techtorque.randitha.net
```

### Release to Production
```bash
git checkout main
git merge dev
git push origin main
# ArgoCD deploys to production (default namespace)
# Live at: https://techtorque.randitha.net
```

---

## Check Status

### All Applications
```bash
kubectl get applications -n argocd
```

### Production
```bash
kubectl get pods -n default
kubectl top pods -n default
```

### Development
```bash
kubectl get pods -n dev
kubectl top pods -n dev
```

---

## Useful Commands

### Sync Application
```bash
# Manual sync
argocd app sync techtorque-services-dev
argocd app sync techtorque-services-prod

# Sync all
argocd app sync techtorque-dev-apps --cascade
argocd app sync techtorque-prod-apps --cascade
```

### View Logs
```bash
# ArgoCD app logs
argocd app logs techtorque-services-dev

# Pod logs (dev)
kubectl logs -n dev -l app=auth-service

# Pod logs (prod)
kubectl logs -n default -l app=auth-service
```

### Delete Environment
```bash
# Delete dev environment (keeps resources)
kubectl delete application techtorque-dev-apps -n argocd --cascade=false

# Delete dev environment (removes resources)
kubectl delete application techtorque-dev-apps -n argocd --cascade=true
```

---

## Troubleshooting

### DNS Not Resolving
```bash
# Check DNS
nslookup dev.techtorque.randitha.net

# Clear cache
sudo systemd-resolve --flush-caches

# Wait 5-30 minutes for propagation
```

### Application OutOfSync
```bash
# Check status
argocd app get techtorque-services-dev

# Force sync
argocd app sync techtorque-services-dev --force
```

### Certificate Pending
```bash
# Check certificates
kubectl get certificates -n dev

# Describe for details
kubectl describe certificate dev-techtorque-tls -n dev

# Check cert-manager
kubectl logs -n cert-manager deployment/cert-manager
```

---

## Documentation

| File | Purpose |
|------|---------|
| [MULTI_ENVIRONMENT_SETUP.md](MULTI_ENVIRONMENT_SETUP.md) | Complete multi-env guide |
| [NAMECHEAP_DNS_SETUP.md](NAMECHEAP_DNS_SETUP.md) | Namecheap DNS configuration |
| [DOMAIN_ACCESS.md](DOMAIN_ACCESS.md) | Domain access setup |
| [README.md](README.md) | Full ArgoCD documentation |

---

## Environment Details

| Aspect | Production | Development |
|--------|------------|-------------|
| Git Branch | `main` | `dev` |
| Namespace | `default` | `dev` |
| Domain | techtorque.randitha.net | dev.techtorque.randitha.net |
| API Domain | api.techtorque.randitha.net | api-dev.techtorque.randitha.net |
| Auto-Sync | ✅ Yes | ✅ Yes |
| Self-Heal | ✅ Yes | ✅ Yes |
| Prune | ✅ Yes | ✅ Yes |

---

## Resource Locations

```
k8s-config/argocd/
├── environments/
│   ├── dev/
│   │   ├── app-of-apps-dev.yaml      # Deploy this for dev
│   │   ├── services-dev.yaml
│   │   ├── databases-dev.yaml
│   │   ├── configmaps-dev.yaml
│   │   └── autoscaling-dev.yaml
│   ├── prod/
│   │   ├── app-of-apps-prod.yaml     # Deploy this for prod
│   │   ├── services-prod.yaml
│   │   ├── databases-prod.yaml
│   │   ├── configmaps-prod.yaml
│   │   └── autoscaling-prod.yaml
│   └── dev-ingress.yaml               # Deploy for dev domains
├── argocd-ingress.yaml                # Deploy for ArgoCD domain
└── configure-ingress.sh               # Run to setup ArgoCD ingress
```

---

## Get Admin Password

```bash
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d
echo ""
```

Username: `admin`

---

**Setup Time**: 15-30 minutes
**Requires**: Git branches (main + dev), DNS configuration
**Cost**: $0 (same cluster, different namespaces)
