#!/bin/bash
set -e

# Usage: ./scripts/destroy-preview.sh <pr-number>
PR_NUMBER=$1

if [ -z "$PR_NUMBER" ]; then
    echo "Usage: ./scripts/destroy-preview.sh <pr-number>"
    echo "Example: ./scripts/destroy-preview.sh 123"
    exit 1
fi

NAMESPACE="pr-$PR_NUMBER"

echo "🗑️  Destroying preview for PR #$PR_NUMBER"
echo "   Namespace: $NAMESPACE"
echo ""

# Check if namespace exists
if ! kubectl get namespace "$NAMESPACE" &> /dev/null; then
    echo "⚠️  Namespace $NAMESPACE does not exist"
    exit 0
fi

# Delete namespace (this deletes everything in it)
kubectl delete namespace "$NAMESPACE" --wait=true

echo ""
echo "✅ Preview destroyed successfully!"
echo "   Namespace $NAMESPACE deleted"
