# Migration Guide: Spark 2.4.8 → 3.5.7 with Livy 0.8.0

## Overview

This guide provides step-by-step instructions for migrating from Spark 2.4.8 + Livy 0.7.1 to Spark 3.5.7 + Livy 0.8.0 in your Kubernetes environment.

---

## Pre-Migration Assessment

### Check Current Version

```bash
# Check running Spark version
kubectl logs -n spark-livy deployment/spark-livy | grep "Spark Version"

# Current expected output: Spark 2.4.8 (git revision 4be4064) built for Hadoop 2.7.3
```

### Key Differences

| Aspect | Spark 2.4.8 | Spark 3.5.7 | Impact |
|--------|------------|-----------|--------|
| Scala Version | 2.11 | 2.13 | Code updates may be needed |
| Hadoop | 2.7 | 3.3 | Better performance, newer APIs |
| Livy | 0.7.1 | 0.8.0 | Startup changes required |
| Session Init | 12s PySpark | 15s PySpark | +3 seconds slower |
| Image Size | 1.4 GB | 1.69 GB | +290 MB larger |

---

## Step 1: Pre-Migration Planning

### 1.1 Schedule Maintenance Window
- Notify users of downtime (typically 30-60 minutes)
- Schedule during low-traffic hours
- Document rollback plan

### 1.2 Backup Current State
```bash
# Export current Kubernetes deployment
kubectl get deployment spark-livy -n spark-livy -o yaml > spark-livy-2.4.8-backup.yaml

# Save current pod name for reference
kubectl get pods -n spark-livy
```

### 1.3 Test Application Compatibility
```bash
# Test critical PySpark scripts
spark-submit --master local tests/test_pyspark.py

# Test Scala if used
spark-shell --version  # Check versions before migration
```

---

## Step 2: Pre-Migration Checks

### 2.1 Verify Cutting Edge Image is Available
```bash
# Pull and verify the new image locally
docker pull stedoh/spark-livy:3.5.7

# Verify image contains correct Spark version
docker run --rm stedoh/spark-livy:3.5.7 \
  /opt/spark/bin/spark-submit --version 2>&1 | head -3
# Expected: version 3.5.7
```

### 2.2 Check Application Dependencies
Review your applications for these common Spark 2.x → 3.x issues:

```python
# ❌ SPARK 2.x API (may not work in 3.5.7)
from pyspark.sql import *
df.createOrReplaceTempView("table")  # Deprecated syntax

# ✅ SPARK 3.x API (works in both)
from pyspark.sql import SparkSession
df.createOrReplaceTempView("table")  # Works in 3.5.7

# Other common changes:
# - DataFrame.toPandas() → still works
# - SQL functions → mostly compatible
# - RDD operations → still compatible
```

### 2.3 Check Configuration Files
```bash
# Review spark-defaults.conf
cat config/spark-defaults.conf

# Key things to check:
# - spark.driver.memory - increase by 10% for 3.5.7
# - spark.executor.memory - increase by 10% for 3.5.7
# - spark.sql.shuffle.partitions - verify still appropriate
```

---

## Step 3: Create Staging Environment

### 3.1 Deploy to Staging Cluster
```bash
# Option 1: Separate namespace
kubectl create namespace spark-livy-staging
kubectl apply -f k8s/spark-livy-manifest.yaml -n spark-livy-staging

# Update image in manifest
kubectl set image deployment/spark-livy \
  spark-livy=stedoh/spark-livy:3.5.7 \
  -n spark-livy-staging

# Wait for pod to start
kubectl wait --for=condition=Ready pod -l app=spark-livy \
  -n spark-livy-staging --timeout=180s
```

### 3.2 Verify Staging Deployment
```bash
# Check pod logs
kubectl logs -n spark-livy-staging deployment/spark-livy | tail -20

# Verify Spark version
kubectl exec -n spark-livy-staging -it deployment/spark-livy \
  -- /opt/spark/bin/spark-submit --version 2>&1 | head -3
# Expected: version 3.5.7
```

### 3.3 Run Comprehensive Tests
```bash
# Test PySpark session creation
kubectl exec -n spark-livy-staging -it deployment/spark-livy \
  -- curl -X POST http://localhost:8998/sessions \
  -H "Content-Type: application/json" \
  -d '{"kind": "pyspark"}'

# Test Scala session creation
kubectl exec -n spark-livy-staging -it deployment/spark-livy \
  -- curl -X POST http://localhost:8998/sessions \
  -H "Content-Type: application/json" \
  -d '{"kind": "scala"}'

# Run full test suite
./scripts/test-livy.sh localhost 8998 true
```

