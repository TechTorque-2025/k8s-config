# HPA Setup for K3s

This guide covers deploying HPA in K3s environments, which has some differences from standard Kubernetes.

## K3s Advantages for HPA

✅ **Metrics Server Included** - K3s bundles metrics-server by default
✅ **Lightweight** - Optimized for resource-constrained environments
✅ **Full HPA Support** - All autoscaling features work out of the box

## Pre-Deployment Checklist

### 1. Verify Metrics Server
K3s includes metrics-server, but confirm it's running:

```bash
# Check metrics-server deployment
kubectl get deployment metrics-server -n kube-system

# Verify metrics are available
kubectl top nodes
kubectl top pods -n default
```

If `kubectl top` commands fail, metrics-server needs troubleshooting (see below).

### 2. Check Node Resources
Verify your K3s node(s) have sufficient capacity:

```bash
# View node resources
kubectl top nodes
kubectl describe nodes | grep -A 5 "Allocated resources"

# Check available capacity
kubectl get nodes -o custom-columns=NAME:.metadata.name,CPU:.status.capacity.cpu,MEMORY:.status.capacity.memory
```

**Minimum Recommended Resources:**
- **Single Node**: 4 CPU cores, 8GB RAM (for all services at min replicas)
- **Production**: 8 CPU cores, 16GB RAM (to allow scaling)

### 3. Calculate Maximum Resource Usage
With HPA at max scale:
- **Memory**: ~15-20GB total
- **CPU**: ~10-15 cores total
- **Pods**: ~40 maximum

Ensure your K3s cluster can handle this, or adjust `maxReplicas` in HPA config.

## Deployment Steps

### Step 1: Verify/Fix Metrics Server

**Check if metrics work:**
```bash
kubectl top nodes
```

**If you get certificate errors**, patch metrics-server:
```bash
kubectl patch deployment metrics-server -n kube-system --type='json' \
  -p='[{"op": "add", "path": "/spec/template/spec/containers/0/args/-", "value": "--kubelet-insecure-tls"}]'

# Wait for metrics-server to restart
kubectl rollout status deployment/metrics-server -n kube-system

# Test again
kubectl top nodes
```

### Step 2: Apply Updated Deployments
```bash
# Apply all service deployments with resource limits
kubectl apply -f k8s-config/k8s/services/

# Verify deployments
kubectl get deployments
kubectl get pods
```

### Step 3: Deploy HPA Configuration
```bash
# Apply HPA for all services
kubectl apply -f k8s-config/k8s/autoscaling/hpa.yaml

# Verify HPAs are created
kubectl get hpa
```

### Step 4: Verify HPA Status
```bash
# Check HPA status (wait 1-2 minutes for metrics to populate)
kubectl get hpa

# Expected output:
# NAME                        REFERENCE                          TARGETS         MINPODS   MAXPODS   REPLICAS
# auth-service-hpa           Deployment/auth-deployment         5%/70%, 10%/80%   1         5         1
# api-gateway-hpa            Deployment/api-gateway-deployment  3%/70%, 8%/80%    1         8         1
# ...

# If TARGETS shows "<unknown>/70%", wait for metrics to populate
```

## Troubleshooting K3s-Specific Issues

### Issue 1: HPA Shows `<unknown>` Targets

**Symptom:**
```bash
kubectl get hpa
# TARGETS shows: <unknown>/70%
```

**Solution:**
```bash
# 1. Check if metrics-server is running
kubectl get pods -n kube-system | grep metrics-server

# 2. Check metrics-server logs
kubectl logs -n kube-system deployment/metrics-server

# 3. If certificate errors, apply insecure TLS patch
kubectl patch deployment metrics-server -n kube-system --type='json' \
  -p='[{"op": "add", "path": "/spec/template/spec/containers/0/args/-", "value": "--kubelet-insecure-tls"}]'

# 4. Wait and verify
sleep 30
kubectl top pods
```

### Issue 2: Metrics Server CrashLoopBackOff

**Symptom:**
```bash
kubectl get pods -n kube-system
# metrics-server pod shows CrashLoopBackOff
```

**Solution:**
```bash
# Check logs
kubectl logs -n kube-system deployment/metrics-server

# Common fix: Add kubelet-preferred-address-types
kubectl patch deployment metrics-server -n kube-system --type='json' \
  -p='[
    {"op": "add", "path": "/spec/template/spec/containers/0/args/-", "value": "--kubelet-insecure-tls"},
    {"op": "add", "path": "/spec/template/spec/containers/0/args/-", "value": "--kubelet-preferred-address-types=InternalIP,ExternalIP,Hostname"}
  ]'
```

### Issue 3: Pods Not Scaling Due to Resource Limits

**Symptom:**
- HPA shows desired replicas > current replicas
- Pods in Pending state

**Solution:**
```bash
# Check pod status
kubectl get pods

# Describe pending pods
kubectl describe pod <pending-pod-name>

# Check node resources
kubectl top nodes
kubectl describe nodes | grep -A 5 "Allocated resources"

# If insufficient resources, either:
# A) Add more nodes to K3s cluster
# B) Reduce maxReplicas in HPA
# C) Reduce resource requests in deployments
```

### Issue 4: K3s Single-Node Resource Exhaustion

**Symptom:**
- Node runs out of resources
- Pods get evicted
- System becomes unstable

