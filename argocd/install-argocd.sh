#!/bin/bash

echo "Installing ArgoCD on Kubernetes cluster..."

# Create namespace
kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -

# Install ArgoCD using the official manifests
echo "Deploying ArgoCD components..."
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Wait for ArgoCD to be ready
echo "Waiting for ArgoCD pods to be ready..."
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=argocd-server -n argocd --timeout=300s

# Apply custom configuration for external access
echo "Applying external access configuration..."
kubectl apply -f argocd-deployment.yaml

# Patch ArgoCD server service to use LoadBalancer/NodePort
echo "Patching ArgoCD server service for external access..."
kubectl patch svc argocd-server -n argocd -p '{"spec": {"type": "LoadBalancer"}}'

# For k3d, we need to expose the service through the load balancer
# The k3d config already maps ports 8080:80 and 8443:443

# Get the initial admin password
echo ""
echo "==================================="
echo "ArgoCD Installation Complete!"
echo "==================================="
echo ""
echo "ArgoCD admin password:"
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
echo ""
echo ""
echo "Access ArgoCD:"
echo ""
echo "1. Via LoadBalancer (Recommended for k3d):"
EXTERNAL_IP=$(kubectl get svc argocd-server -n argocd -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
if [ -n "$EXTERNAL_IP" ]; then
  echo "   https://$EXTERNAL_IP"
else
  echo "   Waiting for LoadBalancer IP... (run: kubectl get svc argocd-server -n argocd)"
fi
echo ""
echo "2. Via Port-forward (Alternative):"
echo "   kubectl port-forward svc/argocd-server -n argocd 8080:443"
echo "   Then access: https://localhost:8080"
echo ""
echo "3. Via Ingress (Requires ingress controller + hosts file):"
echo "   Add '127.0.0.1 argocd.local' to /etc/hosts or C:\\Windows\\System32\\drivers\\etc\\hosts"
echo "   Then access: https://argocd.local"
echo ""
echo "Login with:"
echo "- Username: admin"
echo "- Password: (shown above)"
echo ""
echo "To change the admin password after first login:"
echo "argocd account update-password"