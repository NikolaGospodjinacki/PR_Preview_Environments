#  Local Development Setup Guide

This guide walks you through setting up PR Preview Environments locally using **k3d** (Kubernetes in Docker) and **ngrok** for public access.

**Cost: $0** - Everything runs on your machine!

---

##  Prerequisites

### Required Tools

| Tool | Version | Purpose | Installation |
|------|---------|---------|--------------|
| Docker | 20+ | Container runtime | [docker.com](https://docker.com) |
| kubectl | 1.28+ | Kubernetes CLI | [kubernetes.io](https://kubernetes.io/docs/tasks/tools/) |
| k3d | 5.x | Local K8s clusters | See below |
| ngrok | 3.x | Public tunnels | [ngrok.com](https://ngrok.com/download) |

### Install k3d

**Linux/macOS:**
```bash
curl -s https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | bash
```

**Windows (WSL2 recommended):**
```bash
# In WSL2 terminal
curl -s https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | bash
```

### Verify Prerequisites

```bash
docker --version     # Docker version 20+
kubectl version      # Client Version: v1.28+
k3d version         # k3d version v5.x
```

---

##  Step 1: Create the Cluster

```bash
# From the project root
./scripts/local/create-cluster.sh
```

This script:
1. Creates a 3-node k3s cluster named `pr-previews`
2. Maps ports 8080 (HTTP) and 8443 (HTTPS) to your localhost
3. Disables Traefik (we use Nginx Ingress instead)
4. Installs the Nginx Ingress Controller

### What Gets Created

```

                     Docker Desktop                           
                                                              
  ─ 
                    k3d-pr-previews                         
                                                            
             
       Server         Agent-0        Agent-1        
       (Control)      (Worker)       (Worker)       
             
                                                            
       
                  Nginx Ingress Controller              
                       Port 80  8080                   
                       Port 443  8443                  
       
   
─
            Port 8080               Port 8443
       http://localhost:8080    https://localhost:8443
```

### Verify Cluster

```bash
# Check nodes
kubectl get nodes
# Expected: 3 nodes (1 server, 2 agents)

# Check ingress controller
kubectl get pods -n ingress-nginx
# Expected: controller pod in Running state

# Check ingress class
kubectl get ingressclass
# Expected: nginx class
```

---

##  Step 2: Deploy a Preview

```bash
# Deploy preview for PR #1
./scripts/deploy-preview.sh 1
```

This script:
1. Creates namespace `pr-1`
2. Builds the Docker image locally
3. Imports the image into k3d
4. Deploys Deployment, Service, and Ingress

### Test the Preview

```bash
# Main page
curl http://localhost:8080/pr-1/

# Health check
curl http://localhost:8080/pr-1/health
# {"status":"healthy","timestamp":"..."}

# API info
curl http://localhost:8080/pr-1/api/info
# {"pr":"1","sha":"local","deployedAt":"...","environment":"preview"}
```

### Deploy Multiple Previews

```bash
# Deploy PR #2
./scripts/deploy-preview.sh 2

# Deploy PR #42
./scripts/deploy-preview.sh 42

# Each gets its own namespace and URL path
# http://localhost:8080/pr-2/
# http://localhost:8080/pr-42/
```

### List Active Previews

```bash
./scripts/list-previews.sh
```

---

##  Step 3: Expose Publicly with ngrok

### One-time Setup

1. Create a free account at [ngrok.com](https://ngrok.com)
2. Get your auth token from [dashboard.ngrok.com](https://dashboard.ngrok.com/get-started/your-authtoken)
3. Configure ngrok:

```bash
ngrok config add-authtoken YOUR_AUTH_TOKEN
```

### Start the Tunnel

```bash
./scripts/local/start-tunnel.sh
```

Or manually:
```bash
ngrok http 8080 --host-header=localhost
```

### Access Your Preview

ngrok provides a public URL like:
```
https://abc123-your-name.ngrok-free.dev
```

Your preview is now accessible at:
```
https://abc123-your-name.ngrok-free.dev/pr-1/
```

> **Note**: Free ngrok URLs change each time you restart. Paid plans get static URLs.

---

##  Step 4: Cleanup

### Destroy a Single Preview

```bash
./scripts/destroy-preview.sh 1
# Deletes namespace pr-1 and all resources in it
```

### Destroy the Entire Cluster

```bash
./scripts/local/destroy-cluster.sh
# Removes the k3d cluster completely
```

---

##  Troubleshooting

### Port 80/443 Already in Use

The scripts use ports 8080/8443 by default. If these are also in use:

```bash
HTTP_PORT=9080 HTTPS_PORT=9443 ./scripts/local/create-cluster.sh
```

### Docker Not Running

```bash
# Check Docker status
docker info

# If not running, start Docker Desktop
```

### Image Not Found in k3d

If pods show `ImagePullBackOff`:

```bash
# Re-import the image
k3d image import preview-app:latest -c pr-previews
```

### Ingress Not Routing

Check ingress controller logs:
```bash
kubectl logs -n ingress-nginx -l app.kubernetes.io/component=controller
```

Verify ingress rules:
```bash
kubectl get ingress -A
kubectl describe ingress preview-app -n pr-1
```

### WSL2-Specific Issues

If using Windows with WSL2:

1. **Ensure Docker Desktop WSL2 integration is enabled**
   - Docker Desktop  Settings  Resources  WSL Integration

2. **Run scripts from WSL2 terminal**, not PowerShell

3. **Access via localhost** works in most cases, but you can also use:
   ```bash
   curl http://$(hostname).local:8080/pr-1/
   ```

---

##  Resource Usage

Local development is lightweight:

| Resource | Usage |
|----------|-------|
| CPU | ~0.5 core idle, ~2 cores during builds |
| Memory | ~1.5 GB for cluster + ~100MB per preview |
| Disk | ~2 GB for images and cluster data |

---

##  What You're Learning

By running this locally, you gain hands-on experience with:

- **k3d/k3s**: Lightweight Kubernetes distributions
- **kubectl**: Kubernetes CLI operations
- **Namespaces**: Isolating workloads
- **Ingress**: HTTP routing with path-based rules
- **Docker**: Building and managing images
- **ngrok**: Exposing local services publicly

---

##  Next Steps

Once comfortable with local development:

1. **Customize the app** - Edit `app/src/index.ts` and redeploy
2. **Add your own app** - Replace the sample with your real application
3. **Try EKS** - Deploy to AWS for a production-grade setup

 **[EKS Setup Guide ](EKS_SETUP.md)**
