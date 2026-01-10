# Release Checklist: New Spark & Livy Versions

This document provides a comprehensive checklist for preparing and releasing new Docker images with updated Spark and Livy versions.

---

## Overview

Releasing a new image involves multiple stages:
1. **Planning & Preparation** - Verify version availability and compatibility
2. **Development & Testing** - Build image and validate in staging
3. **Documentation** - Update all version-related documentation
4. **Quality Assurance** - Final testing and validation
5. **Release & Deployment** - Push to registry and production
6. **Post-Release** - Monitoring and documentation updates

---

## Pre-Release Phase (1-2 weeks before)

### 1. Version Planning & Research

- [ ] **Identify new versions to release**
  - Research latest Spark releases at [archive.apache.org](https://archive.apache.org/dist/spark/)
  - Research latest Livy releases at [archive.apache.org](https://archive.apache.org/dist/incubator/livy/)
  - Check Apache project JIRA for known issues
  - Subscribe to release mailing lists

- [ ] **Verify availability of pre-built binaries**
  ```bash
  # Test Spark availability
  curl -I "https://archive.apache.org/dist/spark/spark-X.Y.Z/spark-X.Y.Z-bin-hadoop*.tgz" 2>&1 | head -1
  
  # Test Livy availability
  curl -I "https://archive.apache.org/dist/incubator/livy/X.Y.Z/apache-livy-X.Y.Z-incubating*-bin.zip" 2>&1 | head -1
  ```

- [ ] **Document version combinations to test**
  - Create table with: Spark version, Livy version, Hadoop version, Scala version
  - Example: Spark 3.5.7 + Livy 0.8.0 + Hadoop 3.3 + Scala 2.13
  - Identify which combinations are primary vs. experimental

- [ ] **Check for breaking changes**
  - Review Spark release notes: [Spark Releases](https://spark.apache.org/releases/)
  - Review Livy release notes/documentation
  - Search for known compatibility issues in JIRA
  - Check Stack Overflow for reported issues
  - Document any breaking changes that affect Livy integration

- [ ] **Assess performance impact**
  - Compare CPU/memory requirements between versions
  - Check if JVM settings need adjustment
  - Document expected session initialization time changes

---

## Development Phase (1-2 weeks)

### 2. Update Configuration & Build System

- [ ] **Update Dockerfile**
  - [ ] Modify `ARG SPARK_VERSION` default value
  - [ ] Modify `ARG LIVY_VERSION` default value
  - [ ] Update any version-specific RUN commands
  - [ ] Verify Hadoop distribution selection logic
  - [ ] Test conditional download logic for new versions
  
  ```bash
  # Example Dockerfile section
  ARG SPARK_VERSION=X.Y.Z
  ARG LIVY_VERSION=X.Y.Z
  ARG HADOOP_VERSION=X.Y
  
  # Conditional download based on version
  RUN if [ "${SPARK_VERSION}" = "X.Y.Z" ]; then
        # version-specific commands
      fi
  ```

- [ ] **Update configuration files** (if needed)
  - [ ] `config/spark-defaults.conf` - Add/update version-specific settings
  - [ ] `config/livy-server.conf` - Add/update Livy-specific settings
  - [ ] `config/log4j.properties` - Update if major version changed
  - [ ] Document any configuration changes in comments

- [ ] **Update build scripts**
  - [ ] Update `build-image.sh` if it contains version-specific logic
  - [ ] Update default versions in any helper scripts
  - [ ] Test build scripts with new versions

- [ ] **Update entrypoint.sh**
  - [ ] Verify version-specific startup commands work
  - [ ] Test both older and newer versions start correctly
  - [ ] Check for any Livy version-specific startup parameters

---

### 3. Local Docker Build & Testing

**Use `build-image.sh` for custom version combinations or Docker Hub releases. Use `docker build` directly only for testing default versions locally.**

- [ ] **Build Docker image locally**
  ```bash
  # Using build-image.sh (recommended for releases)
  ./build-image.sh X.Y.Z A.B.C spark-livy:X.Y.Z
  
  # Or using docker build directly
  docker build \
    --build-arg SPARK_VERSION=X.Y.Z \
    --build-arg LIVY_VERSION=A.B.C \
    -t spark-livy:X.Y.Z \
    -t spark-livy:latest-test \
    .
  ```

- [ ] **Verify image contents**
  ```bash
  # Check Spark version
  docker run --rm spark-livy:X.Y.Z \
    /opt/spark/bin/spark-submit --version
  
  # Check Livy version
  docker run --rm spark-livy:X.Y.Z \
    ls /opt/livy/ | grep -i "apache-livy"
  
  # Check Java version
  docker run --rm spark-livy:X.Y.Z \
    java -version
  
  # Check Python version
  docker run --rm spark-livy:X.Y.Z \
    python3 --version
  ```

- [ ] **Image size verification**
  ```bash
  docker images | grep "spark-livy:X.Y.Z"
  # Verify size is reasonable (typically 1.4-1.7GB)
  # Document size for comparison
  ```

- [ ] **Test local container startup**
  ```bash
  docker run --rm -it \
    -p 8998:8998 \
    spark-livy:X.Y.Z
  
  # Wait 60 seconds for startup
  # Test API: curl http://localhost:8998/api/version
  ```

- [ ] **Quick functionality test**
  ```bash
  # Create PySpark session
  curl -X POST http://localhost:8998/sessions \
    -H "Content-Type: application/json" \
    -d '{"kind": "pyspark"}'
  
  # Test code execution
  curl -X POST http://localhost:8998/sessions/0/statements \
    -H "Content-Type: application/json" \
    -d '{"code": "print(\"Test\")"}'
  ```

---

## Staging Phase (3-5 days)

### 4. Kubernetes Staging Deployment

- [ ] **Create staging namespace**
  ```bash
  kubectl create namespace spark-livy-staging
  ```

- [ ] **Deploy to staging cluster**
  ```bash
  kubectl apply -f k8s/spark-livy-manifest.yaml -n spark-livy-staging
  
  # Update image tag
  kubectl set image deployment/spark-livy \
    spark-livy=spark-livy:X.Y.Z \
    -n spark-livy-staging
  ```

- [ ] **Verify pod startup**
  ```bash
  kubectl wait --for=condition=Ready pod -l app=spark-livy \
    -n spark-livy-staging --timeout=180s
  ```

- [ ] **Check pod logs for errors**
  ```bash
  kubectl logs -n spark-livy-staging deployment/spark-livy | head -50
  
  # Look for:
  # - Successful Java startup
  # - Livy server initialization
  # - No ERROR level logs
  ```

- [ ] **Run comprehensive test suite**
  ```bash
  # Port forward to staging
  kubectl port-forward -n spark-livy-staging svc/spark-livy 8998:8998 &
  
  # Run tests
  ./scripts/test-livy.sh localhost 8998 false
  
  # Kill port-forward
  pkill -f "port-forward"
  ```

- [ ] **Test PySpark workloads**
  - [ ] Simple print statement
  - [ ] DataFrame creation and operations
  - [ ] SQL queries
  - [ ] Import external libraries (pandas, numpy, etc.)
  - [ ] Long-running job (5+ minutes)

- [ ] **Test Scala workloads**
  - [ ] Simple println statement
  - [ ] Case classes and pattern matching
  - [ ] DataFrame operations
  - [ ] Scala collections operations
  - [ ] Long-running job (5+ minutes)

- [ ] **Monitor resource usage**
  ```bash
  # Monitor CPU and memory
  kubectl top pod -n spark-livy-staging -w
  
  # Watch for:
  # - CPU spikes during session creation
  # - Memory growth over time
  # - Any resource exhaustion issues
  ```

- [ ] **Performance benchmarking**
  - [ ] Measure PySpark session init time (run 3x, record average)
  - [ ] Measure Scala session init time (run 3x, record average)
  - [ ] Compare with previous version
  - [ ] Document any significant differences

- [ ] **Longevity testing**
  - [ ] Keep sessions running for 30+ minutes
  - [ ] Verify no memory leaks
  - [ ] Check for any timeout issues
  - [ ] Verify pod stability

- [ ] **API compatibility testing**
  - [ ] Test all endpoints used by applications
  - [ ] Verify session management (create, delete, check status)
  - [ ] Test statement execution
  - [ ] Test progress tracking

---

## Documentation Phase (2-3 days)

### 5. Update Documentation

- [ ] **Update VERSION_MATRIX.md**
  ```markdown
  # Add new version to appropriate section:
  # - Tested & Compatible (if stable)
  # - Experimental (if alpha/beta)
  
  | Spark Version | Livy Version | Status | Notes | Docker Image |
  |---|---|---|---|---|
  | X.Y.Z | X.Y.Z | ✅/⚠️ | Description | stedoh/spark-livy:X.Y.Z |
  ```

- [ ] **Update README.md**
  - [ ] Update "Tested Versions" section
  - [ ] Add new version to quick-start examples if appropriate
  - [ ] Update feature list if new features added
  - [ ] Update performance table

- [ ] **Update MIGRATION_GUIDE.md**
  - [ ] Add new section for migration path (if applicable)
  - [ ] Document breaking changes if any
  - [ ] Update compatibility matrix
  - [ ] Add troubleshooting section for new version issues

- [ ] **Create release notes document** (if major version)
  - [ ] Summarize new features in Spark/Livy
  - [ ] Document breaking changes
  - [ ] List known issues and workarounds
  - [ ] Provide upgrade path from previous version
  - [ ] Link to official Spark/Livy release notes

- [ ] **Update project-plan.md**
  - [ ] Update relevant phase status
  - [ ] Document version additions
  - [ ] Link to test results

- [ ] **Create test results document**
  ```markdown
  # PHASE_X_RELEASE_RESULTS_X.Y.Z.md
  
  Include:
  - Build verification
  - Test results (PySpark, Scala, API)
  - Performance metrics
  - Known issues (if any)
  - Deployment instructions
  ```

- [ ] **Update TROUBLESHOOTING.md**
  - [ ] Add version-specific troubleshooting if needed
  - [ ] Document known issues for new version
  - [ ] Add diagnostic commands specific to new version

---

### 6. Update Build & Deployment Configuration

- [ ] **Update Kustomize overlays**
  - [ ] Edit `scripts/generate-overlays.sh`
  - [ ] Add new version to `VERSIONS` array in the format: `["SPARK_VERSION"]="LIVY_VERSION"`
  - [ ] Example: `["3.5.7"]="0.8.0"` for Spark 3.5.7 + Livy 0.8.0
  - [ ] Run: `./scripts/generate-overlays.sh`
  - [ ] Verify files generated: `ls -la k8s/overlays/spark-X.Y.Z/`
  - [ ] Test overlay: `kubectl kustomize k8s/overlays/spark-X.Y.Z/ | grep "image:"`

- [ ] **Update CI/CD configuration** (if using GitHub Actions)
  - [ ] Add new version to build matrix
  - [ ] Update default version
  - [ ] Update image tags
  - [ ] Verify build pipeline still works

- [ ] **Update Kubernetes manifests** (if needed)
  - [ ] Base manifest remains version-agnostic (uses :latest)
  - [ ] Verify resource limits still appropriate
  - [ ] Update any version-specific environment variables

---

## QA Phase (1-2 days)

### 7. Quality Assurance & Final Validation

- [ ] **Run full test suite again**
  ```bash
  ./scripts/test-livy.sh localhost 8998 true
  # Verify all tests pass
  ```

- [ ] **Security scanning**
  - [ ] Scan image for vulnerabilities (if using trivy/grype)
  - [ ] Check for outdated base image
  - [ ] Verify no hardcoded secrets in image

- [ ] **Documentation review**
  - [ ] Review all updated documentation for accuracy
  - [ ] Verify all links work
  - [ ] Check for typos and grammar
  - [ ] Ensure consistency with other documentation

- [ ] **Cross-version compatibility check**
  - [ ] Verify old version still works (if keeping in support)
  - [ ] Test switching between versions works smoothly
  - [ ] Verify rollback procedure works

- [ ] **Verify image contents one final time**
  ```bash
  # List all key components
  docker run --rm spark-livy:X.Y.Z \
    bash -c "echo '=== Spark ===' && \
    ls /opt/spark/bin/spark-* | head -5 && \
    echo '=== Livy ===' && \
    ls /opt/livy/bin/ && \
    echo '=== Python ===' && \
    python3 -c 'import sys; print(sys.version)'"
  ```

---

## Release Phase (1 day)

### 8. Push to Docker Registry

- [ ] **Tag image with all relevant tags**
  ```bash
  # Primary version tag
  docker tag spark-livy:X.Y.Z stedoh/spark-livy:X.Y.Z
  
  # Major.minor tag (if applicable)
  docker tag spark-livy:X.Y.Z stedoh/spark-livy:X.Y
  
  # Latest stable tag (if stable release)
  docker tag spark-livy:X.Y.Z stedoh/spark-livy:latest
  
  # Experimental/cutting-edge tag (if applicable)
  docker tag spark-livy:X.Y.Z stedoh/spark-livy:cutting-edge
  ```

- [ ] **Verify tags**
  ```bash
  docker images | grep stedoh/spark-livy
  ```

- [ ] **Push to Docker Hub**
  ```bash
  docker push stedoh/spark-livy:X.Y.Z
  docker push stedoh/spark-livy:X.Y  # if applicable
  docker push stedoh/spark-livy:latest  # if stable
  docker push stedoh/spark-livy:cutting-edge  # if experimental
  
  # Verify push
  curl https://hub.docker.com/v2/repositories/stedoh/spark-livy/tags \
    -H "Authorization: Bearer $(cat ~/.docker/config.json | jq -r '.auths."https://index.docker.io/v1/".auth' | base64 -d | cut -d: -f2)"
  ```

- [ ] **Verify Docker Hub images**
  - [ ] Check Docker Hub web UI: https://hub.docker.com/r/stedoh/spark-livy
  - [ ] Verify tags appear correctly
  - [ ] Check pull count and last updated timestamp
  - [ ] Verify image description is accurate

---

### 9. Create Release Announcement

- [ ] **Draft release notes** (if major release)
  - [ ] Title: "Release: Spark X.Y.Z + Livy X.Y.Z"
  - [ ] Summary of what's new
  - [ ] List of breaking changes (if any)
  - [ ] Performance metrics vs. previous version
  - [ ] Known issues and workarounds
  - [ ] Migration guide link
  - [ ] Docker Hub link
  - [ ] GitHub tag (if using GitHub releases)

- [ ] **Update GitHub repository**
  - [ ] Create GitHub release with tag X.Y.Z
  - [ ] Attach PHASE_X_RELEASE_RESULTS document
  - [ ] Add release notes
  - [ ] Mark as pre-release if experimental

- [ ] **Update project documentation**
  - [ ] Commit all documentation updates
  - [ ] Update main README if needed
  - [ ] Create summary of changes in project-plan.md

---

## Post-Release Phase (Ongoing)

### 10. Deployment & Monitoring

- [ ] **Plan deployment to production**
  - [ ] Determine if immediate rollout or staged rollout
  - [ ] Schedule maintenance window if needed
  - [ ] Prepare rollback plan
  - [ ] Notify stakeholders

- [ ] **First production deployment** (if applicable)
  ```bash
  # Option 1: Using Kustomize (Recommended)
  # Verify overlays generated correctly
  ./scripts/generate-overlays.sh
  
  # Deploy with Kustomize
  kubectl apply -k k8s/overlays/spark-X.Y.Z/
  
  # Option 2: Manual deployment (Legacy)
  # Update deployment
  kubectl set image deployment/spark-livy \
    spark-livy=stedoh/spark-livy:X.Y.Z \
    -n spark-livy
  
  # Wait for rollout
  kubectl rollout status deployment/spark-livy -n spark-livy
  
  # Run tests
  ./scripts/test-livy.sh localhost 8998 true
  ```

- [ ] **Monitor production metrics**
  - [ ] CPU usage (should be similar to baseline)
  - [ ] Memory usage (should be similar to baseline)
  - [ ] Session initialization time
  - [ ] Job completion time
  - [ ] Error rates
  - [ ] Pod restart count

- [ ] **Watch for reported issues**
  - [ ] Monitor logs for errors
  - [ ] Check for user-reported issues
  - [ ] Be prepared to rollback if critical issues found

---

### 11. Post-Release Documentation

- [ ] **Document actual results**
  - [ ] Record real-world performance metrics
  - [ ] Document any unexpected behavior
  - [ ] Update troubleshooting if issues found

- [ ] **Archive release information**
  - [ ] Save test results
  - [ ] Archive release notes
  - [ ] Document decision rationale for version selection

- [ ] **Plan future work**
  - [ ] Schedule next version evaluation (quarterly/semi-annually)
  - [ ] Identify features to evaluate in next cycle
  - [ ] Plan for EOL versions (e.g., 2.4.8 is EOL)

---

## Rollback Procedure (If Issues Occur)

If critical issues are found after release:

- [ ] **Immediate rollback** (first 24 hours)
  ```bash
  kubectl set image deployment/spark-livy \
    spark-livy=stedoh/spark-livy:PREVIOUS_VERSION \
    -n spark-livy
  
  kubectl rollout restart deployment/spark-livy -n spark-livy
  
  kubectl wait --for=condition=Ready pod -l app=spark-livy \
    --timeout=180s
  
  # Verify rollback
  ./scripts/test-livy.sh localhost 8998 true
  ```

- [ ] **Document issue**
  - [ ] Create GitHub issue with full details
  - [ ] Include error messages and logs
  - [ ] Add to VERSION_MATRIX.md as known issue
  - [ ] Link to Apache JIRA if applicable

- [ ] **Post-mortem** (within 48 hours)
  - [ ] Determine root cause
  - [ ] Plan fix (patch version, wait for upstream fix, etc.)
  - [ ] Update release notes
  - [ ] Share findings with team

---

## Version Support Matrix

### Current Supported Versions

| Version | Spark | Livy | Status | Support Until |
|---------|-------|------|--------|---|
| Latest | 3.5.7 | 0.8.0 | ✅ Active | Next major release +6mo |
| Stable | 2.4.8 | 0.7.1 | ✅ Active | Q2 2026 |
| Legacy | 3.2.4 | 0.7.1 | ⚠️ Limited | Q1 2026 |

- **Active**: Full support, regular testing, security patches
- **Limited**: Bug fixes only, no new features tested
- **EOL**: No support, not recommended for new deployments

### End-of-Life Schedule

Document when each version will be dropped:
- Monitor Spark/Livy upstream support schedules
- Plan removal 6+ months after upstream EOL
- Announce removal in advance
- Provide migration path for users

---

## Checklist Verification

Before releasing, verify all items complete:

```bash
# Run this script to verify checklist items
for section in "Development" "Staging" "Documentation" "QA" "Release"; do
  echo "=== $section Phase ==="
  # grep items from this file
done
```

---

## Quick Reference

### Build Command Template
```bash
docker build \
  --build-arg SPARK_VERSION=X.Y.Z \
  --build-arg LIVY_VERSION=X.Y.Z \
  -t spark-livy:X.Y.Z \
  -t stedoh/spark-livy:X.Y.Z \
  .
```

### Test Command Template
```bash
./scripts/test-livy.sh localhost 8998 true
```

### Deploy Command Template
```bash
kubectl set image deployment/spark-livy \
  spark-livy=stedoh/spark-livy:X.Y.Z \
  -n spark-livy
```

### Rollback Command Template
```bash
kubectl set image deployment/spark-livy \
  spark-livy=stedoh/spark-livy:PREVIOUS_VERSION \
  -n spark-livy
```

---

## Contact & Support

For questions about the release process:
- Review previous release documents in `/home/stedo/spark-image/PHASE*` files
- Check VERSION_MATRIX.md for past version decisions
- Reference MIGRATION_GUIDE.md for deployment guidance
- Consult TROUBLESHOOTING.md for common issues

---

**Last Updated**: January 10, 2026  
**Review Frequency**: Quarterly  
**Next Review Date**: April 10, 2026
