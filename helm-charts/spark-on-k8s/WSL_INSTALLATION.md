# WSL Installation Guide

## Problem

When using Windows Helm from WSL, you get:

```bash
$ helm install spark-platform . -n spark-operator --create-namespace
Error: INSTALLATION FAILED: Chart.yaml file is missing
```

This happens because you're using Windows Helm (`/c/ProgramData/chocolatey/bin/helm`) from within WSL, and it cannot read files properly in the `/mnt/c/` path.

## Solution: Use install-wsl.sh Script

We've created a bash script that works around this issue by using a temporary directory:

```bash
cd /mnt/c/Users/mokhtar/WS/data-platform-with-k8s/spark-operators-on-k8s/helm-charts/spark-on-k8s

# Install development environment
./install-wsl.sh dev

# Install production environment
./install-wsl.sh prod

# With custom configuration
./install-wsl.sh prod my-spark-release my-namespace
```

### What the Script Does

1. **Copies files** to `/tmp` (a native Linux path)
2. **Adds Helm repositories** automatically
3. **Builds dependencies** in the temp location
4. **Validates the chart**
5. **Installs/upgrades** using Windows Helm (but from a path it can read)
6. **Cleans up** temporary files

## Quick Start

```bash
# Navigate to chart directory
cd /mnt/c/Users/mokhtar/WS/data-platform-with-k8s/spark-operators-on-k8s/helm-charts/spark-on-k8s

# Install production
./install-wsl.sh prod

# Or development
./install-wsl.sh dev
```

## Why This Works

The script copies files to `/tmp` which is a native Linux filesystem path. Windows Helm can properly resolve and read files from there, unlike files in `/mnt/c/...` which is a Windows mount.

## Verification

After installation:

```bash
# Check release
helm list -n spark-operator

# Check pods
kubectl get pods -n spark-operator

# For production (Volcano enabled)
kubectl get pods -n volcano-system

# Check team namespaces
kubectl get namespaces | grep team-

# Check resource quotas
kubectl describe quota -A | grep -A5 "team-"
```

## Alternative: Install Native WSL Helm

If you want to avoid using Windows Helm entirely, you would need to:

1. **Enable sudo in WSL**:
   - Go to Windows Settings → Developer Settings
   - Enable "Linux subsystem"

2. **Install Helm natively**:
   ```bash
   curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
   ```

However, this requires admin privileges which are currently disabled in your WSL environment.

## Troubleshooting

### Issue: Script permission denied

```bash
chmod +x install-wsl.sh
./install-wsl.sh prod
```

### Issue: kubectl not found

```bash
# Configure KUBECONFIG
export KUBECONFIG="/mnt/c/Users/mokhtar/.kube/config"

# Add to ~/.bashrc to make permanent
echo 'export KUBECONFIG="/mnt/c/Users/mokhtar/.kube/config"' >> ~/.bashrc
```

### Issue: Helm repositories not accessible

```bash
# Check network connectivity
curl -I https://kubeflow.github.io/spark-operator

# If behind proxy, configure:
export HTTP_PROXY="http://your-proxy:port"
export HTTPS_PROXY="http://your-proxy:port"
```

### Issue: Temporary directory full

```bash
# Clean up /tmp
rm -rf /tmp/tmp.*

# Or specify different temp location
export TMPDIR="/mnt/c/temp"
mkdir -p $TMPDIR
./install-wsl.sh prod
```

## Using Makefile

The Makefile commands won't work correctly with Windows Helm from WSL. Use the install script instead:

```bash
# Instead of: make install-prod
./install-wsl.sh prod

# Instead of: make install-dev
./install-wsl.sh dev
```

## Environment Variables

Ensure these are set:

```bash
# Check KUBECONFIG
echo $KUBECONFIG
# Should show: /mnt/c/Users/mokhtar/.kube/config

# If not set:
export KUBECONFIG="/mnt/c/Users/mokhtar/.kube/config"

# Make permanent
echo 'export KUBECONFIG="/mnt/c/Users/mokhtar/.kube/config"' >> ~/.bashrc
source ~/.bashrc
```

## Summary

| Method | Works in WSL? | Recommended |
|--------|---------------|-------------|
| **install-wsl.sh** | ✅ Yes | ✅ **YES** |
| Direct helm commands | ❌ No (path issues) | ❌ No |
| Windows Helm from PowerShell | ✅ Yes | ⚠️ Use install-windows.ps1 |
| Native WSL Helm | ⚠️ Requires sudo | ⚠️ If enabled |

**For WSL users**: Use `./install-wsl.sh prod` - it's designed specifically for this scenario!

## Complete Example

```bash
# 1. Navigate to chart directory
cd /mnt/c/Users/mokhtar/WS/data-platform-with-k8s/spark-operators-on-k8s/helm-charts/spark-on-k8s

# 2. Ensure script is executable
chmod +x install-wsl.sh

# 3. Run installation
./install-wsl.sh prod

# 4. Verify
helm list -n spark-operator
kubectl get pods -n spark-operator
kubectl get pods -n volcano-system
kubectl get namespaces | grep team-

# 5. Check status
helm status spark-platform -n spark-operator
```

That's it! The script handles all the path complexities for you.
