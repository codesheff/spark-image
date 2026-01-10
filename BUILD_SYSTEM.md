# Spark-Livy Docker Build System

## Overview

The Spark-Livy Docker build system is now fully configurable, allowing easy version switching without manually editing the Dockerfile.

## When to Use Different Build Methods

### Use `build-image.sh` (Recommended) When:
- Building custom Spark/Livy version combinations
- Creating multiple images for different versions (stable, testing, cutting-edge)
- Pushing to Docker Hub or custom registries
- Automating version-based builds in CI/CD
- Testing alpha/beta versions before release

### Use `docker build` directly When:
- Testing default versions (Spark 2.4.8 + Livy 0.7.1) locally
- Building with minimal overhead
- Integrating with custom build systems

## Quick Start

### Default Build (Spark 2.4.8 + Livy 0.7.1)
```bash
cd /home/stedo/spark-image
./build-image.sh
```

### Build Specific Versions
```bash
./build-image.sh 2.4.8 0.7.1 2.4.8         # Spark 2.4.8, Livy 0.7.1, tag as '2.4.8'
./build-image.sh 3.3.2 0.7.1 3.3.2         # Spark 3.3.2, Livy 0.7.1, tag as '3.3.2'
./build-image.sh 3.5.1 0.8.0 3.5.1-alpha   # Spark 3.5.1, Livy 0.8.0, tag as '3.5.1-alpha'
```

### Build and Push to Docker Hub
```bash
./build-image.sh 2.4.8 0.7.1 2.4.8 --push
```

## Build System Components

### 1. Dockerfile Arguments

The Dockerfile now accepts two build arguments:

```dockerfile
ARG SPARK_VERSION=2.4.8
ARG LIVY_VERSION=0.7.1
```

**Usage**:
```bash
docker build \
  --build-arg SPARK_VERSION=2.4.8 \
  --build-arg LIVY_VERSION=0.7.1 \
  -t spark-livy:2.4.8 \
  .
```

### 2. build-image.sh Script

Automated script that:
- Validates arguments
- Runs Docker build with correct arguments
- Tags image appropriately
- Optionally pushes to Docker Hub
- Provides clear status output

**Location**: `/home/stedo/spark-image/build-image.sh`

**Permissions**: Executable (`755`)

### 3. Supported Version Matrix

| Spark | Livy | Status | Image Tag | Tested |
|-------|------|--------|-----------|--------|
| 2.4.8 | 0.7.1 | ✅ Working | `2.4.8` | Yes |
| 2.4.7 | 0.7.1 | ✅ Should work | `2.4.7` | No |
| 3.2.4 | 0.7.1 | ⚠️ Issues | `3.2.4` | Partial |
| 3.3.2 | 0.7.1 | ❌ Broken | `3.3.2` | Yes |
| 3.5.1 | 0.8.0 | 🚀 Alpha | `3.5.1-alpha` | No |

## Docker Hub Registry

Images are automatically tagged and can be pushed to Docker Hub:

```bash
# Build and push to stedoh/spark-livy:<version>
./build-image.sh 2.4.8 0.7.1 2.4.8 --push

# Equivalent manual commands:
docker build --build-arg SPARK_VERSION=2.4.8 --build-arg LIVY_VERSION=0.7.1 -t spark-livy:2.4.8 .
docker tag spark-livy:2.4.8 stedoh/spark-livy:2.4.8
docker push stedoh/spark-livy:2.4.8
```

## Configuration Files

After building, you can customize behavior via configuration files:

### Spark Configuration
**File**: `config/spark-defaults.conf`

```properties
spark.master          local[*]
spark.pyspark.python  /usr/bin/python3
spark.driver.memory   1g
spark.executor.cores  1
```

### Livy Configuration
**File**: `config/livy-server.conf`

```properties
livy.spark.master              local[*]
livy.spark.deploy-mode         client
livy.spark.driver.memory       1g
livy.spark.executor.memory     1g
livy.spark.executor.cores      1
```

These are mounted into the container via ConfigMaps in Kubernetes.

## Kubernetes Deployment

After building an image, update the Kubernetes manifest:

### 1. Update Image Reference
**File**: `k8s/spark-livy-manifest.yaml`

```yaml
spec:
  containers:
  - name: spark-livy
    image: stedoh/spark-livy:2.4.8  # Update this
```

### 2. Deploy
```bash
kubectl apply -f k8s/spark-livy-manifest.yaml
```

### 3. Verify
```bash
kubectl get pods -n spark-livy -w
```

### 4. Test API
```bash
kubectl port-forward -n spark-livy svc/spark-livy-service 8998:8998
curl http://localhost:8998/sessions | jq '.'
```

## Advanced Usage

