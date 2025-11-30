# 🏠 Local Development Setup

This guide explains how to run PR Preview Environments locally using k3d and ngrok.

## Prerequisites

### 1. Install Docker Desktop

Download and install from: https://www.docker.com/products/docker-desktop

### 2. Install k3d

```bash
# Linux/macOS
curl -s https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | bash

# Windows (PowerShell)
choco install k3d
# or
winget install k3d
```

### 3. Install kubectl

```bash
# Linux
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl

# macOS
brew install kubectl

# Windows
choco install kubernetes-cli
```

### 4. Install ngrok

1. Sign up at https://ngrok.com (free tier is fine)
2. Download ngrok: https://ngrok.com/download
3. Get your auth token from: https://dashboard.ngrok.com/get-started/your-authtoken

```bash
# Add to your shell profile
export NGROK_AUTH_TOKEN=your_token_here

# Or configure directly
ngrok authtoken your_token_here
```

---

## Quick Start

### 1. Create the k3d Cluster

```bash
./scripts/local/create-cluster.sh
```

This will:
- Create a k3d cluster named `pr-previews`
- Map ports 80 and 443 to your localhost
- Install Nginx Ingress Controller

### 2. Deploy a Test Preview

```bash
# Deploy a preview for "PR #1"
./scripts/deploy-preview.sh 1

# Check it's running
kubectl get all -n pr-1

# Access locally
curl http://localhost/pr-1/
```

### 3. Start ngrok Tunnel (Optional)

To make your previews accessible from the internet:

```bash
./scripts/local/start-tunnel.sh
```

This will output a URL like `https://abc123.ngrok.io`. Your previews will be at:
- `https://abc123.ngrok.io/pr-1/`
- `https://abc123.ngrok.io/pr-2/`
- etc.

### 4. Clean Up

```bash
# Delete a specific preview
./scripts/destroy-preview.sh 1

# List all previews
./scripts/list-previews.sh

# Destroy the entire cluster
./scripts/local/destroy-cluster.sh
```

---

## Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                        Your Machine                                  │
│  ┌───────────────────────────────────────────────────────────────┐  │
│  │                    k3d Cluster                                 │  │
│  │  ┌─────────────────────────────────────────────────────────┐  │  │
│  │  │              Nginx Ingress Controller                    │  │  │
│  │  │                  localhost:80                            │  │  │
│  │  └─────────────────────────────────────────────────────────┘  │  │
│  │                           │                                    │  │
│  │       ┌───────────────────┼───────────────────┐               │  │
│  │       ▼                   ▼                   ▼               │  │
│  │  ┌─────────┐        ┌─────────┐        ┌─────────┐           │  │
│  │  │ pr-1    │        │ pr-2    │        │ pr-3    │           │  │
│  │  │ /pr-1/  │        │ /pr-2/  │        │ /pr-3/  │           │  │
│  │  └─────────┘        └─────────┘        └─────────┘           │  │
│  └───────────────────────────────────────────────────────────────┘  │
│                               │                                      │
│                               ▼                                      │
│  ┌───────────────────────────────────────────────────────────────┐  │
│  │                     ngrok Tunnel                               │  │
│  │              https://xxxxx.ngrok.io                           │  │
│  └───────────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────┘
```

---

## Connecting GitHub Actions to Local Cluster

For testing the full workflow with GitHub Actions, you need to expose your kubeconfig:

### Option 1: Use ngrok TCP Tunnel (Complex)

Not recommended for local development.

### Option 2: Use a Self-Hosted Runner

1. Install a GitHub Actions runner on your machine
2. Configure it to use your local kubeconfig
3. Update workflows to use `runs-on: self-hosted`

### Option 3: Test Locally, Deploy to EKS (Recommended)

- Develop and test locally with k3d
- Use EKS for actual PR previews from GitHub Actions
- See [EKS Setup Guide](EKS_SETUP.md)

---

## Troubleshooting

### Cluster won't start

```bash
# Check Docker is running
docker info

# Check for port conflicts
netstat -an | grep ":80 "

# Delete and recreate
k3d cluster delete pr-previews
./scripts/local/create-cluster.sh
```

### Can't access localhost

```bash
# Check ingress controller is running
kubectl get pods -n ingress-nginx

# Check ingress rules
kubectl get ingress -A

# Check service
kubectl get svc -n ingress-nginx
```

### ngrok not working

```bash
# Verify auth token
ngrok authtoken your_token

# Check ngrok status
curl http://127.0.0.1:4040/api/tunnels
```

---

## Cost

| Resource | Cost |
|----------|------|
| k3d | Free |
| Docker | Free |
| ngrok (free tier) | Free |
| **Total** | **$0/month** |