### 3.4 Application Testing in Staging
```bash
# Run your critical jobs against staging
# Example: Pi estimation job
spark-submit \
  --master k8s://https://$(kubectl config view --minify -o jsonpath='{.clusters[0].cluster.server}') \
  --deploy-mode cluster \
  --conf spark.kubernetes.container.image=stedoh/spark-livy:3.5.7 \
  local:///opt/spark/examples/src/main/python/pi.py 10

# Monitor job execution
kubectl get jobs -n spark-livy-staging
kubectl logs -n spark-livy-staging job/pi-job
```

---

## Step 4: Production Migration

### 4.1 Take Database/State Snapshots
```bash
# If using external data sources, snapshot them
# Examples:
# - Database backups
# - Pending job queues
# - Session state if persisted

# Document current metrics
kubectl top pod -n spark-livy
```

### 4.2 Drain Existing Sessions
```bash
# Stop accepting new jobs (if possible)
# Option 1: Scale deployment to 0
kubectl scale deployment spark-livy --replicas=0 -n spark-livy

# Wait for existing sessions to complete
sleep 120  # Adjust based on typical session duration

# Verify all sessions are complete
kubectl exec -it deployment/spark-livy -n spark-livy \
  -- curl http://localhost:8998/sessions 2>/dev/null | grep -c '"id"'
# Expected: 0 sessions remaining
```

### 4.3 Update Kustomize Overlays
```bash
# Update the generate-overlays script if adding new versions
# Edit scripts/generate-overlays.sh and add new version to VERSIONS array
# Example for Spark X.Y.Z + Livy A.B.C:
#   ["X.Y.Z"]="A.B.C"

# Regenerate all overlay kustomization.yaml files
./scripts/generate-overlays.sh

# Verify overlays were generated correctly
kubectl kustomize k8s/overlays/spark-3.5.7/ | grep "image: stedoh" | sort -u
```

### 4.4 Deploy Using Kustomize
```bash
# For standard production deployment (recommended)
kubectl apply -k k8s/overlays/spark-3.5.7/

# Or for Spark 2.4.8 (if needed)
kubectl apply -k k8s/overlays/spark-2.4.8/

# Watch deployment progress
kubectl rollout status deployment/spark-livy -n spark-livy -w
```

### 4.5 Verify New Deployment
```bash
# Check pod is running
kubectl get pods -n spark-livy

# Verify Spark version in logs
kubectl logs -n spark-livy deployment/spark-livy | grep "Spark Version"
# Expected: Spark 3.5.7 (git revision ed00d046951) built for Hadoop 3.3.4

# Verify Livy is responding
kubectl exec -it deployment/spark-livy -n spark-livy \
  -- curl http://localhost:8998/api/version

# Run test suite
./scripts/test-livy.sh localhost 8998 true
```

---

## Step 5: Post-Migration Validation

### 5.1 Functional Testing
```bash
# Create test sessions
kubectl exec -n spark-livy deployment/spark-livy \
  -- curl -X POST http://localhost:8998/sessions \
  -H "Content-Type: application/json" \
  -d '{"kind": "pyspark"}'

# Test code execution
curl -X POST http://localhost:8998/sessions/0/statements \
  -H "Content-Type: application/json" \
  -d '{"code": "print(\"Spark 3.5.7 is running!\")"}'

# Verify result
curl http://localhost:8998/sessions/0/statements/0
```

### 5.2 Performance Validation
```bash
# Monitor resource usage (first 5 minutes)
kubectl top pod -n spark-livy

# Check logs for warnings/errors
kubectl logs -n spark-livy deployment/spark-livy | grep -E "ERROR|WARN" | head -20

# Expected warnings (non-critical):
# - SLF4J multiple bindings
# - Hadoop Kerberos reflective access
# - These are normal for Livy/Spark stack
```

### 5.3 Application Testing
```bash
# Test your critical applications
# Example 1: Simple PySpark job
python -c "
from pyspark.sql import SparkSession
spark = SparkSession.builder.appName('test').getOrCreate()
df = spark.createDataFrame([(1, 'a'), (2, 'b')], ['id', 'value'])
df.show()
"

# Example 2: Scala REPL test
# Run in Livy Scala session
scala> val data = List(1,2,3)
scala> data.map(_ * 2).sum
```

### 5.4 Monitoring Setup
```bash
# Start monitoring critical metrics
# Check if applicable to your setup:
kubectl port-forward -n spark-livy svc/spark-livy 8998:8998

# Monitor Livy server status
watch -n 5 'kubectl logs -n spark-livy deployment/spark-livy | tail -20'

# Monitor resource usage
watch -n 5 'kubectl top pod -n spark-livy'
```

---

## Step 6: Rollback Plan (If Needed)

### 6.1 Quick Rollback
If issues are encountered, rollback is fast:

