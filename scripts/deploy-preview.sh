#!/bin/bash
set -e

# Usage: ./scripts/deploy-preview.sh <pr-number> [git-sha] [image]
PR_NUMBER=$1
GIT_SHA=${2:-"local"}
IMAGE=${3:-"preview-app:latest"}

if [ -z "$PR_NUMBER" ]; then
    echo "Usage: ./scripts/deploy-preview.sh <pr-number> [git-sha] [image]"
    echo "Example: ./scripts/deploy-preview.sh 123 abc1234 myrepo/preview-app:pr-123"
    exit 1
fi

NAMESPACE="pr-$PR_NUMBER"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

echo "🚀 Deploying preview for PR #$PR_NUMBER"
echo "   Namespace: $NAMESPACE"
echo "   Git SHA: $GIT_SHA"
echo "   Image: $IMAGE"
echo ""

# Create namespace if it doesn't exist
if ! kubectl get namespace "$NAMESPACE" &> /dev/null; then
    echo "📦 Creating namespace: $NAMESPACE"
    kubectl create namespace "$NAMESPACE"
    kubectl label namespace "$NAMESPACE" pr-preview=true pr-number="$PR_NUMBER"
fi

# Build image locally if using default
if [ "$IMAGE" = "preview-app:latest" ]; then
    echo "🔨 Building Docker image locally..."
    docker build -t preview-app:latest "$PROJECT_ROOT/app"
    
    # Import into k3d
    echo "📥 Importing image into k3d cluster..."
    k3d image import preview-app:latest -c pr-previews
fi

# Create temporary kustomization overlay
TEMP_DIR=$(mktemp -d)
trap "rm -rf $TEMP_DIR" EXIT

cat > "$TEMP_DIR/kustomization.yaml" << EOF
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
  - $PROJECT_ROOT/k8s/base

namespace: $NAMESPACE

patches:
  - patch: |-
      - op: replace
        path: /spec/template/spec/containers/0/env/1/value
        value: "$PR_NUMBER"
    target:
      kind: Deployment
      name: preview-app
  - patch: |-
      - op: replace
        path: /spec/template/spec/containers/0/env/2/value
        value: "$GIT_SHA"
    target:
      kind: Deployment
      name: preview-app
  - patch: |-
      - op: replace
        path: /spec/rules/0/http/paths/0/path
        value: "/pr-$PR_NUMBER"
    target:
      kind: Ingress
      name: preview-app
  - patch: |-
      - op: add
        path: /metadata/annotations/nginx.ingress.kubernetes.io~1rewrite-target
        value: "/"
    target:
      kind: Ingress
      name: preview-app
  - patch: |-
      - op: replace
        path: /spec/rules/0/host
        value: ""
    target:
      kind: Ingress
      name: preview-app

images:
  - name: preview-app
    newName: ${IMAGE%:*}
    newTag: ${IMAGE#*:}
EOF

# Apply manifests
echo "📄 Applying Kubernetes manifests..."
kubectl apply -k "$TEMP_DIR"

# Wait for deployment
echo "⏳ Waiting for deployment to be ready..."
kubectl wait --namespace "$NAMESPACE" \
    --for=condition=available deployment/preview-app \
    --timeout=120s

echo ""
echo "✅ Preview deployed successfully!"
echo ""
echo "📋 Preview Info:"
echo "   Namespace: $NAMESPACE"
echo "   PR Number: $PR_NUMBER"
echo "   Git SHA: $GIT_SHA"
echo ""
echo "🔗 Access URLs:"
echo "   Local: http://localhost/pr-$PR_NUMBER/"
echo "   Ngrok: https://<your-ngrok-url>/pr-$PR_NUMBER/"
echo ""
echo "📊 Check status:"
echo "   kubectl get all -n $NAMESPACE"
