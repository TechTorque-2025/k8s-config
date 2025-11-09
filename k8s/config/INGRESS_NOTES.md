# Ingress Configuration Notes

## Current Active Configuration

**File:** `k8s/config/combined-ingress.yaml`

This is the single source of truth for all ingress routing.

### What it includes:

1. **Certificates:**
   - `techtorque-tls` - For frontend (techtorque.randitha.net)
   - `api-techtorque-tls` - For backend API (api.techtorque.randitha.net)

2. **Middlewares:**
   - `cors-headers` - CORS configuration for API
   - `redirect-to-https` - HTTP to HTTPS redirect

3. **IngressRoutes:**
   - `frontend-http-redirect` - HTTP → HTTPS for frontend
   - `frontend-https` - HTTPS routing for frontend
   - `api-http-redirect` - HTTP → HTTPS for API
   - `api-https` - HTTPS routing for API with CORS

### Routes:

```
http://techtorque.randitha.net → https://techtorque.randitha.net → frontend-service:80
https://techtorque.randitha.net → frontend-service:80 → Next.js:3000

http://api.techtorque.randitha.net → https://api.techtorque.randitha.net → api-gateway-service:80
https://api.techtorque.randitha.net → api-gateway-service:80 → API Gateway:8080
```

## Deprecated Files

- `api-ingress.yaml.deprecated` - Old API-only configuration (superseded by combined-ingress.yaml)

## Apply Configuration

```bash
kubectl apply -f k8s/config/combined-ingress.yaml
```

## Verify

```bash
kubectl get certificate
kubectl get middleware
kubectl get ingressroute
```

## CORS Configuration

The `cors-headers` middleware allows requests from:
- `http://localhost:3000` (local development)
- `https://techtorque.vercel.app` (if still needed)
- `https://techtorque.randitha.net` (production frontend)

**Note:** Once fully migrated from Vercel, you can remove the Vercel URL from the CORS allow list.
