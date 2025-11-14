# ArgoCD Access Options - Quick Guide

## TL;DR - Two Ways to Access ArgoCD

### Option 1: Via Your Domain (Recommended) 🌐

**URL**: https://argocd.techtorque.randitha.net

**Setup**:
```bash
cd k8s-config/argocd
sudo ./install-argocd.sh          # Install ArgoCD
sudo ./configure-ingress.sh       # Configure domain access
```

Then add DNS record:
- **Type**: A
- **Name**: `argocd.techtorque.randitha`
- **Value**: Your server IP (`curl ifconfig.me`)

**Pros**:
- ✅ Access from anywhere
- ✅ HTTPS with valid certificate
- ✅ Permanent access
- ✅ Same domain as your frontend

**Cons**:
- Requires DNS setup (5 minutes)

---

### Option 2: Via Port Forward (Quick Testing) 💻

**URL**: https://localhost:8080

**Setup**:
```bash
cd k8s-config/argocd
sudo ./install-argocd.sh          # Install ArgoCD

# Then start port-forward
kubectl port-forward svc/argocd-server -n argocd 8080:443
```

**Pros**:
- ✅ Instant access
- ✅ No DNS needed
- ✅ Quick testing

**Cons**:
- ❌ Only works on localhost
- ❌ Must keep terminal open
- ❌ Self-signed certificate warning

---

## Get Admin Password

```bash
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d
echo ""
```

Username: `admin`

---

## Your Domain Setup

After configuring domain access, you'll have:

| Domain | Service |
|--------|---------|
| techtorque.randitha.net | Frontend (Next.js) |
| api.techtorque.randitha.net | API Gateway |
| **argocd.techtorque.randitha.net** | **ArgoCD UI** |

All with HTTPS! 🔒

---

## Detailed Guides

- **[DOMAIN_ACCESS.md](DOMAIN_ACCESS.md)** - Complete guide for domain-based access
- **[README.md](README.md)** - Full ArgoCD documentation
- **[QUICKSTART.md](QUICKSTART.md)** - 5-minute installation guide

---

## Which Option Should I Choose?

**Use Domain Access if:**
- You want permanent access
- Multiple people need access
- You're deploying to production
- You want proper HTTPS

**Use Port Forward if:**
- Just testing ArgoCD
- Only you need access
- Don't want to configure DNS yet
- Temporary evaluation

**Recommendation**: Start with port-forward to test, then switch to domain access for production use.
