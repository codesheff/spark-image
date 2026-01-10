#!/bin/bash

# Redeploy Spark-Livy Kubernetes Environment
# Usage: ./scripts/redeploy.sh [version]
# Examples:
#   ./scripts/redeploy.sh 2.4.8    # Deploy Spark 2.4.8
#   ./scripts/redeploy.sh 3.5.7    # Deploy Spark 3.5.7
#   ./scripts/redeploy.sh          # Default to 3.5.7

set -e

# Configuration
NAMESPACE="spark-livy"
DEFAULT_VERSION="3.5.7"
VERSION="${1:-$DEFAULT_VERSION}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Helper functions
print_header() {
    echo -e "\n${BLUE}══════════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}  $1${NC}"
    echo -e "${BLUE}══════════════════════════════════════════════════════════════${NC}\n"
}

print_step() {
    echo -e "${YELLOW}▶ $1${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

# Validate version
validate_version() {
    case "$1" in
        2.4.8|3.5.7)
            return 0
            ;;
        *)
            print_error "Invalid version: $1"
            echo "Supported versions: 2.4.8, 3.5.7"
            exit 1
            ;;
    esac
}

# Main script
print_header "Spark-Livy Kubernetes Redeployment"

echo "Configuration:"
echo "  Namespace: $NAMESPACE"
echo "  Version: Spark $VERSION + Livy $([ "$VERSION" = "2.4.8" ] && echo "0.7.1" || echo "0.8.0")"
echo "  Project: $SCRIPT_DIR"
echo ""

validate_version "$VERSION"

# Step 1: Delete namespace
print_step "Deleting namespace '$NAMESPACE'..."
if kubectl get namespace "$NAMESPACE" &>/dev/null; then
    kubectl delete namespace "$NAMESPACE" --wait=true --timeout=60s
    print_success "Namespace deleted"
    
    # Wait for namespace to be fully deleted
    print_step "Waiting for namespace cleanup..."
    while kubectl get namespace "$NAMESPACE" &>/dev/null; do
        sleep 1
    done
    print_success "Namespace cleanup complete"
else
    print_success "Namespace does not exist (nothing to delete)"
fi

# Step 2: Verify deletion
print_step "Verifying namespace is gone..."
if ! kubectl get namespace "$NAMESPACE" &>/dev/null; then
    print_success "Namespace verification passed"
else
    print_error "Namespace still exists after deletion"
    exit 1
fi

sleep 2

# Step 3: Deploy new environment
print_step "Deploying Spark $VERSION..."

OVERLAY_DIR="k8s/overlays/spark-$VERSION"

if [ ! -d "$OVERLAY_DIR" ]; then
    print_error "Overlay directory not found: $OVERLAY_DIR"
    exit 1
fi

cd "$SCRIPT_DIR"
kubectl apply -k "$OVERLAY_DIR"
print_success "Deployment manifests applied"

# Step 4: Wait for deployment to be ready
print_step "Waiting for pods to be ready (timeout: 120s)..."
if kubectl rollout status deployment/spark-livy -n "$NAMESPACE" --timeout=120s; then
    print_success "Deployment is ready"
else
    print_error "Deployment failed to become ready within timeout"
    echo "Current pod status:"
    kubectl -n "$NAMESPACE" get pods
    exit 1
fi

# Step 5: Verify resources
print_step "Verifying resources..."
echo ""
kubectl -n "$NAMESPACE" get all -L spark-version,livy-version
echo ""

# Step 6: Check pod status
print_step "Checking pod details..."
POD=$(kubectl -n "$NAMESPACE" get pods -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
if [ -z "$POD" ]; then
    print_error "No pod found in namespace"
    exit 1
fi

echo "Pod: $POD"
kubectl -n "$NAMESPACE" get pod "$POD" -o wide

# Step 7: Check image
print_step "Verifying container image..."
IMAGE=$(kubectl -n "$NAMESPACE" get pod "$POD" -o jsonpath='{.spec.containers[0].image}')
echo "Container image: $IMAGE"
if [[ "$IMAGE" == *"$VERSION"* ]]; then
    print_success "Image version matches deployment specification"
else
    print_error "Image version mismatch"
    exit 1
fi

print_header "Redeployment Complete"
echo "Status: $(kubectl -n "$NAMESPACE" get deployment spark-livy -o jsonpath='{.status.conditions[?(@.type=="Available")].reason}')"
echo ""
echo "Next steps:"
echo "  1. Wait for Livy to fully initialize (~10-15 seconds)"
echo "  2. Run tests: ./scripts/test-livy.sh"
echo "  3. Check logs: kubectl logs -f -n $NAMESPACE deployment/spark-livy"
echo ""
