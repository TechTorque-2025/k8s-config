#!/bin/bash
# ArgoCD Installation Script for K3s
# This script installs ArgoCD on your K3s cluster

set -e

echo "========================================="
echo "ArgoCD Installation for TechTorque K3s"
echo "========================================="
echo ""

# Create ArgoCD namespace
echo "1. Creating argocd namespace..."
kubectl create namespace argocd 2>/dev/null || echo "Namespace argocd already exists"

# Install ArgoCD
echo "2. Installing ArgoCD..."
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Wait for ArgoCD to be ready
echo "3. Waiting for ArgoCD components to be ready..."
kubectl wait --for=condition=available --timeout=300s deployment/argocd-server -n argocd

echo ""
echo "✅ ArgoCD installed successfully!"
echo ""
echo "========================================="
echo "Setup Options:"
echo "========================================="
echo ""
echo "Choose how to access ArgoCD:"
echo ""
echo "Option A - Domain Access (Recommended for Production):"
echo "  Run: ./configure-ingress.sh"
echo "  Then access at: https://argocd.techtorque.randitha.net"
echo "  (Requires DNS configuration)"
echo ""
echo "Option B - Port Forward (Quick Testing):"
echo "  Run: kubectl port-forward svc/argocd-server -n argocd 8080:443"
echo "  Then access at: https://localhost:8080"
echo ""
echo "========================================="
echo "Get Admin Password:"
echo "========================================="
echo ""
echo "kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d"
echo ""
echo "Username: admin"
echo ""
echo "========================================="
echo "Optional - Install ArgoCD CLI:"
echo "========================================="
echo ""
echo "curl -sSL -o argocd https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64"
echo "sudo install -m 555 argocd /usr/local/bin/argocd"
echo ""