**Solution - Reduce HPA Limits:**
```bash
# Edit HPA to reduce maxReplicas
kubectl edit hpa auth-service-hpa
# Change maxReplicas from 5 to 3 (or 2)

# Or apply a custom HPA config with lower limits
# Edit k8s-config/k8s/autoscaling/hpa.yaml
# Reduce maxReplicas values, then:
kubectl apply -f k8s-config/k8s/autoscaling/hpa.yaml
```

## K3s-Optimized HPA Configuration

For **single-node K3s** with limited resources (4 cores, 8GB RAM), consider these adjustments:

```yaml
# Reduced maxReplicas for resource-constrained environments
# Edit hpa.yaml and change:

# Backend services: maxReplicas: 5 → 2
# API Gateway: maxReplicas: 8 → 3
# Frontend: maxReplicas: 6 → 3
# Agent Bot: maxReplicas: 4 → 2
```

Apply with:
```bash
kubectl apply -f k8s-config/k8s/autoscaling/hpa.yaml
```

## Monitoring and Verification

### Real-Time Monitoring
```bash
# Watch HPA status
watch kubectl get hpa

# Watch pod scaling
watch kubectl get pods

# Monitor resource usage
watch kubectl top pods
watch kubectl top nodes
```

### Load Testing
Test autoscaling by generating load:

```bash
# Install hey (HTTP load generator)
# On Ubuntu/Debian:
sudo apt-get install hey

# Generate load (adjust URL to your service)
hey -z 5m -c 50 https://your-domain.com/

# In another terminal, watch scaling:
watch kubectl get hpa
watch kubectl get pods
```

### Check Scaling Events
```bash
# View HPA events
kubectl describe hpa auth-service-hpa

# View recent events across all HPAs
kubectl get events --sort-by='.lastTimestamp' | grep -i horizontalpodautoscaler
```

## Performance Tuning for K3s

### 1. Adjust Resource Requests (if needed)
If services are over-provisioned:

```bash
# Reduce requests in deployment files
# Example: Change from 256Mi to 128Mi for lighter services
# Edit k8s-config/k8s/services/*.yaml
# Then apply:
kubectl apply -f k8s-config/k8s/services/
```

### 2. Tune HPA Thresholds
If scaling too aggressively or not enough:

```bash
# Edit HPA configuration
kubectl edit hpa <hpa-name>

# Adjust CPU/memory thresholds:
# - Increase thresholds (e.g., 70% → 80%) to scale less aggressively
# - Decrease thresholds (e.g., 70% → 60%) to scale more proactively
```

### 3. Adjust Scaling Behavior
```bash
# Edit stabilization windows if scaling is too fast/slow
kubectl edit hpa <hpa-name>

# scaleDown.stabilizationWindowSeconds: 300 → 600 (slower scale-down)
# scaleUp.stabilizationWindowSeconds: 0 → 30 (slower scale-up)
```

## K3s Multi-Node Considerations

If running K3s with multiple nodes:

### 1. Enable Pod Affinity (Optional)
Spread replicas across nodes for better availability:

```yaml
# Add to deployment spec.template.spec:
affinity:
  podAntiAffinity:
    preferredDuringSchedulingIgnoredDuringExecution:
    - weight: 100
      podAffinityTerm:
        labelSelector:
          matchExpressions:
          - key: app
            operator: In
            values:
            - <service-name>
        topologyKey: kubernetes.io/hostname
```

### 2. Check Node Distribution
```bash
# View which pods are on which nodes
kubectl get pods -o wide
```

## Production Best Practices for K3s

1. **Start Conservative**
   - Deploy with current HPA settings
   - Monitor for 24-48 hours
   - Adjust based on actual usage

2. **Set Resource Limits**
   - Always define requests and limits (already done ✓)
   - This prevents resource starvation

3. **Monitor Metrics**
   - Use `kubectl top` regularly
   - Set up alerts for node resource usage
   - Consider Prometheus + Grafana for better visibility

4. **Plan for Growth**
   - Ensure you can add K3s nodes if needed
   - Document your resource limits
   - Review and adjust HPA settings monthly

5. **Test Scaling**
   - Perform load tests before production
   - Verify scale-up and scale-down work correctly
   - Ensure node can handle max replicas

## Quick Reference Commands

```bash
# Check HPA status
kubectl get hpa

# View current resource usage
kubectl top pods
kubectl top nodes

# Describe HPA (shows events and status)
kubectl describe hpa <hpa-name>

# Manually scale (for testing)
kubectl scale deployment <deployment-name> --replicas=3

# View metrics-server logs
kubectl logs -n kube-system deployment/metrics-server

# Restart metrics-server
kubectl rollout restart deployment/metrics-server -n kube-system

# Delete HPA (disables autoscaling)
kubectl delete hpa <hpa-name>

# Reapply HPA
kubectl apply -f k8s-config/k8s/autoscaling/hpa.yaml
```

## Support and Resources

- [K3s Documentation](https://docs.k3s.io/)
- [K3s Metrics Server](https://docs.k3s.io/installation/packaged-components#metrics-server)
- [Kubernetes HPA](https://kubernetes.io/docs/tasks/run-application/horizontal-pod-autoscale/)
- [Troubleshooting K3s](https://docs.k3s.io/known-issues)

## Summary

Your HPA configuration is **fully compatible with K3s**. The main differences are:
1. ✅ Metrics-server is pre-installed (but may need TLS patch)
2. ⚠️ Resource constraints may require lower `maxReplicas`
3. ✅ All HPA features work identically to standard Kubernetes

Deploy with confidence, monitor initially, and adjust as needed based on your K3s cluster capacity!
