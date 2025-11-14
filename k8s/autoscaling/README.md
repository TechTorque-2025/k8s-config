# Horizontal Pod Autoscaler (HPA) Configuration

This directory contains the HPA configuration for all TechTorque services, optimized for low resource usage during idle periods with automatic scaling under load.

## Overview

The HPA configuration automatically scales pods based on CPU and memory utilization, ensuring:
- Minimal resource consumption during idle periods
- Rapid scaling up when load increases
- Cost-effective operation
- High availability under load

## Configuration Summary

### Backend Services
All backend microservices (auth, vehicle, project, appointment, payment, admin, time-logging, notification) are configured with:
- **Min Replicas**: 1 (idle state)
- **Max Replicas**: 3-6 (depending on service)
- **CPU Threshold**: 70% utilization
- **Memory Threshold**: 80% utilization

### API Gateway
- **Min Replicas**: 1
- **Max Replicas**: 8
- **CPU Threshold**: 70%
- **Memory Threshold**: 80%

### Frontend
- **Min Replicas**: 2 (for better availability)
- **Max Replicas**: 6
- **CPU Threshold**: 70%
- **Memory Threshold**: 75%

### Agent Bot Service
- **Min Replicas**: 1
- **Max Replicas**: 4
- **CPU Threshold**: 75% (higher for AI workload)
- **Memory Threshold**: 80%

## Scaling Behavior

### Scale Up
- **Stabilization Window**: 0 seconds (immediate scaling)
- **Policies**:
  - Double pods (100% increase) every 30 seconds, OR
  - Add 2 pods every 30 seconds
  - Whichever is faster (selectPolicy: Max)

### Scale Down
- **Stabilization Window**: 300 seconds (5 minutes)
- **Policy**: Remove 1 pod per minute maximum
- Prevents flapping and ensures stability

## Resource Requirements

Each service deployment has been configured with resource requests and limits:

**Java Services** (auth, vehicle, project, appointment, payment, admin, time-logging, notification):
- Requests: 256Mi memory, 200m CPU
- Limits: 512Mi memory, 500m CPU

**API Gateway** (Go):
- Requests: 128Mi memory, 100m CPU
- Limits: 256Mi memory, 300m CPU

**Frontend** (Next.js):
- Requests: 256Mi memory, 200m CPU
- Limits: 512Mi memory, 500m CPU

**Agent Bot** (Python/FastAPI):
- Requests: 512Mi memory, 250m CPU
- Limits: 1Gi memory, 500m CPU

## Prerequisites

1. **Metrics Server**: Must be installed in your cluster
   ```bash
   kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
   ```

2. **Resource Limits**: All pods must have resource requests/limits defined (already configured)

## Deployment

### Apply HPA Configuration
```bash
kubectl apply -f k8s-config/k8s/autoscaling/hpa.yaml
```

### Verify HPA Status
```bash
# Check all HPAs
kubectl get hpa

# Check specific HPA
kubectl get hpa auth-service-hpa -o yaml

# Watch HPA in real-time
kubectl get hpa --watch
```

### Check Metrics
```bash
# View current resource usage
kubectl top pods

# View node resource usage
kubectl top nodes
```

## Monitoring

### Check Current Replica Counts
```bash
kubectl get deployments
```

### View HPA Events
```bash
kubectl describe hpa <hpa-name>
```

### Monitor Scaling Activity
```bash
# Watch deployments for scaling
kubectl get deployments --watch

# View HPA status continuously
watch kubectl get hpa
```

## Troubleshooting

### HPA Not Scaling

1. **Check Metrics Server**
   ```bash
   kubectl get deployment metrics-server -n kube-system
   kubectl logs -n kube-system deployment/metrics-server
   ```

2. **Verify Resource Metrics Available**
   ```bash
   kubectl top pods
   ```
   If this fails, metrics-server is not working properly.

3. **Check HPA Status**
   ```bash
   kubectl describe hpa <hpa-name>
   ```
   Look for error messages in events.

4. **Verify Resource Requests Are Set**
   ```bash
   kubectl get pod <pod-name> -o yaml | grep -A 5 resources
   ```

### Pods Not Scaling Down

- Scale down has a 5-minute stabilization window by design
- Check if CPU/memory is genuinely low with `kubectl top pods`
- Verify min replicas setting in HPA config

### Excessive Scaling (Flapping)

- Adjust stabilization windows in HPA config
- Increase scale-down period
- Adjust CPU/memory thresholds

## Cost Optimization

With this configuration:
- **Idle State**: 11 total pods (9 backend services + 1 gateway + 2 frontend = ~52% reduction from previous 21 pods)
- **Under Load**: Automatically scales up to handle traffic
- **Savings**: Significant reduction in resource usage during off-peak hours

## Testing Autoscaling

### Simulate Load (CPU stress)
```bash
# Install stress tool in a pod
kubectl run -i --tty load-generator --rm --image=busybox --restart=Never -- /bin/sh

# Inside the pod, generate requests to your service
while true; do wget -q -O- http://auth-service/health; done
```

### Monitor Scaling
```bash
# In another terminal
kubectl get hpa --watch
kubectl get pods --watch
```

## Best Practices

1. **Monitor Initially**: Watch HPA behavior closely after deployment
2. **Adjust Thresholds**: Fine-tune CPU/memory thresholds based on actual usage patterns
3. **Set Appropriate Limits**: Ensure maxReplicas can handle peak load
4. **Cost vs Performance**: Balance min replicas with availability requirements
5. **Regular Review**: Periodically review and optimize based on usage patterns

## Maintenance

### Update HPA Configuration
1. Edit `hpa.yaml`
2. Apply changes: `kubectl apply -f k8s-config/k8s/autoscaling/hpa.yaml`
3. Verify: `kubectl get hpa`

### Disable HPA Temporarily
```bash
kubectl delete hpa <hpa-name>
```

### Re-enable HPA
```bash
kubectl apply -f k8s-config/k8s/autoscaling/hpa.yaml
```

## Additional Resources

- [Kubernetes HPA Documentation](https://kubernetes.io/docs/tasks/run-application/horizontal-pod-autoscale/)
- [HPA Walkthrough](https://kubernetes.io/docs/tasks/run-application/horizontal-pod-autoscale-walkthrough/)
- [Metrics Server](https://github.com/kubernetes-sigs/metrics-server)
