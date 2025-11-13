#!/bin/bash

# Volcano Installation Script for K3d Cluster
# This script installs and configures Volcano scheduler with custom queues

set -e

echo "🌋 Installing Volcano Scheduler..."

# Add Volcano Helm repository
echo "📦 Adding Volcano Helm repository..."
helm repo add volcano https://volcano-sh.github.io/helm-charts
helm repo update

# Install Volcano
echo "🚀 Installing Volcano in volcano-system namespace..."
helm install volcano volcano/volcano \
  --namespace volcano-system \
  --create-namespace \
  --set basic.image.tag=v1.8.2 \
  --set basic.scheduler.replicas=1 \
  --set basic.controller.replicas=1 \
  --set basic.admission.replicas=1

# Wait for Volcano to be ready
echo "⏳ Waiting for Volcano components to be ready..."
kubectl wait --namespace volcano-system \
  --for=condition=ready pod \
  --selector=app=volcano-scheduler \
  --timeout=120s

kubectl wait --namespace volcano-system \
  --for=condition=ready pod \
  --selector=app=volcano-controller \
  --timeout=120s

kubectl wait --namespace volcano-system \
  --for=condition=ready pod \
  --selector=app=volcano-admission \
  --timeout=120s

# Verify installation
echo "✅ Volcano installation completed!"
echo ""
echo "📊 Volcano components status:"
kubectl get pods -n volcano-system

echo ""
echo "📋 Available CRDs:"
kubectl get crd | grep volcano

echo ""
echo "🎯 Next steps:"
echo "1. Create team namespaces: kubectl apply -f volcano/namespaces-volcano.yaml"
echo "2. Configure queues: kubectl apply -f volcano/volcano-queues.yaml"
echo "3. Apply RBAC: kubectl apply -f volcano/rbac-volcano-teams.yaml"
echo "4. Set resource quotas: kubectl apply -f volcano/resource-quotas-volcano.yaml"