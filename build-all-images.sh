#!/bin/bash

# Script to build all Spark-Livy Docker image version combinations
# Builds multiple versions for testing and validation
#
# Builds all tested version combinations:
#   - Spark 2.4.8 + Livy 0.7.1 (stable)
#   - Spark 3.5.7 + Livy 0.8.0 (cutting-edge)
#
# Usage: ./build-all-images.sh [--push]
#
# Examples:
#   ./build-all-images.sh                 # Build all images locally
#   ./build-all-images.sh --push          # Build and push all to Docker Hub

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Flags
PUSH_IMAGES=false
if [ "$1" == "--push" ]; then
  PUSH_IMAGES=true
fi

# Define version combinations: (spark_version, livy_version, tag)
declare -a VERSIONS=(
  "2.4.8:0.7.1:2.4.8"
  "3.5.7:0.8.0:3.5.7"
)

echo "════════════════════════════════════════════════════════════════"
echo "Building All Spark-Livy Docker Image Versions"
echo "════════════════════════════════════════════════════════════════"
echo ""
echo "Version Combinations to Build:"
for version_combo in "${VERSIONS[@]}"; do
  IFS=':' read -r spark_ver livy_ver tag <<< "$version_combo"
  echo "  • Spark $spark_ver + Livy $livy_ver (tag: $tag)"
done
echo ""

if [ "$PUSH_IMAGES" = true ]; then
  echo "Push Mode: ✅ ENABLED"
else
  echo "Push Mode: ❌ DISABLED (use --push to enable)"
fi
echo ""
echo "════════════════════════════════════════════════════════════════"
echo ""

# Track build results
BUILDS_PASSED=0
BUILDS_FAILED=0
FAILED_VERSIONS=()

# Build each version combination
for version_combo in "${VERSIONS[@]}"; do
  IFS=':' read -r spark_ver livy_ver tag <<< "$version_combo"
  
  echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${BLUE}Building: Spark $spark_ver + Livy $livy_ver${NC}"
  echo -e "${BLUE}Tag: $tag${NC}"
  echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo ""
  
  if [ "$PUSH_IMAGES" = true ]; then
    if ./build-image.sh "$spark_ver" "$livy_ver" "$tag" --push; then
      echo ""
      echo -e "${GREEN}✅ Build and push successful for Spark $spark_ver + Livy $livy_ver${NC}"
      ((BUILDS_PASSED++))
    else
      echo ""
      echo -e "${RED}❌ Build failed for Spark $spark_ver + Livy $livy_ver${NC}"
      ((BUILDS_FAILED++))
      FAILED_VERSIONS+=("$spark_ver + Livy $livy_ver")
    fi
  else
    if ./build-image.sh "$spark_ver" "$livy_ver" "$tag"; then
      echo ""
      echo -e "${GREEN}✅ Build successful for Spark $spark_ver + Livy $livy_ver${NC}"
      ((BUILDS_PASSED++))
    else
      echo ""
      echo -e "${RED}❌ Build failed for Spark $spark_ver + Livy $livy_ver${NC}"
      ((BUILDS_FAILED++))
      FAILED_VERSIONS+=("$spark_ver + Livy $livy_ver")
    fi
  fi
  echo ""
done

# Print summary
echo "════════════════════════════════════════════════════════════════"
echo "Build Summary"
echo "════════════════════════════════════════════════════════════════"
echo ""
echo -e "Total Builds: $((BUILDS_PASSED + BUILDS_FAILED))"
echo -e "${GREEN}✅ Successful: $BUILDS_PASSED${NC}"
echo -e "${RED}❌ Failed: $BUILDS_FAILED${NC}"
echo ""

if [ $BUILDS_FAILED -eq 0 ]; then
  echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${GREEN}All builds completed successfully!${NC}"
  echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo ""
  
  if [ "$PUSH_IMAGES" = true ]; then
    echo "Built and pushed images:"
    for version_combo in "${VERSIONS[@]}"; do
      IFS=':' read -r spark_ver livy_ver tag <<< "$version_combo"
      echo "  • stedoh/spark-livy:$tag"
    done
  else
    echo "Built local images:"
    for version_combo in "${VERSIONS[@]}"; do
      IFS=':' read -r spark_ver livy_ver tag <<< "$version_combo"
      echo "  • spark-livy:$tag"
    done
    echo ""
    echo "To push to Docker Hub, run:"
    echo "  ./build-all-images.sh --push"
  fi
  echo ""
  exit 0
else
  echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${RED}Some builds failed!${NC}"
  echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo ""
  echo "Failed versions:"
  for failed_ver in "${FAILED_VERSIONS[@]}"; do
    echo "  • $failed_ver"
  done
  echo ""
  exit 1
fi
