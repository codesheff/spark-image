#!/bin/bash

# Script to build Spark-Livy Docker image with configurable versions
# Usage: ./build-image.sh [spark-version] [livy-version] [image-tag]
#
# Examples:
#   ./build-image.sh                           # Builds with defaults (2.4.8, 0.7.1)
#   ./build-image.sh 2.4.8 0.7.1               # Explicit stable version
#   ./build-image.sh 3.3.2 0.7.1 3.3.2         # Spark 3.3.2 with tag
#   ./build-image.sh 3.5.1 0.8.0 cutting-edge # Cutting edge versions

set -e

# Default versions (stable compatible)
SPARK_VERSION="${1:-2.4.8}"
LIVY_VERSION="${2:-0.7.1}"
IMAGE_TAG="${3:-$SPARK_VERSION}"

# Parse image tag for different formats
REGISTRY="stedoh"
IMAGE_NAME="spark-livy"
FULL_TAG="${REGISTRY}/${IMAGE_NAME}:${IMAGE_TAG}"

echo "════════════════════════════════════════════════════════════════"
echo "Building Spark-Livy Docker Image"
echo "════════════════════════════════════════════════════════════════"
echo ""
echo "Configuration:"
echo "  Spark Version:     $SPARK_VERSION"
echo "  Livy Version:      $LIVY_VERSION"
echo "  Image Tag:         $IMAGE_TAG"
echo "  Full Image:        $FULL_TAG"
echo ""
echo "════════════════════════════════════════════════════════════════"
echo ""

# Build the image
echo "Building image..."
docker build \
  --build-arg SPARK_VERSION="${SPARK_VERSION}" \
  --build-arg LIVY_VERSION="${LIVY_VERSION}" \
  -t "spark-livy:latest" \
  -t "spark-livy:${IMAGE_TAG}" \
  .

if [ $? -eq 0 ]; then
  echo ""
  echo "✅ Build successful!"
  echo ""
  echo "Tag the image for Docker Hub:"
  echo "  docker tag spark-livy:${IMAGE_TAG} ${FULL_TAG}"
  echo ""
  echo "Push to Docker Hub:"
  echo "  docker push ${FULL_TAG}"
  echo ""
  echo "Or use the automated push:"
  echo "  ./build-image.sh ${SPARK_VERSION} ${LIVY_VERSION} ${IMAGE_TAG} --push"
else
  echo ""
  echo "❌ Build failed!"
  exit 1
fi

# Optional: Push to registry
if [ "$4" == "--push" ]; then
  echo "Pushing to Docker Hub..."
  docker tag "spark-livy:${IMAGE_TAG}" "${FULL_TAG}"
  docker push "${FULL_TAG}"
  
  if [ $? -eq 0 ]; then
    echo "✅ Push successful!"
  else
    echo "❌ Push failed!"
    exit 1
  fi
fi
