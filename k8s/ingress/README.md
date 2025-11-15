# Ingress Configuration

This directory contains Traefik IngressRoute configurations for different environments.

## Files

### prod-ingress.yaml
Ingress configuration for the PRODUCTION environment:
- **Frontend**: `techtorque.randitha.net` → frontend-service (default namespace)
- **API**: `api.techtorque.randitha.net` → api-gateway-service (default namespace)
- Includes TLS certificates, CORS middleware, and HTTP→HTTPS redirects

### dev-ingress.yaml (on dev branch)
Ingress configuration for the DEV environment:
- **Frontend**: `dev.techtorque.randitha.net` → frontend-service (dev namespace)
- **API**: `api.dev.techtorque.randitha.net` → api-gateway-service (dev namespace)
- Includes TLS certificates, CORS middleware, and HTTP→HTTPS redirects

## Deployment

These ingress configurations are deployed via ArgoCD:
- **Production**: Managed by `techtorque-ingress-prod` ArgoCD application (from main branch)
- **Dev**: Managed by `techtorque-ingress-dev` ArgoCD application (from dev branch)

## Manual Apply (if needed)

```bash
# Apply production ingress
kubectl apply -f k8s/ingress/prod-ingress.yaml

# Apply dev ingress (on dev branch)
kubectl apply -f k8s/ingress/dev-ingress.yaml

# Verify production
kubectl get ingressroute -n default
kubectl get certificate -n default
kubectl get middleware -n default

# Verify dev
kubectl get ingressroute -n dev
kubectl get certificate -n dev
kubectl get middleware -n dev
```

## DNS Requirements

Make sure these DNS records point to your cluster IP (4.187.182.202):

**Production:**
- `techtorque.randitha.net` → 4.187.182.202
- `api.techtorque.randitha.net` → 4.187.182.202

**Dev:**
- `dev.techtorque.randitha.net` → 4.187.182.202
- `api.dev.techtorque.randitha.net` → 4.187.182.202

## TLS Certificates

Certificates are automatically provisioned by cert-manager using Let's Encrypt:

**Production:**
- `techtorque-tls` - For techtorque.randitha.net
- `api-techtorque-tls` - For api.techtorque.randitha.net

**Dev:**
- `dev-techtorque-tls` - For dev.techtorque.randitha.net
- `api-dev-techtorque-tls` - For api.dev.techtorque.randitha.net

## Migration from Manual Configuration

The production ingress was previously managed via `k8s/config/combined-ingress.yaml` and manually applied.
It has now been migrated to GitOps management via ArgoCD.

The old file is kept for reference but should not be used going forward.
