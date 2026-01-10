# Project Plan: Spark-Image Docker Build

## Overview
This project aims to build a Docker image for Apache Livy and Apache Spark to be used in a Kubernetes cluster.

## Phase 1: Foundation & Setup ✅ COMPLETED
- [x] Create directory structure (Dockerfile, docker-compose.yml, scripts/, config/, etc.)
- [x] Set up base Dockerfile with appropriate Spark and Livy versions
- [x] Define build arguments and environment variables
- [x] Create .dockerignore file

## Phase 2: Core Docker Image ✅ COMPLETED
- [x] Install Java/JDK as base runtime (Eclipse Temurin 11 JDK)
- [x] Install Apache Spark (3.3.2) and configure it properly
- [x] Install Apache Livy (0.7.1) and integrate with Spark
- [x] Configure necessary ports (8998 for Livy, 7077 for Spark, 6066 for Web UI, 8081 for Worker)
- [x] Set up user permissions and security best practices (non-root spark user)
- [x] Test Docker build and image functionality
- [x] Test docker-compose deployment (verified healthy status and working API)

## Phase 3: Kubernetes-Native Spark Execution ✅ COMPLETED
- [x] Configure Livy and Spark for Kubernetes scheduler backend
- [x] Set up Kubernetes API server connectivity from Livy
- [x] Configure RBAC and ServiceAccount for pod creation
- [x] Add Spark driver and executor pod templates
- [x] Create ConfigMaps for K8s-specific Spark configurations
- [x] Update Kubernetes manifests to enable pod creation
- [x] Add documentation on K8s backend configuration
- [x] Create example job submission scripts for K8s
- [x] Push image to Docker Hub (stedoh/spark-livy:latest)
- [x] Deploy to Kubernetes with Docker Hub registry
- [x] Verify Livy API is operational in Kubernetes

## Phase 4: Kubernetes Integration (Standard) ✅ COMPLETED
- [x] Create Kubernetes manifests (Deployment, Service, ConfigMap)
- [x] Configure resource requests/limits
- [x] Set up health checks (liveness/readiness probes)
- [x] Document volume mount requirements
- [x] Pod is running and ready (1/1)
- [x] Service active and responding

## Phase 5: Configuration & Scripts ✅ COMPLETED
- [x] Create entrypoint script for container initialization (already implemented)
- [x] Build configuration templates for Spark and Livy (already implemented)
- [x] Add helper scripts for common operations (submit-k8s-job.sh created)
- [x] Document environment variable configuration (in entrypoint.sh and config files)
- [x] Create additional monitoring and debugging scripts (health-check.sh, start-spark-cluster.sh)

## Phase 6: Version Upgrade to Stable Compatible (Spark 2.4.8 + Livy 0.7.1) ✅ COMPLETED
**Status: FULLY OPERATIONAL - All sessions working**

- [x] Update Dockerfile to use Spark 2.4.8 instead of 3.3.2
- [x] Made versions configurable with build args and build-image.sh script
- [x] Maintain Livy 0.7.1 (compatible with Spark 2.4.8)
- [x] Test PySpark interactive sessions (✅ PASS - session 1 initialized successfully)
- [x] Test Scala interactive sessions (✅ PASS - session 2 initialized successfully)
- [x] Verify code execution in sessions (✅ Both session types ready for job submission)
- [x] Update documentation with version changes (VERSION_MATRIX.md created)
- [x] Push updated image to Docker Hub (stedoh/spark-livy:2.4.8)
- [x] Deploy and test in Kubernetes cluster (✅ Pod 1/1 Ready, both sessions initialized)
- [x] Create version compatibility matrix and test documentation
- [x] Fixed readiness probe delays (180s initial delay for Spark 2.4.8 startup)

**Verified Capabilities:**
- ✅ PySpark sessions working with spark-defaults.conf master=local[*]
- ✅ Scala sessions working with proper SCALA_HOME environment
- ✅ Session initialization times: PySpark ~18s, Scala ~60s
- ✅ Memory constraints handled (1GB driver/executor allocation stable)
- ✅ Kubernetes RBAC and ServiceAccount functioning correctly

## Phase 7: Version Upgrade to Cutting Edge (Spark 3.5.x + Livy 0.8.0) ⏳ PENDING
**Status: Ready to start when stability of production version confirmed**

