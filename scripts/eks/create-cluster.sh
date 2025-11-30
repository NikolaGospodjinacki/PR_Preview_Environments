#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TERRAFORM_DIR="$SCRIPT_DIR/../../infrastructure/terraform"

echo "🚀 Creating EKS cluster..."
echo ""
echo "⚠️  WARNING: This will create AWS resources that cost money!"
echo "   Estimated cost: ~\$0.18/hour (~\$130/month if always on)"
echo ""
read -p "Continue? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Aborted."
    exit 0
fi

# Check for terraform.tfvars
if [ ! -f "$TERRAFORM_DIR/terraform.tfvars" ]; then
    echo "❌ terraform.tfvars not found!"
    echo "   Copy terraform.tfvars.example to terraform.tfvars and fill in values"
    exit 1
fi

# Initialize Terraform
echo "📦 Initializing Terraform..."
cd "$TERRAFORM_DIR"
terraform init

# Plan
echo "📋 Planning infrastructure..."
terraform plan -var-file=terraform.tfvars -out=tfplan

echo ""
read -p "Apply this plan? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Aborted."
    exit 0
fi

# Apply
echo "🔨 Creating infrastructure (this takes ~15-20 minutes)..."
terraform apply tfplan

# Get outputs
CLUSTER_NAME=$(terraform output -raw cluster_name)
AWS_REGION=$(terraform output -raw account_id | head -1 && terraform output -raw kubeconfig_command | grep -oP '(?<=--region )[^ ]+')

# Update kubeconfig
echo "🔧 Updating kubeconfig..."
aws eks update-kubeconfig --region us-east-1 --name "$CLUSTER_NAME"

# Install Nginx Ingress Controller
echo "📦 Installing Nginx Ingress Controller..."
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.9.4/deploy/static/provider/aws/deploy.yaml

echo "⏳ Waiting for Ingress Controller to be ready..."
kubectl wait --namespace ingress-nginx \
    --for=condition=ready pod \
    --selector=app.kubernetes.io/component=controller \
    --timeout=300s

# Get Load Balancer URL
echo "⏳ Waiting for Load Balancer..."
sleep 30
LB_URL=$(kubectl get svc -n ingress-nginx ingress-nginx-controller -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')

echo ""
echo "✅ EKS cluster created successfully!"
echo ""
echo "📋 Cluster Info:"
echo "   Name: $CLUSTER_NAME"
echo "   Region: us-east-1"
echo "   Nodes: $(kubectl get nodes --no-headers | wc -l)"
echo ""
echo "🌐 Load Balancer URL:"
echo "   http://$LB_URL"
echo ""
echo "🔧 Next steps:"
echo "   1. Set PREVIEW_BASE_URL secret in GitHub to: http://$LB_URL"
echo "   2. Set AWS_ROLE_ARN secret to: $(terraform output -raw github_actions_role_arn)"
echo "   3. Generate and set KUBECONFIG_BASE64 secret:"
echo "      cat ~/.kube/config | base64 -w 0"
echo ""
echo "💰 Remember to destroy when done: ./scripts/eks/destroy-cluster.sh"
