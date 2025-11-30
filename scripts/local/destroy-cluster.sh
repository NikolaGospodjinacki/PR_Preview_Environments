#!/bin/bash
set -e

CLUSTER_NAME="pr-previews"

echo "🗑️  Destroying k3d cluster: $CLUSTER_NAME"

# Check if cluster exists
if ! k3d cluster list | grep -q "$CLUSTER_NAME"; then
    echo "⚠️  Cluster $CLUSTER_NAME does not exist"
    exit 0
fi

# Delete cluster
k3d cluster delete $CLUSTER_NAME

echo "✅ Cluster destroyed successfully!"
