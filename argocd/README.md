# ArgoCD Deployment on K3d

## Prerequisites

1. **Docker Desktop** must be running
2. **K3d cluster** must be created and running

## Setup Steps

### 1. Start Docker Desktop
Ensure Docker Desktop is running on your Windows machine.

### 2. Create K3d Cluster (if not exists)
```bash
cd cluster
k3d cluster create -c k3d-config.yaml
```

### 3. Set KUBECONFIG
```bash
export KUBECONFIG="~/.kube/config"
```

### 4. Install ArgoCD
```bash
cd argocd
./install-argocd.sh
```

## Access Methods

### Method 1: NodePort (Direct Access)
Access ArgoCD at: https://localhost:30443

### Method 2: Port Forwarding
```bash
kubectl port-forward svc/argocd-server -n argocd 8080:443
```
Then access at: https://localhost:8080


## Login Credentials

- **Username**: admin
- **Password**: Run the following command to get the initial password:
  ```bash
  kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
  ```

## Files Included

- `argocd-deployment.yaml`: Contains namespace, services, ingress, and network policies
- `install-argocd.sh`: Installation script for ArgoCD
- `README.md`: This documentation file

## Features

- **External Access**: Configured with NodePort, Ingress, and LoadBalancer options
- **Network Policy**: Allows controlled access to ArgoCD server
- **Ingress Configuration**: Pre-configured for NGINX ingress controller with SSL/TLS
- **Security**: HTTPS/gRPC enabled with proper backend protocols

## Troubleshooting

### Cluster Not Running
```bash
# Check cluster status
k3d cluster list

# Start cluster if stopped
k3d cluster start <cluster-name>
```

### Cannot Access ArgoCD
1. Verify pods are running:
   ```bash
   kubectl get pods -n argocd
   ```
2. Check service status:
   ```bash
   kubectl get svc -n argocd
   ```
3. View logs:
   ```bash
   kubectl logs -n argocd deployment/argocd-server
   ```

### Reset Admin Password
```bash
# Delete the initial admin secret to regenerate
kubectl delete secret argocd-initial-admin-secret -n argocd
kubectl rollout restart deployment argocd-server -n argocd
```