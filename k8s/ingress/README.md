# Ingress Configuration

This directory contains Traefik IngressRoute configurations for different environments.

## Files

### dev-ingress.yaml
Ingress configuration for the DEV environment:
- **Frontend**: `dev.techtorque.randitha.net` → frontend-service (dev namespace)
- **API**: `api.dev.techtorque.randitha.net` → api-gateway-service (dev namespace)
- Includes TLS certificates, CORS middleware, and HTTP→HTTPS redirects

## Deployment

These ingress configurations are deployed via ArgoCD:
- **Dev**: Managed by `techtorque-ingress-dev` ArgoCD application
- **Prod**: Managed by `k8s/config/combined-ingress.yaml` (manually applied)

## Manual Apply (if needed)

```bash
# Apply dev ingress
kubectl apply -f k8s/ingress/dev-ingress.yaml

# Verify
kubectl get ingressroute -n dev
kubectl get certificate -n dev
kubectl get middleware -n dev
```

## DNS Requirements

Make sure these DNS records point to your cluster:
- `dev.techtorque.randitha.net` → Your cluster IP (4.187.182.202)
- `api.dev.techtorque.randitha.net` → Your cluster IP (4.187.182.202)

## TLS Certificates

Certificates are automatically provisioned by cert-manager using Let's Encrypt:
- `dev-techtorque-tls` - For dev.techtorque.randitha.net
- `api-dev-techtorque-tls` - For api.dev.techtorque.randitha.net
