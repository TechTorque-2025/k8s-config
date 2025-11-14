# Accessing ArgoCD via Domain

This guide shows you how to access ArgoCD through your domain (`argocd.techtorque.randitha.net`) instead of port-forwarding.

## Overview

You have two options to access ArgoCD:

| Method | URL | Best For | Setup Time |
|--------|-----|----------|------------|
| **Domain Access** | https://argocd.techtorque.randitha.net | Production use | 5-10 minutes |
| **Port Forward** | https://localhost:8080 | Quick testing | 30 seconds |

## Option A: Domain Access (Recommended)

This is the recommended approach for production use. ArgoCD will be accessible at:
**https://argocd.techtorque.randitha.net**

### Prerequisites

- ✅ ArgoCD installed (via `./install-argocd.sh`)
- ✅ Traefik ingress controller running (you already have this)
- ✅ cert-manager installed (you already have this)
- ✅ Access to your DNS provider (Azure DNS or domain registrar)

### Step 1: Configure Ingress

Run the configuration script:

```bash
cd k8s-config/argocd
sudo ./configure-ingress.sh
```

This script will:
1. Configure ArgoCD to run in insecure mode (Traefik handles TLS)
2. Restart ArgoCD server
3. Apply Traefik IngressRoute
4. Request Let's Encrypt certificate

### Step 2: Configure DNS

You need to add a DNS record for `argocd.techtorque.randitha.net`.

**Method 1: A Record (Direct IP)**

Add this DNS record:
- **Type**: A
- **Name**: `argocd` (or `argocd.techtorque.randitha` depending on your DNS provider)
- **Value**: Your server's public IP address
- **TTL**: 300 (5 minutes)

To get your server's IP:
```bash
curl ifconfig.me
```

**Method 2: CNAME Record (Alias)**

If you already have `techtorque.randitha.net` pointing to your server:
- **Type**: CNAME
- **Name**: `argocd`
- **Value**: `techtorque.randitha.net`
- **TTL**: 300

#### Azure DNS Example

If using Azure DNS:

```bash
# Get your resource group
az network dns record-set a list --resource-group YOUR_RESOURCE_GROUP --zone-name randitha.net

# Add A record
az network dns record-set a add-record \
  --resource-group YOUR_RESOURCE_GROUP \
  --zone-name randitha.net \
  --record-set-name argocd.techtorque \
  --ipv4-address YOUR_SERVER_IP

# Or add CNAME
az network dns record-set cname set-record \
  --resource-group YOUR_RESOURCE_GROUP \
  --zone-name randitha.net \
  --record-set-name argocd.techtorque \
  --cname techtorque.randitha.net
```

### Step 3: Wait for DNS Propagation

```bash
# Check if DNS is propagated
nslookup argocd.techtorque.randitha.net

# Or use dig
dig argocd.techtorque.randitha.net +short
```

DNS propagation usually takes 1-5 minutes, but can take up to 48 hours in some cases.

### Step 4: Verify Certificate

```bash
# Check certificate status
kubectl get certificate argocd-techtorque-tls -n argocd

# Should show:
# NAME                    READY   SECRET                  AGE
# argocd-techtorque-tls   True    argocd-techtorque-tls   2m

# If not ready, check details:
kubectl describe certificate argocd-techtorque-tls -n argocd
```

### Step 5: Access ArgoCD

Open your browser and go to:
**https://argocd.techtorque.randitha.net**

Login with:
- **Username**: `admin`
- **Password**: (get it with the command below)

```bash
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d
echo ""
```

### Troubleshooting Domain Access

#### Issue: DNS Not Resolving

```bash
# Check DNS
nslookup argocd.techtorque.randitha.net

# If it doesn't resolve:
# 1. Verify DNS record is created
# 2. Wait 5-10 minutes for propagation
# 3. Clear your DNS cache: sudo systemd-resolve --flush-caches
```

#### Issue: Certificate Pending

```bash
# Check certificate status
kubectl describe certificate argocd-techtorque-tls -n argocd

# Common issues:
# - DNS not propagated yet (wait)
# - cert-manager not running
# - Let's Encrypt rate limit (wait 1 hour)

# Check cert-manager logs
kubectl logs -n cert-manager deployment/cert-manager
```