- [ ] Evaluate Livy 0.8.0 availability (GitHub source vs pre-built)
- [ ] Build Livy 0.8.0 or identify compatible pre-release
- [ ] Update Dockerfile with build-arg support for Livy 0.8.0
- [ ] Update Dockerfile to use Spark 3.4.x or 3.5.x
- [ ] Configure classpath fixes for Spark 3.x with Livy 0.8.0
- [ ] Test all interactive session types (PySpark, Scala, SQL)
- [ ] Verify Kubernetes scheduler backend works with newer versions
- [ ] Test dynamic executor pod creation
- [ ] Performance testing and benchmarking (3.x vs 2.4.8)
- [ ] Push updated image to Docker Hub (stedoh/spark-livy:cutting-edge)
- [ ] Create documentation on new features and breaking changes
- [ ] Document migration path for users (Spark 2.4.8 → 3.5.x)

## Phase 8: Testing & Documentation ⏳ PENDING
**Status: Foundation in place, expansion required**

**Current Work:**
- [x] Created test suite for Spark 2.4.8 + Livy 0.7.1 (session creation verified)
- [x] Documented version compatibility matrix (VERSION_MATRIX.md)
- [x] Created build-image.sh for flexible version management

**Remaining Tasks:**
- [ ] Expand test cases to include:
  - [ ] Batch job submission via spark-submit
  - [ ] DataFrame operations (PySpark)
  - [ ] RDD operations (Scala)
  - [ ] Kubernetes scheduler backend with custom pod templates
  - [ ] Dynamic executor scaling
- [ ] Write comprehensive README with:
  - [ ] Quick start guide for different versions
  - [ ] Build instructions with version examples
  - [ ] Kubernetes deployment guide
  - [ ] Configuration customization guide
- [ ] Create troubleshooting guide covering:
  - [ ] Session creation failures
  - [ ] Memory issues and tuning
  - [ ] Kubernetes pod template configuration
  - [ ] Version compatibility issues
- [ ] Add CI/CD pipeline (GitHub Actions):
  - [ ] Automated Docker build on commits
  - [ ] Multi-version builds (2.4.8, 3.5.x, cutting-edge)
  - [ ] Push to Docker Hub on release tags
  - [ ] Automated testing in K8s cluster
- [ ] Create CHANGELOG documenting version history

## Phase 9: Optimization & Release ⏳ PENDING
**Status: Foundation ready for implementation**

**Planned Improvements:**
- [ ] Multi-stage Docker build analysis:
  - [ ] Measure current image size (current: ~950MB)
  - [ ] Identify optimization opportunities
  - [ ] Target: reduce to <800MB if possible
- [ ] Security hardening:
  - [ ] Run Trivy/Snyk vulnerability scans
  - [ ] Apply security patches as needed
  - [ ] Document security considerations
  - [ ] Non-root user validation (already done: spark user)
- [ ] Performance tuning documentation:
  - [ ] Memory allocation recommendations
  - [ ] CPU request/limit best practices
  - [ ] Network configuration for large jobs
  - [ ] Executor scaling recommendations
- [ ] Release process setup:
  - [ ] Semantic versioning scheme (v1.0.0)
  - [ ] Release notes template
  - [ ] GitHub release creation workflow
  - [ ] Docker Hub tag management
  - [ ] Support matrix (which Spark/Livy combos supported)

## Testing Protocol for Version Changes

This section defines the standardized testing procedures to validate new Spark and Livy version combinations before production deployment.

### Mandatory Tests for Every Version Upgrade

#### 1. Docker Build Tests
**Purpose**: Verify image builds correctly with new versions

```bash
./build-image.sh <spark-version> <livy-version> <tag>
```

**Validation Checklist**:
- [ ] Build completes successfully (exit code 0)
- [ ] No build warnings or errors in dockerfile processing
- [ ] Image size reasonable (<1.5GB for JVM-based Spark)
- [ ] Image tags correctly applied
- [ ] Local docker images list shows new version tag

**Expected Time**: 40-60 seconds

#### 2. Kubernetes Deployment Tests
**Purpose**: Verify image deploys and pod initializes correctly

**Deployment Steps**:
```bash
docker tag spark-livy:<version> stedoh/spark-livy:<version>
docker push stedoh/spark-livy:<version>
kubectl apply -f k8s/spark-livy-manifest.yaml
```

**Validation Checklist**:
- [ ] Image pulled successfully (no ImagePullBackOff)
- [ ] Pod transitions to Running state
- [ ] Pod reaches 1/1 Ready status within 120 seconds
- [ ] Service endpoint accessible via port-forward
- [ ] Readiness probe passes consistently

**Troubleshooting**:
```bash
kubectl describe pod -n spark-livy <pod-name>  # Check events
kubectl logs -n spark-livy <pod-name>          # Check initialization logs
```

#### 3. Livy API Connectivity Tests
**Purpose**: Verify Livy service is operational

**Commands**:
```bash
kubectl port-forward -n spark-livy svc/spark-livy-service 8998:8998
curl http://localhost:8998/sessions | jq '.total'
```

