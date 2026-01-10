# Spark-Livy Version Matrix

This document lists tested version combinations for the Spark-Livy Docker image.

## Tested Combinations

### ✅ Stable & Compatible (Recommended for Production)

| Spark Version | Livy Version | Status | Notes | Docker Image |
|---------------|--------------|--------|-------|--------------|
| 2.4.8 | 0.7.1 | ✅ Working | PySpark ✓, Scala ✓, All features | `stedoh/spark-livy:2.4.8` |
| 2.4.7 | 0.7.1 | ✅ Working | Alternative stable version | `stedoh/spark-livy:2.4.7` |

### ⚠️ Newer but Less Stable

| Spark Version | Livy Version | Status | Notes | Docker Image |
|---------------|--------------|--------|-------|--------------|
| 3.2.4 | 0.7.1 | ⚠️ Issues | Scala classpath problems | `stedoh/spark-livy:3.2.4` |
| 3.3.2 | 0.7.1 | ❌ Broken | Scala classpath issues | `stedoh/spark-livy:3.3.2` |

### 🚀 Cutting Edge (Development/Testing)

| Spark Version | Livy Version | Status | Notes | Docker Image |
|---------------|--------------|--------|-------|--------------|
| 3.5.7 | 0.8.0 | ✅ **NEW** | **Pre-built binary, fully tested in K8s** | `stedoh/spark-livy:3.5.7` |
| 3.5.7 | 0.8.0 | ✅ **NEW** | Alias for latest cutting edge | `stedoh/spark-livy:cutting-edge` |
| 3.5.1 | 0.8.0-snapshot | 🚀 Alpha | Requires Livy built from source | `stedoh/spark-livy:cutting-edge-3.5.1` |

## Building Specific Versions

### Quick Build

```bash
# Build default (Spark 2.4.8 + Livy 0.7.1)
./build-image.sh

# Build and push to Docker Hub
./build-image.sh 2.4.8 0.7.1 2.4.8 --push
```

### Manual Docker Build

```bash
# Spark 2.4.8 + Livy 0.7.1
docker build \
  --build-arg SPARK_VERSION=2.4.8 \
  --build-arg LIVY_VERSION=0.7.1 \
  -t spark-livy:2.4.8 \
  .

# Spark 3.5.1 (requires special Livy setup)
docker build \
  --build-arg SPARK_VERSION=3.5.1 \
  --build-arg LIVY_VERSION=0.8.0 \
  -t spark-livy:3.5.1 \
  .
```

## Version Selection Guide

### Choose Spark 2.4.8 if you need:
- ✅ Proven stability
- ✅ Full Scala REPL support
- ✅ No compatibility issues
- ✅ Production-ready environment
- ❌ Newer Spark features

### Choose Spark 3.5.x if you need:
- ✅ Latest Spark features
- ✅ Better performance
- ✅ Active maintenance
- ❌ Custom Livy build from source
- ❌ Still in testing phase

## Known Issues by Version

### Spark 3.5.7 + Livy 0.8.0
- **Status**: ✅ **Fully tested and working**
- **Tested Features**:
  - ✅ PySpark interactive sessions (15s init time)
  - ✅ Scala interactive sessions (12s init time)
  - ✅ Code execution to both session types
  - ✅ Kubernetes deployment and pod lifecycle
  - ✅ Livy server startup with `start` argument
  - ⚠️ PySpark init +3s slower than 2.4.8 (+25%, acceptable)
- **Breaking Changes**:
  - Scala 2.13 (vs 2.11 in 2.4.8) - mostly compatible
  - Minor API differences in PySpark
  - Hadoop 3.3 (vs 2.7 in 2.4.8) - more efficient
- **Kubernetes Requirements**:
  - Livy 0.8.0 requires `livy-server start` (not just `livy-server`)
  - Image size increased to 1.69GB (vs 1.4GB for 2.4.8)
- **Performance**: 
  - Session initialization: 27s total (2.4.8: 24s)
  - Memory usage: ~8GB for idle cluster
  - CPU usage: Minimal at idle