```bash
# Revert to previous version
kubectl set image deployment/spark-livy \
  spark-livy=stedoh/spark-livy:2.4.8 \
  -n spark-livy

# Restart deployment
kubectl rollout restart deployment/spark-livy -n spark-livy

# Wait for pod to start
kubectl wait --for=condition=Ready pod -l app=spark-livy \
  -n spark-livy --timeout=180s

# Verify rollback
kubectl logs -n spark-livy deployment/spark-livy | grep "Spark Version"
# Expected: Spark 2.4.8
```

### 6.2 Post-Rollback Steps
```bash
# Verify all sessions work
./scripts/test-livy.sh localhost 8998 true

# Check logs for errors
kubectl logs -n spark-livy deployment/spark-livy | grep -E "ERROR"

# Document the issue for investigation
# Update github issue/ticket with details
```

---

## Step 7: Post-Migration Cleanup

### 7.1 Update Documentation
```bash
# Update your internal docs to reference 3.5.7
# - Update runbooks
# - Update troubleshooting guides
# - Update team wiki

# Example:
# OLD: "Using Spark 2.4.8 with Livy 0.7.1"
# NEW: "Using Spark 3.5.7 with Livy 0.8.0"
```

### 7.2 Remove Staging Environment
```bash
# Delete staging namespace if created
kubectl delete namespace spark-livy-staging

# Clean up backup files (after confirmation)
rm spark-livy-2.4.8-backup.yaml
```

### 7.3 Update Version References
```bash
# Update any version-specific configs
# Examples:
# - Docker build scripts
# - CI/CD pipelines
# - Installation documentation
# - Team references

# Check all locations
grep -r "2.4.8" .
grep -r "0.7.1" .
```

---

## Compatibility Matrix

### PySpark Code Compatibility

| Feature | 2.4.8 | 3.5.7 | Migration Notes |
|---------|-------|-------|-----------------|
| DataFrame API | ✅ | ✅ | 99% compatible, minor deprecations |
| SQL Queries | ✅ | ✅ | Fully compatible |
| RDD Operations | ✅ | ✅ | Fully compatible |
| MLlib | ✅ | ✅ | Compatible, some API changes |
| Streaming | ✅ | ✅ | Structured Streaming recommended |
| UDFs | ✅ | ✅ | Fully compatible |

### Scala Code Compatibility

| Feature | 2.4.8 | 3.5.7 | Migration Notes |
|---------|-------|-------|-----------------|
| Scala Version | 2.11 | 2.13 | Recompile needed for compiled code |
| Spark API | ✅ | ✅ | Mostly compatible |
| Type Signatures | ⚠️ | ✅ | May need adjustments for 2.13 |
| Libraries | ⚠️ | ✅ | Some 2.11 libraries may need updates |

---

## Troubleshooting

### Issue: Pods fail to start after upgrade

**Symptom**: Pod stuck in `CrashLoopBackOff`

**Solution**:
```bash
# Check pod logs for error
kubectl logs -n spark-livy deployment/spark-livy

# Quick rollback
kubectl set image deployment/spark-livy \
  spark-livy=stedoh/spark-livy:2.4.8 -n spark-livy
```

### Issue: Sessions timeout during initialization

**Symptom**: Sessions hang in "starting" state

**Solution**:
```bash
# Check Livy server logs
kubectl logs -n spark-livy deployment/spark-livy | tail -100

# Increase session timeout in livy-server.conf
# livy.server.session.timeout = 3600

# Restart pod to apply changes
kubectl rollout restart deployment/spark-livy -n spark-livy
```

### Issue: PySpark slower than expected

**Symptom**: Session initialization takes 15+ seconds

**Expected Behavior**: 
- 2.4.8: ~12 seconds
- 3.5.7: ~15 seconds (+3 seconds)

**Solution**: This is normal. Monitor for further degradation.

---

## Success Criteria

Migration is successful when:

✅ New image (3.5.7) deployed to production  
✅ PySpark sessions create and initialize correctly  
✅ Scala sessions create and initialize correctly  
✅ Code execution works in both session types  
✅ No critical errors in pod logs  
✅ Resource usage within expected limits  
✅ Application tests pass  
✅ Monitoring and alerting working  

---

## References

- [Spark 3.5 Release Notes](https://spark.apache.org/releases/spark-release-3-5-0.html)
- [Livy 0.8.0 Documentation](https://livy.apache.org/docs/latest/index.html)
- [Hadoop 3.3 Migration Guide](https://hadoop.apache.org/docs/stable/hadoop-project-dist/hadoop-common/upgrade.html)
- [VERSION_MATRIX.md](./VERSION_MATRIX.md) - Complete version compatibility matrix

---

## Support

If you encounter issues during migration:

1. Check [TROUBLESHOOTING.md](./TROUBLESHOOTING.md) for solutions
2. Review Livy server logs in `/var/log/livy/`
3. Consult the rollback plan in Step 6
4. Open an issue with complete pod logs and test script output