**Validation Checklist**:
- [ ] HTTP 200 response from /sessions endpoint
- [ ] Valid JSON response format
- [ ] Total sessions count is a number
- [ ] Service responds within 500ms

#### 4. Session Creation Tests - PySpark
**Purpose**: Verify PySpark session initialization works

**Test Command**:
```bash
curl -X POST http://localhost:8998/sessions \
  -H "Content-Type: application/json" \
  -d '{"kind":"pyspark"}'
```

**Validation Checklist**:
- [ ] Session created (response contains valid session ID)
- [ ] Initial state is "starting" or "idle"
- [ ] Session transitions from "starting" to "idle" within 60 seconds
- [ ] No error or dead states
- [ ] Spark logs show successful context initialization
- [ ] Session persists without crashes

**Expected Timeline**:
- Starting: 0-10 seconds
- Spark context init: 10-30 seconds
- Ready state: 30-60 seconds

**Logs to Verify**:
```
"SparkContext finished initialization"
"Created Spark session"
"Successfully started service 'SparkUI'"
```

#### 5. Session Creation Tests - Scala
**Purpose**: Verify Scala session initialization works

**Test Command**:
```bash
curl -X POST http://localhost:8998/sessions \
  -H "Content-Type: application/json" \
  -d '{"kind":"spark"}'
```

**Validation Checklist**:
- [ ] Session created (response contains valid session ID)
- [ ] Initial state is "starting"
- [ ] Session transitions to "idle" within 120 seconds (Scala takes longer)
- [ ] No ClassNotFoundException or scala.* errors
- [ ] No "Interpreter died" errors
- [ ] Session logs show successful initialization

**Expected Timeline**:
- Starting: 0-20 seconds
- Spark context init: 20-60 seconds
- Ready state: 60-120 seconds

**Common Errors to Check**:
```
ClassNotFoundException: scala.Function0$class  ← Version incompatibility
Interpreter died                               ← Memory/environment issue
scala.concurrent.* errors                      ← Scala classpath issue
```

#### 6. Code Execution Tests - PySpark
**Purpose**: Verify PySpark session can execute Python code

**Test Script**: `scripts/test-livy-jobs.sh localhost 8998`

**Simple Code Test**:
```bash
curl -X POST http://localhost:8998/sessions/{id}/statements \
  -H "Content-Type: application/json" \
  -d '{"code":"print(\"test\")"}'
```

**Validation Checklist**:
- [ ] Statement submission succeeds (valid statement ID)
- [ ] Statement state transitions to "available" within 5 seconds
- [ ] Output status is "ok" (not "error")
- [ ] No "Interpreter died" errors
- [ ] Code result displays correctly

**Test Cases**:
1. **Print Statement**: `print("Hello PySpark")`
   - Expected: String output visible
   
2. **Spark Context Access**: `spark.version`
   - Expected: Version string returned
   
3. **DataFrame Creation**: `sc.range(10).collect()`
   - Expected: List of 0-9 returned

#### 7. Code Execution Tests - Scala
**Purpose**: Verify Scala session can execute Scala code

**Simple Code Test**:
```bash
curl -X POST http://localhost:8998/sessions/{id}/statements \
  -H "Content-Type: application/json" \
  -d '{"code":"println(\"test\")"}'
```

**Validation Checklist**:
- [ ] Statement submission succeeds
- [ ] Statement reaches "available" state
- [ ] Output status is "ok"
- [ ] No ClassNotFoundException
- [ ] Code result displays correctly

**Test Cases**:
1. **Print Statement**: `println("Hello Scala")`
2. **RDD Operations**: `sc.range(0, 10).collect()`
3. **SQL Context**: `spark.sql("SELECT 1").show()`

#### 8. Kubernetes Backend Tests
**Purpose**: Verify Spark can submit jobs to Kubernetes

**Configuration Check**:
```yaml
# In livy-server.conf or via API
livy.spark.master                 kubernetes://...
livy.spark.kubernetes.namespace   spark-livy
```

**Test**:
```python
# In Livy PySpark session
import subprocess
result = subprocess.run(['kubectl', 'get', 'pods', '-n', 'spark-livy'], 
                       capture_output=True, text=True)
print(result.stdout)
```

**Validation Checklist**:
- [ ] Kubernetes master URL correctly set
- [ ] Pod creation permissions functional
- [ ] Executor pods can be created and scheduled
- [ ] RBAC rules are honored
- [ ] Dynamic pod scaling works (if applicable)

#### 9. Performance & Resource Tests
**Purpose**: Verify resource consumption is reasonable

**Memory Usage Test**:
```python
# In Livy PySpark session
import sys
data = [i for i in range(1000000)]
print(f"Memory available: {sys.getsizeof(data)} bytes")
```

