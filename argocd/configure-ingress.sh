#!/bin/bash
# Configure ArgoCD to work with Traefik Ingress
# This allows access via https://argocd.techtorque.randitha.net

set -e

echo "========================================="
echo "Configure ArgoCD Ingress Access"
echo "========================================="
echo ""

# Step 1: Configure ArgoCD to run in insecure mode (Traefik handles TLS)
echo "1. Configuring ArgoCD server to run in insecure mode..."
echo "   (Traefik will handle TLS termination)"

kubectl patch configmap argocd-cmd-params-cm -n argocd \
  --type merge \
  -p '{"data":{"server.insecure":"true"}}'

# Step 2: Restart ArgoCD server to apply changes
echo ""
echo "2. Restarting ArgoCD server..."
kubectl rollout restart deployment argocd-server -n argocd

# Wait for rollout to complete
echo "   Waiting for ArgoCD server to be ready..."
kubectl rollout status deployment/argocd-server -n argocd --timeout=120s

# Step 3: Apply Ingress configuration
echo ""
echo "3. Applying Traefik IngressRoute..."
kubectl apply -f argocd-ingress.yaml

# Step 4: Wait for certificate
echo ""
echo "4. Waiting for Let's Encrypt certificate..."
echo "   This may take 1-2 minutes..."
sleep 10

# Check certificate status
for i in {1..12}; do
  CERT_STATUS=$(kubectl get certificate argocd-techtorque-tls -n argocd -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null || echo "False")

  if [ "$CERT_STATUS" = "True" ]; then
    echo "   ✅ Certificate issued successfully!"
    break
  fi

  if [ $i -eq 12 ]; then
    echo "   ⚠️  Certificate still pending (this is normal for first-time setup)"
    echo "   Check status with: kubectl describe certificate argocd-techtorque-tls -n argocd"
  else
    echo "   Waiting... ($i/12)"
    sleep 10
  fi
done

echo ""
echo "========================================="
echo "✅ ArgoCD Ingress Configuration Complete!"
echo "========================================="
echo ""
echo "Access ArgoCD at: https://argocd.techtorque.randitha.net"
echo ""
echo "Login credentials:"
echo "  Username: admin"
echo "  Password: (run the command below)"
echo ""
echo "Get password:"
echo "  kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d"
echo ""
echo "========================================="
echo "DNS Configuration Required:"
echo "========================================="
echo ""
echo "Add this DNS record to your domain registrar:"
echo "  Type: A"
echo "  Name: argocd.techtorque.randitha.net"
echo "  Value: $(curl -s ifconfig.me 2>/dev/null || echo 'YOUR_SERVER_IP')"
echo "  TTL: 300"
echo ""
echo "Or if using Azure DNS:"
echo "  Type: CNAME"
echo "  Name: argocd"
echo "  Value: techtorque.randitha.net"
echo ""
