# Troubleshooting Guide: Spark-Livy on Kubernetes

This guide covers common issues encountered when using spark-image and provides solutions.

## Table of Contents

1. [Container/Pod Issues](#containerpod-issues)
2. [Session Creation Issues](#session-creation-issues)
3. [Code Execution Issues](#code-execution-issues)
4. [Network & Connectivity Issues](#network--connectivity-issues)
5. [Performance & Resource Issues](#performance--resource-issues)
6. [Version Compatibility Issues](#version-compatibility-issues)

---

## Container/Pod Issues

### Pod Not Starting (Pending State)

**Symptom**: Pod remains in `Pending` state
```
kubectl get pods -n spark-livy
# NAME                          READY   STATUS    RESTARTS
# spark-livy-744d4b455c-8lsfn   0/1     Pending   0
```

**Diagnostic Steps:**

```bash
# Check pod events
kubectl describe pod -n spark-livy <pod-name>

# Look for messages like:
# - "no nodes available matching selector"
# - "insufficient memory"
# - "ImagePullBackOff"
```

**Common Causes & Solutions:**

1. **Insufficient cluster resources**
   - Check node availability: `kubectl get nodes`
   - Check node capacity: `kubectl top nodes`
   - Scale up cluster or reduce resource requests

2. **Image pull errors**
   ```bash
   # Check image pull status
   kubectl describe pod -n spark-livy <pod-name> | grep -A 5 "Events"
   
   # If ImagePullBackOff:
   # - Verify image exists: docker pull stedoh/spark-livy:2.4.8
   # - Check registry credentials: kubectl secrets -n spark-livy
   # - Verify image name/tag in manifest
   ```

3. **Node selector/affinity issues**
   - Check if node selector is too restrictive
   - Verify nodes have required labels: `kubectl get nodes --show-labels`

**Solution:**
```bash
# Check node resources
kubectl describe node <node-name>

# If insufficient, either:
# a) Reduce resource requests in manifest:
kubectl patch deployment spark-livy -n spark-livy -p '{"spec":{"template":{"spec":{"resources":{"requests":{"memory":"1Gi","cpu":"0.5"}}}}}}'

# b) Scale cluster (cloud-specific command)
```

---

### Pod Crashes (CrashLoopBackOff)

**Symptom**: Pod keeps restarting
```
kubectl get pods -n spark-livy
# NAME                          READY   STATUS             RESTARTS
# spark-livy-744d4b455c-8lsfn   0/1     CrashLoopBackOff   15
```

**Diagnostic Steps:**

```bash
# Check pod logs
kubectl logs -n spark-livy <pod-name>

# Check previous logs (before crash)
kubectl logs -n spark-livy <pod-name> --previous

# Get detailed pod info
kubectl describe pod -n spark-livy <pod-name>
```

**Common Causes & Solutions:**

1. **Java not found or version mismatch**
   ```bash
   # Check logs for: "java: command not found" or "JAVA_HOME not set"
   # Solution: Verify Dockerfile installs Java correctly
   
   # Test in container
   kubectl exec -n spark-livy <pod-name> -- java -version
   ```

2. **Port already in use**
   ```bash
   # Check logs for: "Address already in use" or "Bind exception"
   
   # Verify port in manifest is correct
   # Kill conflicting process inside pod
   kubectl exec -n spark-livy <pod-name> -- lsof -i :8998
   ```

3. **Configuration file errors**
   ```bash
   # Check logs for: "Exception", "Error reading config", "InvalidConfigError"
   
   # Verify ConfigMap content
   kubectl get configmap -n spark-livy spark-livy-config -o yaml
   
   # Check mounted files in pod
   kubectl exec -n spark-livy <pod-name> -- ls -la /etc/spark/
   ```

4. **Insufficient memory**
   ```bash
   # Check logs for: "OutOfMemoryError", "Cannot allocate memory"
   
   # Increase memory limit
   kubectl patch deployment spark-livy -n spark-livy -p '{"spec":{"template":{"spec":{"resources":{"limits":{"memory":"8Gi"}}}}}}'
   ```

**Solution Example:**
```bash
# Restart pod to see fresh logs
kubectl delete pod -n spark-livy <pod-name>
kubectl wait --for=condition=Ready pod -l app=spark-livy -n spark-livy --timeout=300s

# Check logs immediately
kubectl logs -n spark-livy -l app=spark-livy --tail=100
```

---

### Pod Runs but Not Ready (1/1 → 0/1)

**Symptom**: Pod shows Running but not Ready
```
kubectl get pods -n spark-livy
# NAME                          READY   STATUS    RESTARTS
# spark-livy-744d4b455c-8lsfn   0/1     Running   0
```

**Diagnostic Steps:**

```bash
# Check readiness probe status
kubectl get pod -n spark-livy <pod-name> -o jsonpath='{.status.conditions[?(@.type=="Ready")]}'

# Check probe events
kubectl describe pod -n spark-livy <pod-name> | grep -A 10 "Probes"
```

**Common Causes & Solutions:**

1. **Readiness probe timeout too short**
   - Default initial delay: 180 seconds (Spark startup takes 60+ seconds)
   - Check logs during startup: `kubectl logs -f -n spark-livy <pod-name>`
   - If probe keeps failing, increase `initialDelaySeconds` in manifest:

   ```yaml
   readinessProbe:
     httpGet:
       path: /sessions
       port: 8998
     initialDelaySeconds: 240  # Increase from 180
     periodSeconds: 10
   ```

2. **Livy service not responding**
   ```bash
   # Check if Livy is actually listening
   kubectl exec -n spark-livy <pod-name> -- curl -s http://localhost:8998/sessions
   
   # If error: verify Livy started
   kubectl logs -n spark-livy <pod-name> | grep -i "livy"
   ```

3. **Service not responding on port 8998**
   ```bash
   # Check port binding inside pod
   kubectl exec -n spark-livy <pod-name> -- netstat -tlnp | grep 8998
   
   # If not listed: Livy failed to start
   # Check logs for Livy errors
   ```

---

## Session Creation Issues

### Session Fails to Create

**Symptom**: POST to /sessions returns error or invalid response
```bash
curl -X POST http://localhost:8998/sessions \
  -H "Content-Type: application/json" \
  -d '{"kind":"pyspark"}'

# Response: error, empty, or invalid JSON
```

**Diagnostic Steps:**

```bash
# Create session and check response
RESPONSE=$(curl -X POST http://localhost:8998/sessions \
  -H "Content-Type: application/json" \
  -d '{"kind":"pyspark"}')

echo $RESPONSE | jq .

# Check what error is returned
echo $RESPONSE | jq '.error'
echo $RESPONSE | jq '.log'
```

**Common Causes & Solutions:**

1. **Invalid request format**
   ```bash
   # Wrong Content-Type header
   # Error: "Unsupported Media Type" (415)
   
   # Verify header includes "application/json"
   curl -v -X POST http://localhost:8998/sessions \
     -H "Content-Type: application/json" \
     -d '{"kind":"pyspark"}'
   ```

2. **Insufficient memory**
   ```bash
   # Error: "Cannot run program java", "OutOfMemory"
   
   # Check pod memory
   kubectl top pod -n spark-livy <pod-name>
   
   # Increase memory request/limit
   kubectl set resources deployment spark-livy \
     -n spark-livy \
     --limits=memory=8Gi,cpu=2 \
     --requests=memory=4Gi,cpu=1
   ```

3. **Livy service issue**
   ```bash
   # Check service availability
   kubectl get svc -n spark-livy
   
   # If service missing or not ready:
   kubectl describe svc -n spark-livy spark-livy-service
   
   # Verify endpoints
   kubectl get endpoints -n spark-livy
   ```

---

### Session Stuck in "Starting" State

**Symptom**: Session remains in "starting" state indefinitely
```bash
curl http://localhost:8998/sessions/0 | jq '.state'
# "starting"

# After waiting 30-60+ seconds, still "starting"
```

**Diagnostic Steps:**

```bash
# Check session logs
curl http://localhost:8998/sessions/0 | jq '.log'

# Monitor over time
for i in {1..20}; do 
  STATE=$(curl -s http://localhost:8998/sessions/0 | jq -r '.state')
  echo "$(date): $STATE"
  sleep 3
done
```

**Common Causes & Solutions:**

1. **Python/Scala environment issue**
   - Logs contain: `ImportError`, `ModuleNotFoundError`, `ClassNotFoundException`
   
   ```bash
   # Check container environment
   kubectl exec -n spark-livy <pod-name> -- python --version
   kubectl exec -n spark-livy <pod-name> -- which scala
   
   # For Python issues, check distutils installation
   kubectl exec -n spark-livy <pod-name> -- python -c "import distutils"
   ```

2. **Spark context initialization hanging**
   - Logs show context being created but no completion message
   
   ```bash
   # Check if Spark is waiting for resources
   kubectl logs -n spark-livy <pod-name> | tail -50
   
   # Monitor pod resources while session starts
   kubectl top pod -n spark-livy <pod-name> --containers
   ```

3. **Network/DNS issues**
   - Logs contain connection timeouts
   
   ```bash
   # Test network from inside pod
   kubectl exec -n spark-livy <pod-name> -- ping -c 5 kubernetes.default
   kubectl exec -n spark-livy <pod-name> -- nslookup kubernetes.default
   ```

**Solution - Increase timeout:**

```bash
# Modify test script timeout from 30s to 90s
# In test-livy.sh:
MAX_WAIT=90  # Was 30

# Or wait manually
sleep 60
curl http://localhost:8998/sessions/0 | jq '.state'
```

---

### Session Enters "Error" State

**Symptom**: Session creation succeeds but immediately fails
```bash
curl http://localhost:8998/sessions/0 | jq '.state'
# "error"
```

**Diagnostic Steps:**

```bash
# Get error details from session logs
curl http://localhost:8998/sessions/0 | jq '.log[-10:]'

# Look for specific error types
curl http://localhost:8998/sessions/0 | jq '.log | .[] | select(. | contains("Error") or contains("Exception"))'
```

**Common Causes & Solutions:**

1. **Python cloudpickle/serialization error**
   ```
   TypeError: 'bytes' object cannot be interpreted as an integer
   ```
   - **Cause**: Python version incompatibility (usually Python 3.9+ with older Spark)
   - **Solution**: Use Spark 2.4.8 (known to work) instead of 3.3.2
   - **Reference**: See [VERSION_MATRIX.md](VERSION_MATRIX.md)

2. **Scala ClassNotFoundException**
   ```
   ClassNotFoundException: scala.Function0$class
   ```
   - **Cause**: Scala version mismatch or missing scala-library
   - **Solution**: 
     - Verify Scala installation: `kubectl exec -n spark-livy <pod> -- scala -version`
     - Rebuild image with compatible Spark version

3. **Out of memory during initialization**
   ```
   OutOfMemoryError: Java heap space
   ```
   - **Solution**: Increase driver memory
     ```bash
     # Edit config/spark-defaults.conf
     spark.driver.memory 2g  # from 1g
     
     # Rebuild image and redeploy
     ```

---

## Code Execution Issues

### Code Statement Returns "Error" Status

**Symptom**: Code executes but returns error status
```bash
curl -X POST http://localhost:8998/sessions/0/statements \
  -H "Content-Type: application/json" \
  -d '{"code":"print(test)"}'
# Returns: {"state":"error","output":{"status":"error",...}}
```

**Diagnostic Steps:**

```bash
# Check statement result
curl http://localhost:8998/sessions/0/statements/0 | jq '.'

# Look at output section for error message
curl http://localhost:8998/sessions/0/statements/0 | jq '.output.evalue'
```

**Common Causes & Solutions:**

1. **Undefined variable/function**
   ```python
   # Error: name 'test' is not defined
   
   # Solution: Ensure variable exists before use
   curl -X POST http://localhost:8998/sessions/0/statements \
     -H "Content-Type: application/json" \
     -d '{"code":"test = 5; print(test)"}'
   ```

2. **Syntax error in code**
   ```python
   # Error: invalid syntax
   
   # Verify code is valid Python before submission
   python -c "code = 'print('; compile(code, '<string>', 'exec')"
   ```

3. **Import error**
   ```python
   # Error: No module named 'numpy'
   
   # Check available modules
   curl -X POST http://localhost:8998/sessions/0/statements \
     -H "Content-Type: application/json" \
     -d '{"code":"import sys; print(sys.path)"}'
   
   # To install packages: modify Docker image or use pip in container
   ```

---

### Interpreter Dies During Execution

**Symptom**: Session crashes when executing code
```bash
# Session was "idle", but becomes "error"
curl http://localhost:8998/sessions/0 | jq '.log' 
# Contains: "Interpreter died"
```

**Diagnostic Steps:**

```bash
# Check pod logs for interpreter crash
kubectl logs -n spark-livy <pod-name> | grep -i "interpreter\|crash\|died"

# Monitor system resources during execution
watch kubectl top pod -n spark-livy <pod-name> --containers
```

**Common Causes & Solutions:**

1. **Out of memory**
   - Logs show OutOfMemoryError
   - Solution: Increase driver/executor memory

2. **Segmentation fault**
   - Logs show "Segmentation fault"
   - Usually JVM crash: increase Java heap size
   ```bash
   # Edit entrypoint.sh
   export JAVA_OPTS="-Xmx2g -XX:+UseG1GC"
   ```

3. **Native library crash**
   - Logs show cryptic error from native code
   - Try reducing parallelism: `spark.default.parallelism 4`

---

## Network & Connectivity Issues

### Cannot Reach Livy API

**Symptom**: curl to Livy API fails
```bash
curl http://localhost:8998/sessions
# Connection refused or timeout
```

**Diagnostic Steps:**

```bash
# Check if port-forward is active
ps aux | grep "port-forward.*8998"

# Restart port-forward
pkill -f "kubectl port-forward"
kubectl port-forward -n spark-livy svc/spark-livy-service 8998:8998

# Verify port is open
lsof -i :8998
```

**Common Causes & Solutions:**

1. **Port-forward not running**
   ```bash
   # Start port-forward in background
   kubectl port-forward -n spark-livy svc/spark-livy-service 8998:8998 &
   
   # Verify it's listening
   sleep 2
   curl http://localhost:8998/sessions
   ```

2. **Port-forward crashed**
   ```bash
   # Port-forward dies when pod restarts
   # Solution: Use kubectl exec method instead
   ./scripts/test-livy.sh localhost 8998 true
   ```

3. **Service not ready**
   ```bash
   # Check service endpoints
   kubectl get endpoints -n spark-livy spark-livy-service
   
   # If no endpoints, pod is not ready
   kubectl get pods -n spark-livy -w  # Watch pod status
   ```

4. **Firewall/network policy blocking**
   ```bash
   # Check network policies
   kubectl get networkpolicies -n spark-livy
   
   # Try accessing from inside pod
   kubectl exec -n spark-livy <pod> -- curl -s http://localhost:8998/sessions | jq '.total'
   ```

---

### Port-Forward Connection Drops

**Symptom**: Port-forward works initially but becomes unreliable
```bash
# Works first time:
curl http://localhost:8998/sessions
# {"from":0,"total":1,...}

# Fails on second attempt:
curl http://localhost:8998/sessions
# Connection refused
```

**Root Cause**: `kubectl port-forward` is ephemeral; it dies when the underlying pod restarts or network glitches occur.

**Solutions:**

1. **Recommended: Use kubectl exec method**
   ```bash
   # Instead of port-forward + curl:
   kubectl exec -n spark-livy <pod> -- curl -s http://localhost:8998/sessions
   
   # Or use test script with exec flag
   ./scripts/test-livy.sh localhost 8998 true
   ```

2. **Restart port-forward automatically**
   ```bash
   # Create shell script that restarts on failure
   while true; do
     kubectl port-forward -n spark-livy svc/spark-livy-service 8998:8998
     echo "Port-forward died, restarting..."
     sleep 5
   done
   ```

3. **Use Ingress or NodePort** (for production)
   ```yaml
   # Modify service type in manifest
   kind: Service
   spec:
     type: NodePort  # or LoadBalancer
     ports:
     - port: 8998
       nodePort: 30998
   ```

---

## Performance & Resource Issues

### Slow Session Initialization

**Symptom**: Sessions take much longer than expected
- Expected: PySpark 9-18s, Scala 9-60s
- Actual: 90s+ or timeouts

**Diagnostic Steps:**

```bash
# Monitor pod resources during session creation
watch 'kubectl top pod -n spark-livy --containers | grep -v "NAME"'

# Check pod events
kubectl describe pod -n spark-livy <pod>

# Monitor node resources
watch 'kubectl top nodes'
```

**Common Causes & Solutions:**

1. **Insufficient CPU allocation**
   ```bash
   # Check actual vs requested
   kubectl get pods -n spark-livy -o jsonpath='{.items[0].spec.containers[0].resources}'
   
   # Increase CPU request
   kubectl patch deployment spark-livy -n spark-livy \
     -p '{"spec":{"template":{"spec":{"containers":[{"name":"spark-livy","resources":{"requests":{"cpu":"2"}}}]}}}}'
   ```

2. **Node under resource pressure**
   ```bash
   # Check node status
   kubectl describe node <node> | grep -A 5 "Allocatable"
   
   # Drain pod to different node
   kubectl taint node <node> key=value:NoSchedule
   ```

3. **Disk I/O bottleneck**
   ```bash
   # Check I/O wait time inside pod
   kubectl exec -n spark-livy <pod> -- iostat -x 1 5
   
   # Check available disk space
   kubectl exec -n spark-livy <pod> -- df -h
   ```

---

### High Memory Usage

**Symptom**: Pod memory usage exceeds limits
```bash
kubectl top pod -n spark-livy
# MEMORY: 3Gi (limit: 4Gi) - keep increasing until OOMKilled
```

**Solutions:**

1. **Reduce allocated memory per session**
   ```bash
   # Edit config/spark-defaults.conf
   spark.driver.memory 512m     # from 1g
   spark.executor.memory 512m   # from 1g
   ```

2. **Limit concurrent sessions**
   ```bash
   # Edit livy-server.conf in ConfigMap
   livy.server.session.max-sessions 5  # from 10
   ```

3. **Increase pod limit**
   ```bash
   kubectl patch deployment spark-livy -n spark-livy \
     -p '{"spec":{"template":{"spec":{"resources":{"limits":{"memory":"8Gi"}}}}}}'
   ```

---

## Version Compatibility Issues

### "Interpreter Died" with Spark 3.3.2 + Livy 0.7.1

**Symptom**: Session initialization fails with cryptic error
```
TypeError: 'bytes' object cannot be interpreted as an integer
```

**Root Cause**: Spark 3.3.2 is incompatible with Livy 0.7.1 due to Python cloudpickle version conflicts

**Solution**: Use Spark 2.4.8 instead

```bash
# Rebuild with correct version
./build-image.sh 2.4.8 0.7.1 spark-livy

# Redeploy image
kubectl set image deployment/spark-livy spark-livy=stedoh/spark-livy:2.4.8 -n spark-livy

# Verify
./scripts/test-livy.sh localhost 8998 true
```

See [VERSION_MATRIX.md](VERSION_MATRIX.md) for tested version combinations.

---

## Still Having Issues?

1. **Collect diagnostics**
   ```bash
   # Get complete pod info
   kubectl describe pod -n spark-livy <pod> > debug.txt
   
   # Get all logs
   kubectl logs -n spark-livy <pod> --all-containers=true >> debug.txt
   
   # Get recent events
   kubectl get events -n spark-livy >> debug.txt
   ```

2. **Check documentation**
   - [README.md](README.md) - Quick reference
   - [VERSION_MATRIX.md](VERSION_MATRIX.md) - Version compatibility
   - [project-plan.md](project-plan.md) - Project status

3. **Enable debug logging**
   ```bash
   # Edit log4j.properties
   log4j.rootCategory=DEBUG, console
   
   # Rebuild and redeploy image
   ```