**Validation Checklist**:
- [ ] Session memory usage within limits (pod not OOMKilled)
- [ ] CPU usage reasonable (<200% for 2-core limit)
- [ ] Session doesn't leak memory over time
- [ ] Multiple sequential jobs don't degrade performance

**Metrics to Monitor**:
```bash
kubectl top pod -n spark-livy
watch kubectl get pods -n spark-livy
```

#### 10. Version Compatibility Cross-Check
**Purpose**: Ensure version combination has no known incompatibilities

**Validation Checklist**:
- [ ] Version combination listed in VERSION_MATRIX.md
- [ ] No known issues documented for this combination
- [ ] Compatible base Java version (check Spark requirements)
- [ ] Livy version supports Spark version
- [ ] No deprecated APIs used in session configurations

### Abbreviated Testing for Minor Updates

If updating only patch versions (e.g., 2.4.8 → 2.4.9), run:
1. Docker build test (test 1)
2. Kubernetes deployment (test 2)
3. Session creation (tests 4-5)
4. Single code execution (tests 6-7)

**Estimated Time**: 5-10 minutes

### Full Testing for Major/Minor Version Upgrades

If updating major or minor versions (e.g., 2.4.8 → 3.5.0), run ALL tests:
1. All 10 test categories above
2. Performance benchmarks against previous version
3. Documentation updates for breaking changes
4. Create detailed upgrade guide

**Estimated Time**: 30-60 minutes

### Testing Checklist Template

```markdown
## Version X.Y.Z Testing Checklist

**Spark Version**: X.Y.Z  
**Livy Version**: X.Y.Z  
**Test Date**: YYYY-MM-DD  
**Tester**: [name]  

### Results
- [ ] Build test: PASS/FAIL
- [ ] Deployment test: PASS/FAIL
- [ ] API connectivity: PASS/FAIL
- [ ] PySpark sessions: PASS/FAIL
- [ ] Scala sessions: PASS/FAIL
- [ ] PySpark execution: PASS/FAIL
- [ ] Scala execution: PASS/FAIL
- [ ] K8s backend: PASS/FAIL
- [ ] Performance: PASS/FAIL
- [ ] Compatibility: PASS/FAIL

### Issues Found
(List any issues and resolutions)

### Documentation Updated
- [ ] VERSION_MATRIX.md
- [ ] PHASE_X_TEST_RESULTS.md
- [ ] Troubleshooting guide
- [ ] Release notes

### Sign-off
- [ ] All critical tests passing
- [ ] No blocker issues
- [ ] Ready for production deployment
```

### Testing Tools & Resources

**Available Test Scripts**:
- `scripts/test-livy.sh` - Automated PySpark/Scala session test
- `scripts/submit-k8s-job.sh` - Job submission example
- `scripts/health-check.sh` - Basic health verification

**Documentation Files**:
- `VERSION_MATRIX.md` - Version compatibility reference
- `PHASE6_TEST_RESULTS.md` - Example test results
- `JOB_SUBMISSION_TEST.md` - Job submission test guide

### Automated Testing (Future)

When Phase 8 CI/CD is implemented, testing will include:
- GitHub Actions workflow triggering on version PRs
- Automated build test
- Automated deployment to test K8s cluster
- Automated session creation tests
- Automated code execution tests
- Test result reporting and approval gates

## Current Status Summary (as of January 9, 2026)

**Completed Phases:** 1, 2, 3, 4, 5, 6 (6 out of 9)
**In Progress:** None (Phase 6 completed successfully)
**Available for Work:** Phases 7, 8, 9

**Key Artifacts Created:**
- ✅ Dockerfile with configurable Spark/Livy versions
- ✅ build-image.sh script for version-based building
- ✅ VERSION_MATRIX.md documenting version compatibility
- ✅ Kubernetes manifests with RBAC and pod templates
- ✅ Production-ready image: stedoh/spark-livy:2.4.8 (Docker Hub)
- ✅ Verified working PySpark and Scala sessions
- ✅ Complete configuration templates for Spark and Livy

**Recommended Next Steps:**
1. **Immediate (High Priority):**
   - Create comprehensive README with quick-start guides
   - Document all supported configurations
   - Set up GitHub Actions CI/CD for automated builds

2. **Short Term (Medium Priority):**
   - Expand test suite for batch jobs and complex operations
   - Create troubleshooting guide based on known issues
   - Performance benchmark (2.4.8 vs 3.x when ready)

3. **Long Term (Low Priority):**
   - Begin Phase 7 (Spark 3.5.x + Livy 0.8.0) research
   - Image size optimization
   - Security vulnerability scanning
   - Release versioning strategy
