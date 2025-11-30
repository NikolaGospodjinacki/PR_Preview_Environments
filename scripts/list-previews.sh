#!/bin/bash
set -e

echo "📋 Listing all PR preview environments"
echo ""

# Get all namespaces with pr-preview label
NAMESPACES=$(kubectl get namespaces -l pr-preview=true -o jsonpath='{.items[*].metadata.name}' 2>/dev/null || echo "")

if [ -z "$NAMESPACES" ]; then
    echo "No preview environments found."
    exit 0
fi

echo "┌─────────────┬───────────────┬──────────────────────────────┐"
echo "│ PR Number   │ Status        │ Created                      │"
echo "├─────────────┼───────────────┼──────────────────────────────┤"

for ns in $NAMESPACES; do
    PR_NUM=$(kubectl get namespace "$ns" -o jsonpath='{.metadata.labels.pr-number}' 2>/dev/null || echo "?")
    CREATED=$(kubectl get namespace "$ns" -o jsonpath='{.metadata.creationTimestamp}' 2>/dev/null || echo "?")
    
    # Check deployment status
    READY=$(kubectl get deployment preview-app -n "$ns" -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
    DESIRED=$(kubectl get deployment preview-app -n "$ns" -o jsonpath='{.spec.replicas}' 2>/dev/null || echo "1")
    
    if [ "$READY" = "$DESIRED" ]; then
        STATUS="✅ Running"
    else
        STATUS="⏳ $READY/$DESIRED"
    fi
    
    printf "│ %-11s │ %-13s │ %-28s │\n" "#$PR_NUM" "$STATUS" "$CREATED"
done

echo "└─────────────┴───────────────┴──────────────────────────────┘"
echo ""
echo "Total: $(echo $NAMESPACES | wc -w) preview environment(s)"
