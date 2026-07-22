#!/bin/sh
# Custom k3d entrypoint script that starts NFS client services.
# k3d runs all /bin/k3d-entrypoint-*.sh scripts before starting k3s,
# so this script must start the services and return (no exec).
# Starts rpcbind directly (OpenRC doesn't work reliably in k3d containers).
# Based on: https://github.com/jlian/k3d-nfs

# Start rpcbind in the background — needed for NFS client (mount.nfs) to work.
# rpcbind must be running before any NFS mount attempts.
/sbin/rpcbind 2>/dev/null || true
echo "NFS client support enabled (rpcbind started)."
