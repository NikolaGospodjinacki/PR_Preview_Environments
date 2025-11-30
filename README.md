#  PR Preview Environments

**Automatically deploy isolated preview environments for every Pull Request using Kubernetes.**

This project demonstrates a production-ready PR preview system that gives reviewers a live environment to test changes before merging - the same approach used by companies like Vercel, Netlify, and Heroku.

[![Local Development](https://img.shields.io/badge/Local-k3d%20%2B%20ngrok-blue)](#local-development-free)
[![Production](https://img.shields.io/badge/Production-AWS%20EKS-orange)](#production-aws-eks)
[![License](https://img.shields.io/badge/License-MIT-green)](LICENSE)

---

##  Table of Contents

- [What This Does](#-what-this-does)
- [Architecture](#-architecture)
- [Quick Start](#-quick-start)
- [Local Development (Free)](#local-development-free)
- [Production (AWS EKS)](#production-aws-eks)
- [GitHub Actions Workflows](#-github-actions-workflows)
- [Project Structure](#-project-structure)
- [Configuration](#-configuration)
- [Cost Breakdown](#-cost-breakdown)
- [Skills Demonstrated](#-skills-demonstrated)

---

##  What This Does

When a **Pull Request is opened**:
1.  **Build**  Docker image is built from the PR branch
2.  **Deploy**  New Kubernetes namespace created with isolated resources
3.  **Route**  Unique URL generated (e.g., `/pr-123/`)
4.  **Comment**  PR gets an automatic comment with the preview URL

When the **PR is closed/merged**:
1.  **Cleanup**  Namespace and all resources automatically deleted
2.  **Update**  PR comment updated to show cleanup status

This enables:
- **Faster reviews** - Reviewers can test live changes without pulling code
- **Better QA** - Non-technical stakeholders can preview features
- **Reduced bugs** - Issues caught before merging to main
- **Parallel development** - Multiple PRs can have independent environments

---

##  Architecture

```

                            GitHub Actions                                    
                                                                              
  PR Opened  Build Image  Push to ECR  Deploy to K8s  Comment    
  PR Closed  Delete Namespace  Update Comment  Done                 
──
                                    
                                    

                         Kubernetes Cluster                                   
                      (k3d local / AWS EKS production)                       
                                                                              
      
                      Nginx Ingress Controller                              
                Routes: /pr-{number}/*  namespace                      │    
      
                                                                             
                      
                                                                          
                                
   ns: pr-101              ns: pr-102              ns: pr-103          
                                      
   Deployment              Deployment              Deployment          
   Service                 Service                 Service             
   Ingress                 Ingress                 Ingress             
                                
──
                                    
                                     (local only)

                              Ngrok Tunnel                                    
                  Exposes local cluster to the internet                       
                     https://xxxxx.ngrok-free.dev/pr-101/                    
──
```

### Key Components

| Component | Local | Production | Purpose |
|-----------|-------|------------|---------|
| **Kubernetes** | k3d (k3s in Docker) | AWS EKS | Container orchestration |
| **Ingress** | Nginx Ingress | Nginx Ingress + ALB | HTTP routing |
| **Registry** | Local Docker | AWS ECR | Container images |
| **Tunnel** | ngrok | AWS Load Balancer | Public access |
| **IaC** | Shell scripts | Terraform | Infrastructure |

---

##  Quick Start

### Prerequisites

| Tool | Required For | Installation |
|------|--------------|--------------|
| Docker | Both | [docker.com](https://docker.com) |
| kubectl | Both | [kubernetes.io](https://kubernetes.io/docs/tasks/tools/) |
| k3d | Local | `curl -s https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh \| bash` |
| ngrok | Local | [ngrok.com](https://ngrok.com/download) |
| AWS CLI | Production | [aws.amazon.com](https://aws.amazon.com/cli/) |
| Terraform | Production | [terraform.io](https://terraform.io) |

---

## Local Development (Free)

Perfect for learning and development - runs entirely on your machine.

### 1. Create the Cluster

```bash
# Clone the repo
git clone https://github.com/YOUR_USERNAME/PR_Preview_Environments.git
cd PR_Preview_Environments

# Create k3d cluster with Nginx Ingress
./scripts/local/create-cluster.sh
```

This creates:
- 3-node k3s cluster in Docker
- Nginx Ingress Controller
- Port mappings (8080  HTTP, 8443  HTTPS)

### 2. Deploy a Preview

```bash
# Deploy preview for PR #1
./scripts/deploy-preview.sh 1

# Test it
curl http://localhost:8080/pr-1/
curl http://localhost:8080/pr-1/health
curl http://localhost:8080/pr-1/api/info
```

### 3. Expose Publicly (Optional)

```bash
# Authenticate ngrok (one-time)
ngrok config add-authtoken YOUR_TOKEN

# Start tunnel
./scripts/local/start-tunnel.sh

# Your preview is now at: https://xxxxx.ngrok-free.dev/pr-1/
```

### 4. Cleanup

```bash
# Destroy single preview
./scripts/destroy-preview.sh 1

# Destroy entire cluster
./scripts/local/destroy-cluster.sh
```

 **[Detailed Local Setup Guide ](docs/LOCAL_SETUP.md)**

---

## Production (AWS EKS)

For demonstrations and real deployments. Uses AWS EKS with GitHub Actions.

### 1. Deploy Infrastructure

```bash
cd infrastructure/terraform

# Configure variables
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your values

# Deploy (~15 minutes)
terraform init
terraform apply
```

### 2. Configure GitHub

Add these secrets to your repository:

| Secret | Value | Source |
|--------|-------|--------|
| `AWS_ROLE_ARN` | IAM role ARN | `terraform output github_actions_role_arn` |

### 3. Create a PR

GitHub Actions will automatically:
1. Build and push the Docker image to ECR
2. Deploy to a new namespace in EKS
3. Comment on the PR with the preview URL

### 4. Cleanup

```bash
# Destroy infrastructure (stops billing)
terraform destroy
```

 **[Detailed EKS Setup Guide ](docs/EKS_SETUP.md)**

---

##  GitHub Actions Workflows

### Deploy Workflow (`.github/workflows/pr-preview-deploy.yml`)

Triggers on: `pull_request: [opened, synchronize, reopened]`

```
         
  Checkout    Build Image  Push to ECR  Deploy K8s  
         
                                                              
                                                              
                                                      
                                                       Comment PR  
                                                      
```

### Cleanup Workflow (`.github/workflows/pr-preview-cleanup.yml`)

Triggers on: `pull_request: [closed]`

```
      
 Delete Namespace Remove Resources  Update Comment 
      
```

---

##  Project Structure

```
PR_Preview_Environments/
 app/                              # Sample Node.js application
    src/index.ts                 # Express server with preview info
    Dockerfile                   # Multi-stage production build
    package.json
    tsconfig.json

 k8s/                              # Kubernetes manifests (Kustomize)
    base/                        # Base resources
       deployment.yaml          # Pod template with health checks
│       service.yaml             # ClusterIP service
       ingress.yaml             # Nginx ingress with path rewrite
       kustomization.yaml
    overlays/preview/            # Preview-specific patches
        kustomization.yaml

 infrastructure/                   # Terraform for AWS
    terraform/
        main.tf                  # Provider & data sources
        variables.tf             # Input variables
        outputs.tf               # Useful outputs
        vpc.tf                   # VPC, subnets, NAT gateways
        eks.tf                   # EKS cluster & node group
        ecr.tf                   # Container registry
        github_oidc.tf           # GitHub Actions OIDC auth

 scripts/
    deploy-preview.sh            # Deploy a preview environment
    destroy-preview.sh           # Destroy a preview environment
    list-previews.sh             # List all active previews
    local/
       create-cluster.sh        # Create k3d cluster
       destroy-cluster.sh       # Destroy k3d cluster
       start-tunnel.sh          # Start ngrok tunnel
    eks/
        create-cluster.sh        # Create EKS via Terraform
        destroy-cluster.sh       # Destroy EKS cluster

 .github/workflows/
    pr-preview-deploy.yml        # Deploy on PR open/update
    pr-preview-cleanup.yml       # Cleanup on PR close

 docs/
    LOCAL_SETUP.md               # Detailed local setup guide
    EKS_SETUP.md                 # Detailed EKS setup guide

 README.md                         # This file
```

---

##  Configuration

### Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `HTTP_PORT` | 8080 | Local HTTP port (k3d) |
| `HTTPS_PORT` | 8443 | Local HTTPS port (k3d) |
| `AWS_REGION` | us-east-1 | AWS region for EKS |

### Terraform Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `project_name` | pr-previews | Project identifier |
| `github_repo` | - | Your repo (owner/repo) |
| `cluster_version` | 1.28 | Kubernetes version |
| `node_instance_type` | t3.medium | EC2 instance type |
| `node_desired_size` | 2 | Number of nodes |

### GitHub Secrets (for EKS)

| Secret | Description |
|--------|-------------|
| `AWS_ROLE_ARN` | IAM role for GitHub Actions (from Terraform output) |

---

##  Cost Breakdown

### Local Development
| Resource | Cost |
|----------|------|
| k3d | **Free** |
| Docker Desktop | **Free** (personal) |
| ngrok | **Free** (limited) |
| **Total** | **$0/month** |

### Production (AWS EKS)
| Resource | Hourly | Monthly (24/7) |
|----------|--------|----------------|
| EKS Control Plane | $0.10 | ~$73 |
| t3.medium  2 | $0.084 | ~$61 |
| NAT Gateway  2 | $0.09 | ~$65 |
| Load Balancer | $0.025 | ~$18 |
| ECR Storage | - | ~$1 |
| **Total** | **~$0.30/hr** | **~$218/month** |

>  **Pro tip**: For demos, spin up the cluster, do your demo, then destroy it. A 2-hour demo costs less than $1!

---

##  Skills Demonstrated

This project showcases proficiency in:

### Kubernetes
- Namespace isolation for multi-tenancy
- Deployments with health checks (liveness/readiness probes)
- Services and Ingress routing
- Resource requests and limits
- Kustomize for configuration management

### AWS
- EKS cluster provisioning and management
- VPC networking (public/private subnets, NAT gateways)
- IAM roles with least-privilege access
- ECR for container image registry
- OIDC authentication for GitHub Actions

### Infrastructure as Code
- Terraform for reproducible infrastructure
- Shell scripting for automation
- Modular, reusable configurations

### CI/CD
- GitHub Actions with OIDC authentication
- Automated testing and deployment
- Environment cleanup automation
- PR-based workflows

### DevOps Best Practices
- GitOps principles
- Ephemeral environments
- Infrastructure automation
- Cost optimization strategies

---

##  Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing`)
5. Open a Pull Request

---

##  License

MIT License - see [LICENSE](LICENSE) for details.

---

##  Acknowledgments

- [k3d](https://k3d.io/) - Lightweight Kubernetes in Docker
- [ngrok](https://ngrok.com/) - Secure tunnels to localhost
- [Nginx Ingress](https://kubernetes.github.io/ingress-nginx/) - Ingress controller

---

**Built with  for the DevOps community**
