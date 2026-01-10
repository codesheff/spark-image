# Phase 7: Cutting Edge Version Upgrade Plan
## Spark 3.5.x + Livy 0.8.0

**Status**: IN PROGRESS  
**Date Started**: January 10, 2026  
**Target Versions**: Spark 3.5.1, Livy 0.8.0  
**Goal**: Build and test cutting-edge versions with full compatibility

---

## Executive Summary

Phase 7 upgrades from stable Spark 2.4.8 + Livy 0.7.1 to cutting-edge Spark 3.5.x + Livy 0.8.0. This provides:
- Latest Spark features and performance improvements
- Active maintenance and security patches
- Modern Python and Scala support
- Better Kubernetes integration

**Risks**:
- Livy 0.8.0 requires building from source (not pre-built binaries)
- Potential compatibility issues with existing configurations
- Breaking changes between major versions
- Extended testing required

---

## Phase 7 Tasks

### 1. Research & Planning (THIS TASK - Status: IN PROGRESS)

#### 1.1 Livy 0.8.0 Availability Research
- [ ] Check Apache Livy GitHub releases (https://github.com/apache/incubator-livy/releases)
- [ ] Determine if 0.8.0 is released or still in development
- [ ] Identify build requirements (Maven, Java version, dependencies)
- [ ] Document build steps and expected build time
- [ ] Create Dockerfile build stage for Livy

#### 1.2 Spark 3.5.x Compatibility
- [ ] Verify Spark 3.5.1 pre-built binaries availability
- [ ] Check Hadoop distribution compatibility
- [ ] Identify required Python version (3.8+)
- [ ] Document breaking changes from 2.4.8 → 3.5.1
- [ ] Review Kubernetes scheduler backend changes

#### 1.3 Configuration & Setup
- [ ] Identify configuration changes needed in spark-defaults.conf
- [ ] Update livy-server.conf for 0.8.0 specifics
- [ ] Document Kubernetes pod template changes
- [ ] Research classpath configuration for 3.5.x compatibility

### 2. Docker Image Updates (TASK 2)
- [ ] Create build stage for Livy 0.8.0 (Maven-based build)
- [ ] Update Dockerfile Spark download for 3.5.x
- [ ] Fix duplicate ARG declarations in Dockerfile
- [ ] Configure build arguments for cutting-edge versions
- [ ] Add conditional logic for Livy source build vs pre-built
- [ ] Test local Docker build with new versions

### 3. Configuration Updates (TASK 3)
- [ ] Update spark-defaults.conf for Spark 3.5.x
- [ ] Verify Java version compatibility (JDK 11+ required)
- [ ] Update Python environment setup if needed
- [ ] Modify Scala configuration for 3.5.x
- [ ] Update Kubernetes pod templates for 3.5.x

### 4. Testing - Phase 1: Build Validation (TASK 4)
- [ ] Build image successfully
- [ ] Verify image size is reasonable (<1.5GB)
- [ ] Check image contents (Spark, Livy, Java versions)
- [ ] Verify Docker registry push works

### 5. Testing - Phase 2: Kubernetes Deployment (TASK 5)
- [ ] Deploy to Kubernetes cluster
- [ ] Verify pod transitions to Running
- [ ] Verify pod reaches Ready (1/1) status
- [ ] Check service endpoint accessibility
- [ ] Verify readiness/liveness probes pass

### 6. Testing - Phase 3: API Connectivity (TASK 6)
- [ ] Test Livy API /sessions endpoint
- [ ] Verify JSON response format
- [ ] Check initial session count
- [ ] Test curl connectivity with new Livy version

### 7. Testing - Phase 4: Session Creation (TASK 7)
- [ ] Test PySpark session creation
- [ ] Test Scala session creation
- [ ] Monitor session initialization times
- [ ] Check for compatibility errors in logs
- [ ] Handle any Scala classpath issues

### 8. Testing - Phase 5: Code Execution (TASK 8)
- [ ] Execute Python code in PySpark session
- [ ] Execute Scala code in Scala session
- [ ] Test Spark context access
- [ ] Test DataFrame operations (PySpark)
- [ ] Test RDD operations (Scala)

### 9. Testing - Phase 6: Kubernetes Scheduler (TASK 9)
- [ ] Configure dynamic executor pod creation
- [ ] Test executor pod creation and deletion
- [ ] Verify driver-executor communication
- [ ] Test with custom pod templates
- [ ] Monitor pod resource usage

### 10. Performance Benchmarking (TASK 10)
- [ ] Session initialization time comparison (2.4.8 vs 3.5.1)
- [ ] Code execution performance comparison
- [ ] Memory usage comparison
- [ ] CPU usage comparison
- [ ] Create performance report

### 11. Documentation (TASK 11)
- [ ] Document new features in Spark 3.5.x
- [ ] Document Livy 0.8.0 breaking changes
- [ ] Update VERSION_MATRIX.md with 3.5.x entry
- [ ] Create migration guide (2.4.8 → 3.5.x)
- [ ] Document configuration differences
- [ ] Update README with cutting-edge version

### 12. Push to Docker Hub (TASK 12)
- [ ] Tag image as `stedoh/spark-livy:cutting-edge`
- [ ] Tag image as `stedoh/spark-livy:3.5.1` 
- [ ] Push to Docker Hub
- [ ] Verify images are accessible
- [ ] Update README with new image availability

### 13. Known Issues Handling (TASK 13)
- [ ] Document any compatibility issues discovered
- [ ] Create workarounds or fixes
- [ ] Add issues to VERSION_MATRIX.md Known Issues section
- [ ] Provide fallback recommendations

---

## Detailed Research Findings

### Livy 0.8.0 Status

**What we need to research**:
1. Is Livy 0.8.0 officially released?
   - Check: https://github.com/apache/incubator-livy/releases
   - Check: https://archive.apache.org/dist/incubator/livy/
   
2. If still in development:
   - Build from master branch
   - Build requirements: Maven 3.6+, Java 8+, Scala 2.12
   - Expected build time: ~30-60 seconds

3. Livy 0.8.0 Key Changes:
   - Better Spark 3.x support
   - Improved session management
   - Better error handling
   - Enhanced Scala/Python compatibility

### Spark 3.5.x Compatibility

**Breaking changes to prepare for**:
- Configuration property changes
- PySpark version requirements
- Python 3.8+ required
- Java 11+ recommended
- Hadoop 2.x may have issues; Hadoop 3.x recommended

**Migration considerations**:
- spark-defaults.conf syntax changes
- Executor/driver configuration changes
- Kubernetes pod template format changes
- Security and RBAC configuration changes

---

## Build Plan

### Option A: Pre-built Livy 0.8.0 (if available)
```dockerfile
# Similar to 0.7.1, just different version
RUN wget https://archive.apache.org/dist/incubator/livy/0.8.0/apache-livy-0.8.0-incubating-bin.zip
```

### Option B: Build Livy 0.8.0 from Source
```dockerfile
FROM maven:3.8-jdk-11 AS livy-builder
WORKDIR /tmp
RUN git clone https://github.com/apache/incubator-livy.git livy
WORKDIR /tmp/livy
RUN git checkout 0.8.0-branch  # or master
RUN mvn clean package -DskipTests
# Result: /tmp/livy/assembly/target/livy-0.8.0-SNAPSHOT-bin.zip
```

**Current assumption**: We'll try pre-built first, fall back to source build if needed.

---

## Testing Strategy

### Quick Validation (5-10 minutes)
1. Build image locally
2. Run docker-compose test
3. Verify basic Livy API connectivity

### Full Kubernetes Validation (30-45 minutes)
1. Deploy to K8s cluster
2. Run test-livy.sh with both exec and port-forward methods
3. Verify PySpark and Scala sessions
4. Execute sample code

### Performance Testing (20-30 minutes)
1. Compare session initialization times
2. Compare code execution times
3. Measure memory/CPU usage
4. Create comparison report

---

## Success Criteria

### Build Success
- ✅ Docker image builds without errors
- ✅ Image size < 1.5GB
- ✅ Java version correct (11+)
- ✅ Spark version in logs shows 3.5.1
- ✅ Livy version in logs shows 0.8.0

### Kubernetes Success
- ✅ Pod reaches 1/1 Ready status within 3 minutes
- ✅ Service endpoints active
- ✅ Readiness/liveness probes passing

### Functional Success
- ✅ PySpark sessions create successfully
- ✅ Scala sessions create successfully
- ✅ Code execution works for both types
- ✅ No compatibility errors in logs
- ✅ Performance not significantly worse than 2.4.8

### Documentation Success
- ✅ VERSION_MATRIX.md updated
- ✅ Migration guide created
- ✅ README reflects cutting-edge version
- ✅ Known issues documented

---

## Known Risks & Mitigation

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|-----------|
| Livy 0.8.0 not released | HIGH | Requires source build | Build from GitHub master |
| Spark 3.5.1 config incompatible | MEDIUM | Session init failures | Test systematically, update config |
| ClassNotFoundException (Scala) | MEDIUM | Scala sessions broken | Debug classpath, add jars |
| Performance regression | MEDIUM | Slower execution | Benchmark, tune JVM settings |
| Kubernetes scheduler issues | LOW | Pod creation fails | Check RBAC, pod templates |

---

## Timeline Estimate

| Task | Estimated Time | Status |
|------|-----------------|--------|
| Research & Planning | 1 hour | IN PROGRESS |
| Docker Image Updates | 1 hour | TODO |
| Configuration Updates | 30 min | TODO |
| Build & Local Test | 30 min | TODO |
| Kubernetes Deployment | 30 min | TODO |
| Session Testing | 1 hour | TODO |
| Code Execution Testing | 1 hour | TODO |
| Performance Benchmarking | 1 hour | TODO |
| Documentation | 1 hour | TODO |
| Docker Hub Push | 15 min | TODO |
| **Total** | **~8 hours** | |

---

## Contingency Plans

### If Livy 0.8.0 source build fails
→ Try Livy master branch
→ If still fails, stick with 0.7.1 and focus on Spark 3.5.x compatibility

### If Spark 3.5.1 sessions crash
→ Try Spark 3.5.0 instead
→ Try Spark 3.4.2 (more stable)
→ Fallback: Stay with 2.4.8 production version

### If performance regresses significantly
→ Tune JVM heap size and GC settings
→ Test with different executor configurations
→ Compare memory usage patterns

---

## Next Steps

1. ✅ Create this planning document
2. → Research Livy 0.8.0 availability
3. → Update Dockerfile with new versions
4. → Build and test locally
5. → Deploy to Kubernetes
6. → Run comprehensive test suite
7. → Document findings and migration guide
8. → Push to Docker Hub

---

## References

- Apache Spark 3.5.x: https://spark.apache.org/docs/3.5.0/
- Apache Livy: https://incubator.apache.org/projects/livy.html
- Livy GitHub: https://github.com/apache/incubator-livy
- Spark Release Notes: https://spark.apache.org/releases/
- Kubernetes Spark Operator: https://github.com/kubeflow/spark-on-k8s-operator

---

## Progress Tracking

- [x] Create Phase 7 plan document
- [ ] Complete Livy 0.8.0 research
- [ ] Complete Spark 3.5.x research
- [ ] Update Dockerfile
- [ ] Build and test
- [ ] Document results
- [ ] Push to Docker Hub

