#!/bin/bash
set -e

CLUSTER_NAME="pr-previews"

echo "🚀 Creating k3d cluster: $CLUSTER_NAME"

# Check if k3d is installed
if ! command -v k3d &> /dev/null; then
    echo "❌ k3d is not installed. Install it with:"
    echo "   curl -s https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | bash"
    exit 1
fi

# Check if cluster already exists
if k3d cluster list | grep -q "$CLUSTER_NAME"; then
    echo "⚠️  Cluster $CLUSTER_NAME already exists"
    read -p "Delete and recreate? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        k3d cluster delete $CLUSTER_NAME
    else
        echo "Exiting..."
        exit 0
    fi
fi

# Create cluster with port mappings for ingress
k3d cluster create $CLUSTER_NAME \
    --port "80:80@loadbalancer" \
    --port "443:443@loadbalancer" \
    --agents 2 \
    --wait

echo "⏳ Waiting for cluster to be ready..."
kubectl wait --for=condition=Ready nodes --all --timeout=60s

echo "📦 Installing Nginx Ingress Controller..."
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.9.4/deploy/static/provider/cloud/deploy.yaml

echo "⏳ Waiting for Ingress Controller to be ready..."
kubectl wait --namespace ingress-nginx \
    --for=condition=ready pod \
    --selector=app.kubernetes.io/component=controller \
    --timeout=120s

echo ""
echo "✅ Cluster created successfully!"
echo ""
echo "📋 Cluster Info:"
echo "   Name: $CLUSTER_NAME"
echo "   Nodes: $(kubectl get nodes --no-headers | wc -l)"
echo "   Ingress: http://localhost"
echo ""
echo "🔧 Next steps:"
echo "   1. Run ./scripts/local/start-tunnel.sh to expose with ngrok"
echo "   2. Run ./scripts/deploy-preview.sh <pr-number> to deploy a preview"
