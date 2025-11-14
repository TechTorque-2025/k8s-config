# Service Discovery Fix - Quick Reference

## 🚨 What Was Wrong

1. **Missing ports in service URLs** - Services called `http://auth-service` instead of `http://auth-service:80`
2. **Wrong gRPC DNS format** - Used complex FQDN instead of simple service name
3. **Agent Bot routing through gateway** - Added unnecessary hop and latency
4. **Inconsistent service naming** - Some places had ports, others didn't

## ✅ What Was Fixed

| Component | Old Value | New Value |
|-----------|-----------|-----------|
| Gateway → Auth | `http://auth-service` | `http://auth-service:80` |
| Gateway → Vehicle | `http://vehicle-service` | `http://vehicle-service:80` |
| Gateway → All Services | Missing :80 | Added :80 to all |
| Admin → Auth | `http://auth-service` | `http://auth-service:80` |
| Auth → Notification gRPC | `dns:///notification-service-grpc.default.svc.cluster.local:9090` | `notification-service-grpc:9090` |
| Agent Bot → Services | Via gateway | Direct service calls with :80 |

## 🚀 Deploy the Fixes

```bash
cd ~/Desktop/IT/UoM/TechTorque-2025/k8s-config
./apply-service-discovery-fixes.sh
```

This script will:
1. ✅ Backup current configurations
2. ✅ Apply all ConfigMap updates
3. ✅ Apply all Deployment updates
4. ✅ Restart affected pods
5. ✅ Wait for rollouts to complete
6. ✅ Run connectivity tests
7. ✅ Check logs for errors

## 🔍 Verify the Fixes

```bash
cd ~/Desktop/IT/UoM/TechTorque-2025/k8s-config
./verify-service-discovery.sh
```

This will check:
- ✅ All services exist and are properly configured
- ✅ ConfigMaps have correct values
- ✅ Pods have correct environment variables
- ✅ DNS resolution works
- ✅ HTTP connectivity works
- ✅ No connection errors in logs

## 📊 Expected Results

### Before Fix:
```
Browser → API → Service ✅ Works (has ports)
Service → Service ❌ Fails (no ports)
Auth → Notification gRPC ❌ Fails (wrong DNS)
Agent Bot → Services ❌ Fails (wrong routing)
```

### After Fix:
```
Browser → API → Service ✅ Works
Service → Service ✅ Works (explicit ports)
Auth → Notification gRPC ✅ Works (simple DNS)
Agent Bot → Services ✅ Works (direct calls)
```

## 🔧 Manual Commands (if needed)

### Apply individual fixes:
```bash
# Fix gateway
kubectl apply -f k8s/services/gateway-deployment.yaml
kubectl rollout restart deployment api-gateway-deployment

# Fix admin
kubectl apply -f k8s/services/admin-deployment.yaml
kubectl rollout restart deployment admin-deployment

# Fix auth gRPC
kubectl apply -f k8s/configmaps/auth-configmap.yaml
kubectl rollout restart deployment auth-deployment

# Fix agent bot
kubectl apply -f k8s/configmaps/agent-bot-configmap.yaml
kubectl rollout restart deployment agent-bot-deployment
```

### Check service URLs:
```bash
# Check gateway env vars
kubectl exec deployment/api-gateway-deployment -- env | grep SERVICE_URL

# Check agent bot env vars
kubectl exec deployment/agent-bot-deployment -- env | grep SERVICE_URL

# Check admin env vars
kubectl exec deployment/admin-deployment -- env | grep AUTH_SERVICE_URL
```

### Test connectivity:
```bash
# Get a pod to test from
POD=$(kubectl get pods -l app=api-gateway -o jsonpath='{.items[0].metadata.name}')

# Test DNS
kubectl exec $POD -- nslookup auth-service
kubectl exec $POD -- nslookup notification-service-grpc

# Test HTTP
kubectl exec $POD -- curl -v http://auth-service:80/health
kubectl exec $POD -- curl -v http://vehicle-service:80/health
```

### Check logs:
```bash
# Gateway logs
kubectl logs -f deployment/api-gateway-deployment

# Auth logs (check gRPC connection)
kubectl logs -f deployment/auth-deployment | grep -i grpc

# Agent bot logs
kubectl logs -f deployment/agent-bot-deployment
```

## 🔄 Rollback (if needed)

```bash
cd ~/Desktop/IT/UoM/TechTorque-2025/k8s-config

# Find your backup directory
ls -la | grep backup-

# Restore from backup
kubectl apply -f backup-YYYYMMDD-HHMMSS/auth-config-backup.yaml
kubectl apply -f backup-YYYYMMDD-HHMMSS/agent-bot-config-backup.yaml
kubectl apply -f backup-YYYYMMDD-HHMMSS/gateway-deployment-backup.yaml
kubectl apply -f backup-YYYYMMDD-HHMMSS/admin-deployment-backup.yaml

# Restart pods
kubectl rollout restart deployment api-gateway-deployment
kubectl rollout restart deployment admin-deployment
kubectl rollout restart deployment auth-deployment
kubectl rollout restart deployment agent-bot-deployment
```

## 📝 Files Modified

1. `k8s/services/gateway-deployment.yaml` - Added :80 to all 9 service URLs
2. `k8s/services/admin-deployment.yaml` - Added :80 to AUTH_SERVICE_URL
3. `k8s/configmaps/auth-configmap.yaml` - Simplified gRPC target
4. `k8s/configmaps/agent-bot-configmap.yaml` - Changed to direct service calls

## 🎯 Success Criteria

- [ ] All pods are Running
- [ ] No "connection refused" errors in logs
- [ ] DNS resolution works for all services
- [ ] HTTP requests between services succeed
- [ ] gRPC connection from auth to notification works
- [ ] Agent bot can call services directly
- [ ] Frontend can access APIs through gateway
- [ ] User registration works (tests auth + notification)
- [ ] Appointments can be created (tests multiple services)

## 💡 Why This Matters

1. **Explicit ports = reliable connections** - No guessing, no defaults
2. **Simple DNS = faster resolution** - Less DNS queries, faster responses
3. **Direct calls = lower latency** - No unnecessary hops through gateway
4. **Consistent patterns = easier debugging** - Same format everywhere

## 📞 Support

If issues persist after applying fixes:

1. Check cluster status: `kubectl get nodes`
2. Check CoreDNS: `kubectl get pods -n kube-system -l k8s-app=kube-dns`
3. Check service endpoints: `kubectl get endpoints`
4. Check network policies: `kubectl get networkpolicies`
5. Review full logs: `kubectl logs deployment/<name> --previous` (if pod crashed)

For detailed documentation, see: `SERVICE_DISCOVERY_FIX.md`