### Spark 3.3.2 + Livy 0.7.1
- **Issue**: `ClassNotFoundException: scala.Function0$class`
- **Cause**: Scala library version mismatch
- **Solution**: Use Spark 2.4.8 or upgrade to 3.5.7 + Livy 0.8.0

### Spark 2.4.8 + Livy 0.7.1
- **Status**: ✅ Stable and production-ready
- **Tested Features**:
  - ✅ PySpark interactive sessions (12s init time)
  - ✅ Scala interactive sessions (12s init time)
  - ✅ Batch jobs via spark-submit
  - ✅ Kubernetes deployment
  - ✅ RBAC and ServiceAccount integration
- **Known Limitations**:
  - Spark 2.x end-of-life (no longer actively maintained)
  - Scala 2.11 (older but stable)
  - Hadoop 2.7 (older but stable)

## Migration Paths

### From Spark 2.4.8 → 3.5.7 (RECOMMENDED for Cutting Edge)
1. Download new image: `docker pull stedoh/spark-livy:cutting-edge`
2. Update Kubernetes manifest to use: `stedoh/spark-livy:3.5.7`
3. Test in staging environment first (both PySpark and Scala sessions)
4. Monitor resource usage (expect ~8GB idle, more for active workloads)
5. Update application code for Spark 3.5.7 API changes if needed
6. Redeploy to production during maintenance window

**Compatibility Notes**:
- Most PySpark code is compatible without changes
- Scala code may need updates for Scala 2.13
- Configuration files mostly compatible (check spark-defaults.conf)
- YARN/Hadoop configs need Hadoop 3.3 compatibility check

### From Spark 3.3.2 → 2.4.8
1. Download new image: `docker pull stedoh/spark-livy:2.4.8`
2. Update Kubernetes manifest to use new image tag
3. Test in staging environment first
4. Redeploy to production

### From Spark 3.3.2 → 3.5.7 (Alternative)
1. Build new Livy 0.8.0 image
2. Build image with new versions (use Spark 3.5.7 + Livy 0.8.0)
3. Extensive testing required
4. Test both PySpark and Scala workloads

### Docker Image Build Commands

```bash
# Build Spark 3.5.7 + Livy 0.8.0 (Cutting Edge)
docker build \
  --build-arg SPARK_VERSION=3.5.7 \
  --build-arg LIVY_VERSION=0.8.0 \
  -t spark-livy:3.5.7 \
  -t spark-livy:cutting-edge \
  .

# Build Spark 2.4.8 + Livy 0.7.1 (Stable)
docker build \
  --build-arg SPARK_VERSION=2.4.8 \
  --build-arg LIVY_VERSION=0.7.1 \
  -t spark-livy:2.4.8 \
  .

# Push to Docker Hub
docker tag spark-livy:3.5.7 stedoh/spark-livy:3.5.7
docker tag spark-livy:cutting-edge stedoh/spark-livy:cutting-edge
docker push stedoh/spark-livy:3.5.7
docker push stedoh/spark-livy:cutting-edge
```

### Kubernetes Deployment Update

```bash
# Switch to Cutting Edge (3.5.7)
kubectl set image deployment/spark-livy \
  spark-livy=stedoh/spark-livy:cutting-edge \
  -n spark-livy

# Switch back to Stable (2.4.8)
kubectl set image deployment/spark-livy \
  spark-livy=stedoh/spark-livy:2.4.8 \
  -n spark-livy

# Verify deployment
kubectl rollout status deployment/spark-livy -n spark-livy
```
4. Plan for potential code changes

## Testing Commands

After deploying a version, test with:

```bash
# Check Livy is running
kubectl exec -n spark-livy pod-name -- curl localhost:8998/sessions

# Create PySpark session
curl -X POST http://localhost:8998/sessions \
  -H "Content-Type: application/json" \
  -d '{"kind":"pyspark"}'

# Create Scala session
curl -X POST http://localhost:8998/sessions \
  -H "Content-Type: application/json" \
  -d '{"kind":"spark"}'
```

## Contributing New Versions

To test a new version combination:
1. Update VERSION_MATRIX.md with test results
2. Run full test suite
3. Document any known issues
4. Update build-image.sh if needed
5. Create GitHub issue with test results
