# ☁️ EKS Production Setup

This guide explains how to deploy PR Preview Environments to AWS EKS for production use.

## Prerequisites

### 1. AWS CLI

```bash
# Install
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install

# Configure
aws configure
```

### 2. Terraform

```bash
# Linux/macOS
brew install terraform

# Or download from https://www.terraform.io/downloads
```

### 3. kubectl

```bash
brew install kubectl
```

---

## Quick Start

### 1. Configure Terraform Variables

```bash
cd infrastructure/terraform
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars`:
```hcl
aws_region   = "us-east-1"
project_name = "pr-previews"
environment  = "dev"
github_repo  = "YOUR_USERNAME/PR_Preview_Environments"
```

### 2. Create the EKS Cluster

```bash
./scripts/eks/create-cluster.sh
```

This will:
- Create a VPC with public and private subnets
- Create an EKS cluster with 2 worker nodes
- Install Nginx Ingress Controller with AWS Load Balancer
- Set up GitHub OIDC for Actions authentication

**⏱️ Time: ~15-20 minutes**

### 3. Configure GitHub Secrets

After the cluster is created, set these GitHub secrets:

| Secret | Value |
|--------|-------|
| `AWS_ROLE_ARN` | From terraform output: `terraform output github_actions_role_arn` |
| `KUBECONFIG_BASE64` | `cat ~/.kube/config \| base64 -w 0` |
| `PREVIEW_BASE_URL` | Load Balancer URL from the script output |

### 4. Test It

1. Create a new branch
2. Make a change to `app/src/index.ts`
3. Open a Pull Request
4. Watch the GitHub Action deploy a preview
5. Check the PR comment for the preview URL

### 5. Destroy When Done

```bash
./scripts/eks/destroy-cluster.sh
```

---

## Architecture

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                              AWS Account                                     │
│                                                                              │
│  ┌─────────────────────────────────────────────────────────────────────┐    │
│  │                              VPC                                     │    │
│  │  ┌─────────────────────────────────────────────────────────────┐    │    │
│  │  │                    Public Subnets                            │    │    │
│  │  │  ┌─────────────────────────────────────────────────────┐    │    │    │
│  │  │  │           Application Load Balancer                  │    │    │    │
│  │  │  │         (Nginx Ingress Controller)                   │    │    │    │
│  │  │  └─────────────────────────────────────────────────────┘    │    │    │
│  │  └─────────────────────────────────────────────────────────────┘    │    │
│  │                               │                                      │    │
│  │  ┌─────────────────────────────────────────────────────────────┐    │    │
│  │  │                   Private Subnets                            │    │    │
│  │  │  ┌─────────────────────────────────────────────────────┐    │    │    │
│  │  │  │                 EKS Cluster                          │    │    │    │
│  │  │  │  ┌───────────────┐    ┌───────────────┐             │    │    │    │
│  │  │  │  │  Node Group   │    │  Node Group   │             │    │    │    │
│  │  │  │  │  (t3.medium)  │    │  (t3.medium)  │             │    │    │    │
│  │  │  │  └───────────────┘    └───────────────┘             │    │    │    │
│  │  │  │         │                    │                       │    │    │    │
│  │  │  │    ┌────┴────────────────────┴────┐                 │    │    │    │
│  │  │  │    │      Preview Namespaces       │                 │    │    │    │
│  │  │  │    │  pr-1  │  pr-2  │  pr-3  │   │                 │    │    │    │
│  │  │  │    └───────────────────────────────┘                 │    │    │    │
│  │  │  └─────────────────────────────────────────────────────┘    │    │    │
│  │  └─────────────────────────────────────────────────────────────┘    │    │
│  └─────────────────────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## Cost Breakdown

| Resource | Hourly | Monthly (24/7) | Notes |
|----------|--------|----------------|-------|
| EKS Control Plane | $0.10 | $72 | Fixed cost |
| t3.medium nodes (2x) | $0.042 each | $60 | On-demand pricing |
| NAT Gateways (2x) | $0.045 each | $65 | For private subnets |
| Load Balancer | $0.025 | $18 | Plus data transfer |
| **Total** | **~$0.30/hr** | **~$215/month** | |

### Cost Optimization Tips

1. **Use Spot Instances**: Add `capacity_type = "SPOT"` to node group for ~60% savings
2. **Single NAT Gateway**: Use 1 NAT instead of 2 for ~$32/month savings
3. **Destroy when not using**: Run cluster only during work hours
4. **Right-size nodes**: Use t3.small if previews are light

### On-Demand Usage

If you only run the cluster for demos:

| Usage | Cost |
|-------|------|
| 2 hours | ~$0.60 |
| 8 hours | ~$2.40 |
| 1 week | ~$50 |

---

## GitHub Actions Integration

The workflows are already configured to:

1. **On PR Open/Update** (`pr-preview-deploy.yml`):
   - Build Docker image
   - Push to GitHub Container Registry
   - Deploy to EKS in a new namespace
   - Comment on PR with preview URL

2. **On PR Close** (`pr-preview-cleanup.yml`):
   - Delete the preview namespace
   - Update PR comment

### Required Secrets

| Secret | Description | How to Get |
|--------|-------------|------------|
| `AWS_ROLE_ARN` | IAM role for OIDC auth | `terraform output github_actions_role_arn` |
| `KUBECONFIG_BASE64` | Base64 kubeconfig | `cat ~/.kube/config \| base64 -w 0` |
| `PREVIEW_BASE_URL` | Load Balancer URL | From create script output |

---

## Maintenance

### Updating Kubernetes Version

1. Update `cluster_version` in `terraform.tfvars`
2. Run `terraform plan` to see changes
3. Run `terraform apply` (rolling update)

### Scaling Nodes

```bash
# Edit terraform.tfvars
node_desired_size = 3
node_max_size     = 6

# Apply
cd infrastructure/terraform
terraform apply -var-file=terraform.tfvars
```

### Viewing Logs

```bash
# All preview namespaces
kubectl get ns -l pr-preview=true

# Logs for a specific PR
kubectl logs -n pr-123 -l app=preview-app -f
```

---

## Troubleshooting

### GitHub Actions can't connect to EKS

1. Check IAM role trust policy includes your repo
2. Verify OIDC provider is set up correctly
3. Check KUBECONFIG_BASE64 is valid

### Pods not starting

```bash
# Check events
kubectl describe pod -n pr-123 preview-app-xxx

# Common issues:
# - Image pull errors: Check GHCR authentication
# - Resource limits: Increase node size
```

### Load Balancer not getting external IP

```bash
# Check ingress controller
kubectl get svc -n ingress-nginx

# Check AWS Load Balancer
aws elbv2 describe-load-balancers
```

---

## Security Considerations

1. **Private Subnets**: Worker nodes run in private subnets
2. **OIDC Authentication**: No long-lived AWS credentials in GitHub
3. **Namespace Isolation**: Each PR gets its own namespace
4. **Resource Limits**: Containers have CPU/memory limits
5. **Network Policies**: Consider adding for production use
