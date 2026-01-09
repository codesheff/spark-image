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
| 3.5.1 | 0.8.0-snapshot | 🚀 Alpha | Requires Livy built from source | `stedoh/spark-livy:cutting-edge` |

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

### Spark 3.3.2 + Livy 0.7.1
- **Issue**: `ClassNotFoundException: scala.Function0$class`
- **Cause**: Scala library version mismatch
- **Solution**: Use Spark 2.4.8 instead or upgrade Livy to 0.8.0-snapshot

### Spark 2.4.8 + Livy 0.7.1
- **Status**: No known issues
- **Tested Features**:
  - ✅ PySpark interactive sessions
  - ✅ Scala interactive sessions
  - ✅ Batch jobs via spark-submit
  - ✅ Kubernetes deployment
  - ✅ RBAC and ServiceAccount integration

## Migration Paths

### From Spark 3.3.2 → 2.4.8
1. Download new image: `docker pull stedoh/spark-livy:2.4.8`
2. Update Kubernetes manifest to use new image tag
3. Test in staging environment first
4. Redeploy to production

### From Spark 2.4.8 → 3.5.1
1. Build Livy 0.8.0 from source
2. Build image with new versions
3. Extensive testing required
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