#### Issue: 502 Bad Gateway

```bash
# Check ArgoCD server is running
kubectl get pods -n argocd

# Check ingress
kubectl describe ingressroute argocd-https -n argocd

# Restart ArgoCD server
kubectl rollout restart deployment argocd-server -n argocd
```

#### Issue: SSL/TLS Errors

```bash
# Verify ArgoCD is in insecure mode
kubectl get configmap argocd-cmd-params-cm -n argocd -o yaml | grep insecure

# Should show: server.insecure: "true"

# If not, run:
kubectl patch configmap argocd-cmd-params-cm -n argocd \
  --type merge -p '{"data":{"server.insecure":"true"}}'

kubectl rollout restart deployment argocd-server -n argocd
```

## Option B: Port Forward (Quick Access)

For quick testing or when DNS is not available:

### Start Port Forward

```bash
kubectl port-forward svc/argocd-server -n argocd 8080:443
```

Keep this terminal open.

### Access ArgoCD

Open browser: **https://localhost:8080**

Login:
- **Username**: `admin`
- **Password**: (get with command below)

```bash
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d
echo ""
```

### Stop Port Forward

Press `Ctrl+C` in the terminal running port-forward.

## Comparison

| Feature | Domain Access | Port Forward |
|---------|--------------|--------------|
| Access from anywhere | ✅ Yes | ❌ No (localhost only) |
| HTTPS with valid cert | ✅ Yes | ⚠️ Self-signed |
| Easy to share | ✅ Yes | ❌ No |
| Permanent access | ✅ Yes | ❌ Only while running |
| DNS setup required | ✅ Yes | ❌ No |
| Setup complexity | Medium | Easy |

## Summary of Your Domains

After setup, you'll have:

| Domain | Service | Purpose |
|--------|---------|---------|
| techtorque.randitha.net | Frontend | User-facing website |
| api.techtorque.randitha.net | API Gateway | Backend API |
| argocd.techtorque.randitha.net | ArgoCD | Deployment management |

All with HTTPS via Let's Encrypt! 🔒

## Complete Setup Commands

Here's the complete process:

```bash
# 1. Install ArgoCD
cd k8s-config/argocd
sudo ./install-argocd.sh

# 2. Configure ingress
sudo ./configure-ingress.sh

# 3. Add DNS record (via Azure Portal or DNS provider)
# Type: A
# Name: argocd.techtorque.randitha
# Value: YOUR_SERVER_IP

# 4. Wait for DNS (check with)
nslookup argocd.techtorque.randitha.net

# 5. Get password
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d

# 6. Access ArgoCD
# Browser: https://argocd.techtorque.randitha.net
# Username: admin
# Password: (from step 5)
```

## Alternative: Using Azure Application Gateway

If you want to use Azure Application Gateway instead of direct access:

1. Create Application Gateway in Azure Portal
2. Add backend pool: Your server IP, port 80/443
3. Add HTTP settings
4. Add listener for argocd.techtorque.randitha.net
5. Add rule to route traffic

This adds an extra layer but provides features like WAF, SSL offloading, etc.

## Next Steps

After accessing ArgoCD:

1. **Change default password**
   ```bash
   # Login first
   argocd login argocd.techtorque.randitha.net

   # Change password
   argocd account update-password
   ```

2. **Deploy applications**
   ```bash
   # Update repository URLs in applications/*.yaml
   # Then deploy
   kubectl apply -f applications/app-of-apps.yaml
   ```

3. **Configure notifications** (optional)
   - Slack
   - Microsoft Teams
   - Email

4. **Setup SSO** (optional)
   - GitHub OAuth
   - Google
   - Azure AD

## Resources

- [Traefik IngressRoute Documentation](https://doc.traefik.io/traefik/routing/providers/kubernetes-crd/)
- [ArgoCD Ingress Documentation](https://argo-cd.readthedocs.io/en/stable/operator-manual/ingress/)
- [cert-manager Documentation](https://cert-manager.io/docs/)

---
**Access Method**: Domain-based with Traefik + Let's Encrypt
**URL**: https://argocd.techtorque.randitha.net
**Status**: Ready to configure