### Building All Versions
```bash
#!/bin/bash
cd /home/stedo/spark-image

# Build stable version
./build-image.sh 2.4.8 0.7.1 2.4.8 --push

# Build alternative stable
./build-image.sh 2.4.7 0.7.1 2.4.7 --push

# Build experimental (if ready)
./build-image.sh 3.5.1 0.8.0 3.5.1-alpha --push
```

### Switching Between Versions
```bash
# Build new version
./build-image.sh 3.3.2 0.7.1 3.3.2 --push

# Update manifest
sed -i 's/stedoh\/spark-livy:2.4.8/stedoh\/spark-livy:3.3.2/g' k8s/spark-livy-manifest.yaml

# Redeploy
kubectl apply -f k8s/spark-livy-manifest.yaml

# Monitor rollout
kubectl rollout status deployment/spark-livy -n spark-livy
```

### Local Testing (No Docker Hub Push)
```bash
# Build locally but don't push
./build-image.sh 3.5.1 0.8.0 3.5.1-test

# Load into Docker Desktop K8s
docker tag spark-livy:3.5.1-test stedoh/spark-livy:3.5.1-test

# Test with kind/minikube
kind load docker-image spark-livy:3.5.1-test
minikube image load spark-livy:3.5.1-test
```

## Build Arguments Explained

### SPARK_VERSION
The Apache Spark version to install.

- **Format**: `X.Y.Z` (e.g., `2.4.8`)
- **Source**: https://archive.apache.org/dist/spark/
- **Default**: `2.4.8`
- **Compatible Downloads**:
  - Spark 2.x: Uses `hadoop2.7` packaging
  - Spark 3.x: Uses `hadoop3` packaging

### LIVY_VERSION
The Apache Livy version to install.

- **Format**: `X.Y.Z` (e.g., `0.7.1`)
- **Source**: https://archive.apache.org/dist/incubator/livy/
- **Default**: `0.7.1`
- **Note**: Livy 0.8.0+ not yet available in official builds (requires GitHub + Maven)

## Troubleshooting

### Build Fails: "No such file or directory"
**Problem**: Script `build-image.sh` not found

**Solution**:
```bash
chmod +x /home/stedo/spark-image/build-image.sh
```

### Build Fails: "failed to download Spark"
**Problem**: URL not found for version

**Solution**:
1. Check version exists: https://archive.apache.org/dist/spark/
2. Verify format is `SPARK_VERSION=2.4.8` (not `spark-2.4.8`)
3. For Spark 3.3.0+, ensure Dockerfile uses `hadoop3` path

### Docker Image is Large
**Problem**: Image size >1.5 GB

**Solution**: This is normal for JVM-based Spark. To reduce:
1. Use smaller base image (Alpine Linux) - not recommended for JVM
2. Remove test/debug packages from Dockerfile
3. Use multi-stage builds (already implemented)

### Version Not Available
**Problem**: Trying to build Spark 3.6.0 or Livy 0.9.0

**Solution**:
1. Check Apache Archive: https://archive.apache.org/dist/
2. For newer versions, may need to build from source
3. Consult VERSION_MATRIX.md for available versions

## Environment Detection

The Dockerfile automatically detects the Spark version and adjusts:

```dockerfile
# Spark 2.x uses hadoop2.7
RUN if [ "${SPARK_VERSION}" \< "3.0" ]; then \
      HADOOP_DIST="hadoop2.7"; \
    else \
      HADOOP_DIST="hadoop3"; \
    fi

# Download correct distribution
RUN wget https://archive.apache.org/dist/spark/spark-${SPARK_VERSION}/spark-${SPARK_VERSION}-bin-${HADOOP_DIST}.tgz
```

## Continuous Integration

For automated builds, add to CI/CD pipeline:

```yaml
# GitHub Actions example
- name: Build Spark-Livy Image
  run: |
    cd /home/stedo/spark-image
    ./build-image.sh ${{ matrix.spark-version }} ${{ matrix.livy-version }} ${{ matrix.spark-version }} --push
  env:
    DOCKER_USERNAME: ${{ secrets.DOCKER_USERNAME }}
    DOCKER_PASSWORD: ${{ secrets.DOCKER_PASSWORD }}
```

## Version Release Schedule

**Current Stable**: Spark 2.4.8 + Livy 0.7.1  
**Recommended Update**: Spark 3.2.4 + Livy 0.7.1 (when tested)  
**Cutting Edge**: Spark 3.5.x + Livy 0.8.0 (Q2 2026)  

## Documentation Files

- **VERSION_MATRIX.md**: Detailed version compatibility matrix
- **PHASE6_TEST_RESULTS.md**: Test results for current versions
- **PHASE6_SUMMARY.md**: Phase 6 implementation summary
- **PHASE3_IMPLEMENTATION.md**: Kubernetes setup guide

## Support

For issues or version requests:
1. Check VERSION_MATRIX.md for compatibility
2. Review PHASE6_TEST_RESULTS.md for troubleshooting
3. Update VERSION_MATRIX.md with test results if successful
4. Document new version combinations for future reference
