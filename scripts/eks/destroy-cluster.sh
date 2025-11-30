#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TERRAFORM_DIR="$SCRIPT_DIR/../../infrastructure/terraform"

echo "🗑️  Destroying EKS cluster..."
echo ""
echo "⚠️  WARNING: This will destroy all AWS resources!"
echo "   All preview environments will be deleted."
echo ""
read -p "Continue? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Aborted."
    exit 0
fi

cd "$TERRAFORM_DIR"

# First, delete all preview namespaces
echo "🧹 Cleaning up preview namespaces..."
NAMESPACES=$(kubectl get namespaces -l pr-preview=true -o jsonpath='{.items[*].metadata.name}' 2>/dev/null || echo "")
for ns in $NAMESPACES; do
    echo "   Deleting namespace: $ns"
    kubectl delete namespace "$ns" --wait=false || true
done

# Delete Nginx Ingress (to release Load Balancer)
echo "🧹 Removing Nginx Ingress Controller..."
kubectl delete -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.9.4/deploy/static/provider/aws/deploy.yaml || true

# Wait for Load Balancer to be released
echo "⏳ Waiting for Load Balancer to be released..."
sleep 60

# Destroy Terraform infrastructure
echo "🔨 Destroying Terraform infrastructure..."
terraform destroy -var-file=terraform.tfvars -auto-approve

echo ""
echo "✅ EKS cluster destroyed successfully!"
echo "   AWS billing will stop within the hour."
