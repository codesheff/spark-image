#!/bin/bash

# Release & Deploy Script: Add new Spark/Livy version and deploy to Kubernetes
# Usage: ./scripts/release-version.sh <spark_version> <livy_version> [--deploy]
# Examples:
#   ./scripts/release-version.sh 3.5.7 0.8.0          # Generate overlays only
#   ./scripts/release-version.sh 3.5.7 0.8.0 --deploy # Generate and deploy
#   ./scripts/release-version.sh                       # Interactive mode

set -e

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GENERATE_SCRIPT="$SCRIPT_DIR/scripts/generate-overlays.sh"
NAMESPACE="spark-livy"

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Helper functions
print_header() {
    echo -e "\n${BLUE}════════════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}  $1${NC}"
    echo -e "${BLUE}════════════════════════════════════════════════════════════════${NC}\n"
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

print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

# Validate versions
validate_version() {
    local version=$1
    local type=$2
    
    if [[ ! $version =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        print_error "Invalid $type version format: $version (expected X.Y.Z)"
        return 1
    fi
    return 0
}

# Get versions from user input or arguments
get_versions() {
    local spark_ver=$1
    local livy_ver=$2
    
    # If not provided as arguments, prompt user
    if [ -z "$spark_ver" ]; then
        echo "Enter Spark version (e.g., 3.5.7): "
        read -r spark_ver
    fi
    
    if [ -z "$livy_ver" ]; then
        echo "Enter Livy version (e.g., 0.8.0): "
        read -r livy_ver
    fi
    
    # Validate
    validate_version "$spark_ver" "Spark" || exit 1
    validate_version "$livy_ver" "Livy" || exit 1
    
    echo "$spark_ver:$livy_ver"
}

# Update generate-overlays.sh with new version
update_generate_script() {
    local spark_ver=$1
    local livy_ver=$2
    
    print_step "Updating $GENERATE_SCRIPT..."
    
    # Check if version already exists
    if grep -q "\\[\"$spark_ver\"\\]" "$GENERATE_SCRIPT"; then
        print_info "Version $spark_ver already exists in script"
        read -p "Overwrite? (y/n) " -r
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            print_error "Cancelled"
            return 1
        fi
        # Remove existing version
        sed -i "/\[\"$spark_ver\"\]/d" "$GENERATE_SCRIPT"
    fi
    
    # Add new version to VERSIONS array (before closing parenthesis)
    sed -i "/^)/i\\    [\"$spark_ver\"]=\"$livy_ver\"" "$GENERATE_SCRIPT"
    
    print_success "Updated $GENERATE_SCRIPT with Spark $spark_ver + Livy $livy_ver"
}

# Run generate-overlays.sh
run_generate_script() {
    print_step "Running generate-overlays.sh..."
    
    if ! "$GENERATE_SCRIPT"; then
        print_error "Failed to generate overlays"
        return 1
    fi
    
    print_success "Overlays generated successfully"
}

# Test kustomize overlays
test_overlays() {
    local spark_ver=$1
    
    print_step "Testing Kustomize overlay for Spark $spark_ver..."
    
    local overlay_dir="$SCRIPT_DIR/k8s/overlays/spark-$spark_ver"
    
    if [ ! -d "$overlay_dir" ]; then
        print_error "Overlay directory not found: $overlay_dir"
        return 1
    fi
    
    # Test kustomize build
    if ! kubectl kustomize "$overlay_dir" >/dev/null 2>&1; then
        print_error "Kustomize validation failed"
        return 1
    fi
    
    # Show image being deployed
    local image=$(kubectl kustomize "$overlay_dir" 2>/dev/null | grep "image: stedoh" | head -1 | tr -d ' ')
    print_info "Deployment will use: $image"
    
    print_success "Kustomize overlay validation passed"
}

# Deploy to Kubernetes
deploy_to_kubernetes() {
    local spark_ver=$1
    
    print_step "Deploying Spark $spark_ver to Kubernetes..."
    
    # Check if namespace exists
    if ! kubectl get namespace "$NAMESPACE" &>/dev/null; then
        print_error "Namespace '$NAMESPACE' does not exist"
        print_info "Create it with: kubectl create namespace $NAMESPACE"
        return 1
    fi
    
    # Confirm deployment
    read -p "Deploy Spark $spark_ver to production? (y/n) " -r
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_info "Deployment cancelled"
        return 0
    fi
    
    local overlay_dir="$SCRIPT_DIR/k8s/overlays/spark-$spark_ver"
    
    # Delete existing Deployment if it exists (to reset immutable fields)
    if kubectl get deployment spark-livy -n "$NAMESPACE" &>/dev/null; then
        print_info "Deleting existing Deployment to reset immutable selector fields..."
        if ! kubectl delete deployment spark-livy -n "$NAMESPACE" --grace-period=30; then
            print_error "Failed to delete existing Deployment"
            return 1
        fi
        # Wait a moment for the delete to fully process
        sleep 2
    fi
    
    # Apply deployment
    if kubectl apply -k "$overlay_dir"; then
        print_success "Deployment applied successfully"
    else
        print_error "Deployment failed"
        return 1
    fi
    
    # Wait for rollout
    print_step "Waiting for deployment to be ready..."
    if kubectl rollout status deployment/spark-livy -n "$NAMESPACE" --timeout=120s; then
        print_success "Deployment is ready"
    else
        print_error "Deployment failed to become ready"
        return 1
    fi
}

# Verify deployment
verify_deployment() {
    local spark_ver=$1
    
    print_step "Verifying deployment..."
    
    # Check pod status
    echo ""
    kubectl -n "$NAMESPACE" get pods -L spark-version,livy-version
    echo ""
    
    # Check image
    local pod=$(kubectl -n "$NAMESPACE" get pods -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
    if [ -z "$pod" ]; then
        print_error "No pods found in namespace"
        return 1
    fi
    
    local image=$(kubectl -n "$NAMESPACE" get pod "$pod" -o jsonpath='{.spec.containers[0].image}')
    print_info "Running image: $image"
    
    if [[ "$image" == *"$spark_ver"* ]]; then
        print_success "Image version matches expected version"
    else
        print_error "Image version mismatch"
        return 1
    fi
    
    print_success "Deployment verification passed"
}

# Main flow
main() {
    local spark_ver=$1
    local livy_ver=$2
    local deploy_flag=$3
    
    print_header "Spark-Livy Release & Deployment Script"
    
    # Get versions
    if [ -z "$spark_ver" ]; then
        echo "Version Information:"
        versions=$(get_versions)
        spark_ver=$(echo "$versions" | cut -d: -f1)
        livy_ver=$(echo "$versions" | cut -d: -f2)
    fi
    
    echo "Release Configuration:"
    echo "  Spark Version: $spark_ver"
    echo "  Livy Version: $livy_ver"
    echo "  Namespace: $NAMESPACE"
    echo ""
    
    # Step 1: Update generate script
    if ! update_generate_script "$spark_ver" "$livy_ver"; then
        exit 1
    fi
    
    sleep 1
    
    # Step 2: Generate overlays
    if ! run_generate_script; then
        exit 1
    fi
    
    sleep 1
    
    # Step 3: Test overlays
    if ! test_overlays "$spark_ver"; then
        exit 1
    fi
    
    sleep 1
    
    # Step 4: Deploy (if requested or flag provided)
    if [ "$deploy_flag" = "--deploy" ] || [ "$deploy_flag" = "-d" ]; then
        if ! deploy_to_kubernetes "$spark_ver"; then
            exit 1
        fi
        
        sleep 2
        
        # Step 5: Verify
        if ! verify_deployment "$spark_ver"; then
            exit 1
        fi
    else
        print_info "Skipping deployment (use --deploy flag to deploy)"
        echo ""
        echo "To deploy this version, run:"
        echo "  kubectl apply -k k8s/overlays/spark-$spark_ver/"
        echo ""
        echo "Or use this script with --deploy flag:"
        echo "  ./scripts/release-version.sh $spark_ver $livy_ver --deploy"
    fi
    
    print_header "Release Complete"
    echo "Version Spark $spark_ver + Livy $livy_ver is ready for use!"
    echo ""
    echo "Useful commands:"
    echo "  View overlay: kubectl kustomize k8s/overlays/spark-$spark_ver/"
    echo "  Deploy: kubectl apply -k k8s/overlays/spark-$spark_ver/"
    echo "  Test: ./scripts/test-livy.sh"
    echo "  Check pods: kubectl -n $NAMESPACE get pods -L spark-version,livy-version"
    echo ""
}

# Show usage
if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
    cat << EOF
Usage: ./scripts/release-version.sh [OPTIONS]

Add a new Spark/Livy version and optionally deploy it to Kubernetes.

OPTIONS:
  <spark_version>     Spark version (e.g., 3.5.7)
  <livy_version>      Livy version (e.g., 0.8.0)
  --deploy, -d        Deploy immediately after generation (optional)
  --help, -h          Show this help message

EXAMPLES:
  # Interactive mode (prompts for versions)
  ./scripts/release-version.sh

  # Generate overlays only
  ./scripts/release-version.sh 3.5.7 0.8.0

  # Generate and deploy
  ./scripts/release-version.sh 3.5.7 0.8.0 --deploy

STEPS:
  1. Updates scripts/generate-overlays.sh with new version
  2. Runs generate-overlays.sh to create overlay files
  3. Tests Kustomize overlay validation
  4. Optionally deploys to Kubernetes
  5. Optionally verifies deployment

EOF
    exit 0
fi

# Run main
main "$@"
