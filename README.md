# 🚀 PR Preview Environments

Automatically deploy preview environments for every Pull Request using Kubernetes.

[![Local Development](https://img.shields.io/badge/Local-k3d%20%2B%20ngrok-blue)](docs/LOCAL_SETUP.md)
[![Production](https://img.shields.io/badge/Production-EKS-orange)](docs/EKS_SETUP.md)
[![License](https://img.shields.io/badge/License-MIT-green)](LICENSE)

---

## 🎯 What This Does

When a Pull Request is opened:
1. **Build** → Docker image is built and pushed
2. **Deploy** → New Kubernetes namespace created with the app
3. **Route** → Unique URL generated (e.g., `pr-123.preview.example.com`)
4. **Comment** → PR gets a comment with the preview URL

When the PR is closed/merged:
1. **Cleanup** → Namespace and all resources deleted automatically

---

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                            GitHub Actions                                    │
│                                                                              │
│  PR Opened ──► Build Image ──► Deploy to K8s ──► Post Preview URL           │
│  PR Closed ──► Delete Namespace ──► Cleanup Complete                        │
└─────────────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                         Kubernetes Cluster                                   │
│                      (k3d local / EKS production)                           │
│                                                                              │
│  ┌─────────────────────────────────────────────────────────────────────┐    │
│  │                    Nginx Ingress Controller                          │    │
│  │         Routes: pr-{number}.preview.domain.com → namespace           │    │
│  └─────────────────────────────────────────────────────────────────────┘    │
│                                    │                                         │
│         ┌──────────────────────────┼──────────────────────────┐             │
│         ▼                          ▼                          ▼             │
│  ┌─────────────┐           ┌─────────────┐           ┌─────────────┐        │
│  │ ns: pr-101  │           │ ns: pr-102  │           │ ns: pr-103  │        │
│  │ ─────────── │           │ ─────────── │           │ ─────────── │        │
│  │ Deployment  │           │ Deployment  │           │ Deployment  │        │
│  │ Service     │           │ Service     │           │ Service     │        │
│  │ Ingress     │           │ Ingress     │           │ Ingress     │        │
│  └─────────────┘           └─────────────┘           └─────────────┘        │
└─────────────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼ (local only)
┌─────────────────────────────────────────────────────────────────────────────┐
│                              Ngrok Tunnel                                    │
│                  Exposes local cluster to the internet                       │
│                     https://xxxxx.ngrok.io/pr-101/                          │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## 🚀 Quick Start

### Prerequisites

- Docker Desktop
- kubectl
- k3d (for local) or AWS CLI (for EKS)
- ngrok account (free tier works)

### Local Development (Free)

```bash
# 1. Create local k3d cluster
./scripts/local/create-cluster.sh

# 2. Start ngrok tunnel
./scripts/local/start-tunnel.sh

# 3. Deploy a preview manually (or let GitHub Actions do it)
./scripts/deploy-preview.sh pr-1

# 4. Cleanup
./scripts/destroy-preview.sh pr-1
```

### Production (EKS)

```bash
# 1. Create EKS cluster (~10 minutes, costs ~$0.10/hr)
./scripts/eks/create-cluster.sh

# 2. Deploy previews via GitHub Actions (automatic)

# 3. Destroy cluster when done (stops billing)
./scripts/eks/destroy-cluster.sh
```

---

## 📁 Project Structure

```
PR_Preview_Environments/
├── app/                          # Sample application
│   ├── src/
│   │   └── index.ts
│   ├── Dockerfile
│   └── package.json
├── k8s/                          # Kubernetes manifests
│   ├── base/                     # Base manifests (Kustomize)
│   │   ├── deployment.yaml
│   │   ├── service.yaml
│   │   ├── ingress.yaml
│   │   └── kustomization.yaml
│   └── overlays/                 # Environment-specific overlays
│       └── preview/
│           └── kustomization.yaml
├── infrastructure/               # Terraform for EKS
│   └── terraform/
│       ├── main.tf
│       ├── eks.tf
│       ├── vpc.tf
│       └── variables.tf
├── scripts/                      # Helper scripts
│   ├── local/
│   │   ├── create-cluster.sh
│   │   ├── destroy-cluster.sh
│   │   └── start-tunnel.sh
│   ├── eks/
│   │   ├── create-cluster.sh
│   │   └── destroy-cluster.sh
│   ├── deploy-preview.sh
│   └── destroy-preview.sh
├── .github/
│   └── workflows/
│       ├── pr-preview-deploy.yml
│       └── pr-preview-cleanup.yml
├── docs/
│   ├── LOCAL_SETUP.md
│   └── EKS_SETUP.md
└── README.md
```

---

## 🔧 Configuration

### Environment Variables

| Variable | Description | Required |
|----------|-------------|----------|
| `NGROK_AUTH_TOKEN` | Ngrok authentication token | Local only |
| `AWS_ROLE_ARN` | AWS role for GitHub Actions | EKS only |
| `DOCKER_REGISTRY` | Container registry URL | EKS only |

### GitHub Secrets

| Secret | Description |
|--------|-------------|
| `NGROK_AUTH_TOKEN` | For local tunnel |
| `AWS_ROLE_ARN` | For EKS deployments |
| `KUBECONFIG_BASE64` | Base64 encoded kubeconfig |

---

## 💰 Cost Breakdown

### Local (k3d + ngrok)

| Resource | Cost |
|----------|------|
| k3d | Free |
| ngrok (free tier) | Free |
| **Total** | **$0/month** |

### Production (EKS)

| Resource | Cost | Notes |
|----------|------|-------|
| EKS Control Plane | $0.10/hr | ~$72/month if always on |
| t3.medium nodes (2x) | $0.042/hr each | ~$60/month |
| **Total** | **~$130/month** | Or ~$0.18/hr on-demand |

> 💡 **Tip**: Use the destroy scripts when not demoing. A 2-hour demo costs ~$0.36!

---

## 🎓 What You'll Learn

- **Kubernetes**: Deployments, Services, Ingress, Namespaces
- **Kustomize**: Base/overlay pattern for K8s manifests
- **CI/CD**: GitHub Actions with PR triggers
- **Terraform**: EKS cluster provisioning
- **Networking**: Ingress routing, tunneling with ngrok
- **GitOps**: PR-driven deployments

---

## 📝 License

MIT License - see [LICENSE](LICENSE)
