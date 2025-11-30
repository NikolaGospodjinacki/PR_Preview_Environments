#  AWS EKS Production Setup Guide

This guide walks you through deploying PR Preview Environments to **AWS EKS** (Elastic Kubernetes Service) with automated GitHub Actions CI/CD.

**Cost: ~$0.30/hour** - Only pay for what you use!

---

##  Prerequisites

### Required Tools

| Tool | Version | Purpose | Installation |
|------|---------|---------|--------------|
| AWS CLI | 2.x | AWS management | [aws.amazon.com](https://aws.amazon.com/cli/) |
| Terraform | 1.0+ | Infrastructure as Code | [terraform.io](https://terraform.io) |
| kubectl | 1.28+ | Kubernetes CLI | [kubernetes.io](https://kubernetes.io/docs/tasks/tools/) |

### AWS Requirements

- AWS Account with admin access (or appropriate IAM permissions)
- AWS CLI configured with credentials:
  ```bash
  aws configure
  # Enter your Access Key ID, Secret Access Key, and region
  ```

### Verify Prerequisites

```bash
aws --version           # aws-cli/2.x
terraform --version     # Terraform v1.x
kubectl version         # Client Version: v1.28+
aws sts get-caller-identity  # Verify AWS auth
```

---

##  Architecture Overview

```

                                  AWS                                         
                                                                              
      
                            VPC (10.0.0.0/16)                              
                                                                            
     Public Subnets (10.0.1.0/24, 10.0.2.0/24)                             
     ─                        
      NAT Gateway    NAT Gateway        ALB                         
                             
                                                                        
     Private Subnets (10.0.10.0/24, 10.0.11.0/24)                         
              
                         EKS Cluster                                     
                                        
         t3.medium       t3.medium      Node Group                 
          (Node 1)        (Node 2)                                  
                                        
                                                                         
                 
                     Nginx Ingress Controller                         
       ─          
                                                                        
           ─                  
                                                                     
                                         
        pr-101            pr-102            pr-103               
                 ─                        
     ─         
      │
                                                                              
                                                      
          ECR            Container Registry                               
   (preview-app images)                                                    
                                                      

                                    
                    
                           GitHub Actions          
                       (OIDC Authentication)       
                    
```

---

##  Step 1: Deploy Infrastructure with Terraform

### Configure Variables

```bash
cd infrastructure/terraform

# Copy example variables
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars`:
```hcl
aws_region     = "us-east-1"
project_name   = "pr-previews"
github_repo    = "YOUR_USERNAME/PR_Preview_Environments"
environment    = "dev"

# Optional customization
cluster_version    = "1.28"
node_instance_type = "t3.medium"
node_desired_size  = 2
node_min_size      = 1
node_max_size      = 4
```

### Deploy Infrastructure

```bash
# Initialize Terraform
terraform init

# Preview changes
terraform plan

# Apply (takes ~15 minutes)
terraform apply
```

### Get Outputs

```bash
# Get the role ARN for GitHub Actions
terraform output github_actions_role_arn

# Get the ECR repository URL
terraform output ecr_repository_url

# Configure kubectl
$(terraform output -raw kubeconfig_command)
```

---

##  Step 2: Install Nginx Ingress Controller

After the EKS cluster is created, install the ingress controller:

```bash
# Verify kubectl is connected
kubectl get nodes

# Install Nginx Ingress Controller
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.9.4/deploy/static/provider/aws/deploy.yaml

# Wait for it to be ready
kubectl wait --namespace ingress-nginx \
    --for=condition=ready pod \
    --selector=app.kubernetes.io/component=controller \
    --timeout=120s

# Get the Load Balancer URL
kubectl get svc -n ingress-nginx ingress-nginx-controller
```

---

##  Step 3: Configure GitHub

### Add Repository Secrets

Go to your repository: **Settings  Secrets and variables  Actions**

| Secret | Value | How to Get |
|--------|-------|------------|
| `AWS_ROLE_ARN` | `arn:aws:iam::123456789:role/pr-previews-github-actions-role` | `terraform output github_actions_role_arn` |

### Verify OIDC Connection

The Terraform creates a GitHub OIDC provider. This allows GitHub Actions to authenticate with AWS without storing long-lived credentials.

---

##  Step 4: Test the Pipeline

### Create a Test PR

```bash
# Create a feature branch
git checkout -b test/preview-demo

# Make a change
echo "# Test" >> README.md

# Commit and push
git add .
git commit -m "test: trigger preview deployment"
git push -u origin test/preview-demo

# Create a PR via GitHub UI or CLI
gh pr create --title "Test Preview" --body "Testing preview deployment"
```

### Watch the Workflow

1. Go to **Actions** tab in your repository
2. Watch the "Deploy PR Preview" workflow
3. Once complete, check the PR for the preview URL comment

### Verify the Preview

```bash
# Get the Load Balancer URL
LB_URL=$(kubectl get svc -n ingress-nginx ingress-nginx-controller -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')

# Test the preview
curl http://$LB_URL/pr-1/
curl http://$LB_URL/pr-1/health
```

---

##  Cost Management

### Current Resources

| Resource | Cost/Hour | Cost/Month (24/7) |
|----------|-----------|-------------------|
| EKS Control Plane | $0.10 | $73 |
| t3.medium  2 | $0.084 | $61 |
| NAT Gateway  2 | $0.09 | $65 |
| Load Balancer | $0.025 | $18 |
| ECR (1GB) | - | $0.10 |
| **Total** | **~$0.30** | **~$218** |

### Cost Optimization Strategies

1. **On-Demand Usage**: Destroy when not demoing
   ```bash
   terraform destroy  # Stops all billing
   ```

2. **Reduce NAT Gateways**: Use 1 instead of 2
   ```hcl
   # In vpc.tf, change count = 2 to count = 1
   ```

3. **Smaller Nodes**: Use t3.small for demos
   ```hcl
   node_instance_type = "t3.small"  # $0.021/hr instead of $0.042
   ```

4. **Spot Instances**: Add spot configuration for up to 90% savings
   ```hcl
   # Add to eks.tf node group
   capacity_type = "SPOT"
   ```

---

##  Step 5: Cleanup

### Destroy Single Preview

```bash
./scripts/destroy-preview.sh 1
```

### Destroy All Infrastructure

```bash
cd infrastructure/terraform
terraform destroy
```

This removes:
- EKS cluster
- VPC and subnets
- NAT gateways
- Load balancers
- ECR repository
- IAM roles

---

##  Troubleshooting

### GitHub Actions Can't Authenticate

Check the OIDC trust policy:
```bash
aws iam get-role --role-name pr-previews-github-actions-role
```

Verify the repo name matches exactly (case-sensitive).

### Pods Stuck in Pending

Check node resources:
```bash
kubectl describe nodes
kubectl get events -A
```

Scale up nodes if needed:
```bash
aws eks update-nodegroup-config \
    --cluster-name pr-previews-eks \
    --nodegroup-name pr-previews-nodes \
    --scaling-config desiredSize=3
```

### Load Balancer Not Created

Check ingress controller logs:
```bash
kubectl logs -n ingress-nginx -l app.kubernetes.io/component=controller
```

Verify AWS Load Balancer Controller (if using):
```bash
kubectl get pods -n kube-system | grep aws-load-balancer
```

### ECR Push Failures

Verify ECR permissions:
```bash
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin YOUR_ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com
```

---

##  Monitoring

### Basic Monitoring

```bash
# Watch all preview namespaces
watch kubectl get pods -l pr-preview=true --all-namespaces

# Resource usage
kubectl top pods --all-namespaces
kubectl top nodes
```

### CloudWatch Integration

EKS automatically sends logs to CloudWatch. View in AWS Console:
- CloudWatch  Logs  /aws/eks/pr-previews-eks

---

##  Security Considerations

### Current Security Features

1. **OIDC Authentication**: No long-lived AWS credentials in GitHub
2. **Private Subnets**: Worker nodes not directly exposed
3. **NAT Gateways**: Outbound-only internet access for nodes
4. **ECR Scanning**: Images scanned on push
5. **Least Privilege**: IAM roles with minimal permissions

### Additional Recommendations

1. **Enable EKS Secrets Encryption**
2. **Add Network Policies** for pod-to-pod traffic control
3. **Enable Pod Security Standards**
4. **Add WAF** in front of the Load Balancer
5. **Enable VPC Flow Logs** for network monitoring

---

##  Next Steps

1. **Add your own app** - Replace the sample with your real application
2. **Add tests** - Integrate testing before preview deployment
3. **Add monitoring** - Set up Prometheus/Grafana or CloudWatch dashboards
4. **Add custom domains** - Use Route53 for pretty URLs

 **[Back to README ](../README.md)**
