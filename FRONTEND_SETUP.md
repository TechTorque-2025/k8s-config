# Frontend K8S Setup - Quick Reference

## Files Added

### ConfigMaps
- `k8s/configmaps/frontend-configmap.yaml` - Environment variables for Next.js

### Services
- `k8s/services/frontend-deployment.yaml` - Frontend deployment with 2 replicas and ClusterIP service

### Ingress
- `k8s/config/combined-ingress.yaml` - Updated with:
  - Certificate for techtorque.randitha.net
  - HTTPS IngressRoute for frontend
  - HTTP to HTTPS redirect for frontend

## Quick Deploy

```bash
# Apply all frontend resources
kubectl apply -f k8s/configmaps/frontend-configmap.yaml
kubectl apply -f k8s/services/frontend-deployment.yaml
kubectl apply -f k8s/config/combined-ingress.yaml

# Check status
kubectl get pods -l app=frontend
kubectl get svc frontend-service
kubectl get certificate techtorque-tls
```

## DNS Configuration

Ensure DNS is configured:
- `techtorque.randitha.net` → Your K3S cluster IP
- `api.techtorque.randitha.net` → Same K3S cluster IP

## Architecture

- **Frontend:** `techtorque.randitha.net` → frontend-service:80 → Next.js:3000
- **Backend:** `api.techtorque.randitha.net` → api-gateway-service:80 → API Gateway:8080

Both use HTTPS with Let's Encrypt certificates via cert-manager.

## CI/CD

Frontend deployment is automated via GitHub Actions in the Frontend_Web repository:
1. Push to main → Build & Test → Docker Image pushed to GHCR
2. Deploy workflow → Updates K8S deployment with new image tag

See `FRONTEND_K8S_MIGRATION.md` for full details.
