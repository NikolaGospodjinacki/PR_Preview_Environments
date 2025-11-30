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

echo "📄 Applying Kubernetes manifests..."

# Apply Deployment
cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: preview-app
  namespace: $NAMESPACE
  labels:
    app: preview-app
    pr-number: "$PR_NUMBER"
spec:
  replicas: 1
  selector:
    matchLabels:
      app: preview-app
  template:
    metadata:
      labels:
        app: preview-app
    spec:
      containers:
        - name: preview-app
          image: $IMAGE
          imagePullPolicy: Never
          ports:
            - containerPort: 3000
          env:
            - name: PORT
              value: "3000"
            - name: PR_NUMBER
              value: "$PR_NUMBER"
            - name: GIT_SHA
              value: "$GIT_SHA"
          resources:
            requests:
              memory: "64Mi"
              cpu: "50m"
            limits:
              memory: "128Mi"
              cpu: "100m"
          livenessProbe:
            httpGet:
              path: /health
              port: 3000
            initialDelaySeconds: 5
            periodSeconds: 10
          readinessProbe:
            httpGet:
              path: /health
              port: 3000
            initialDelaySeconds: 3
            periodSeconds: 5
EOF

# Apply Service
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Service
metadata:
  name: preview-app
  namespace: $NAMESPACE
  labels:
    app: preview-app
spec:
  type: ClusterIP
  ports:
    - port: 80
      targetPort: 3000
      protocol: TCP
  selector:
    app: preview-app
EOF

# Apply Ingress
cat <<EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: preview-app
  namespace: $NAMESPACE
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /\$2
spec:
  ingressClassName: nginx
  rules:
    - http:
        paths:
          - path: /pr-$PR_NUMBER(/|$)(.*)
            pathType: ImplementationSpecific
            backend:
              service:
                name: preview-app
                port:
                  number: 80
EOF

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
echo "   Local: http://localhost:8080/pr-$PR_NUMBER/"
echo "   Ngrok: https://<your-ngrok-url>/pr-$PR_NUMBER/"
echo ""
echo "📊 Check status:"
echo "   kubectl get all -n $NAMESPACE"
