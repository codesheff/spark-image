# Spark-Livy Docker Image

Production-ready Docker image for Apache Spark with Apache Livy on Kubernetes.

## Quick Start

### Prerequisites
- Docker Engine 20.10+
- Kubernetes 1.20+
- kubectl configured with cluster access
- Docker Hub account (for pushing images)

### Option 1: Using Pre-built Image (Recommended for Testing)

```bash
# Use pre-built image from Docker Hub
docker run -it stedoh/spark-livy:2.4.8
```

### Option 2: Build Locally

```bash
# Clone the repository
git clone <repository-url>
cd spark-image

# Build with default versions (Spark 2.4.8, Livy 0.7.1)
docker build -t spark-livy:2.4.8 .

# Or use the build script for flexible version management
./build-image.sh 2.4.8 0.7.1 spark-livy
```

### Option 3: Deploy to Kubernetes

```bash
# Apply the Kubernetes manifests
kubectl apply -f k8s/spark-livy-manifest.yaml

# Verify deployment
kubectl get pods -n spark-livy
kubectl get svc -n spark-livy

# Port-forward for local testing
kubectl port-forward -n spark-livy svc/spark-livy-service 8998:8998

# Test Livy API
curl http://localhost:8998/sessions | jq '.total'
```

## Features

✅ **Apache Spark 2.4.8** - Stable, production-tested version
✅ **Apache Livy 0.7.1** - Full compatibility with Spark 2.4.8
✅ **Kubernetes Native** - RBAC, ServiceAccount, dynamic pod creation
✅ **Multi-Session Support** - PySpark, Scala, SQL interpreters
✅ **Configurable** - Build-time and runtime configuration via environment variables
✅ **Security Hardened** - Non-root spark user, minimal attack surface

## Supported Versions

| Spark | Livy | Status | Notes |
|-------|------|--------|-------|
| 2.4.8 | 0.7.1 | ✅ Production | Recommended, fully tested |
| 3.3.2 | 0.7.1 | ❌ Incompatible | Interpreter crashes - use 2.4.8 |
| 3.5.x | 0.8.0 | 🔄 Planning | Phase 7 of roadmap |

See [VERSION_MATRIX.md](./VERSION_MATRIX.md) for detailed version compatibility information.

## Building Images with Different Versions

The `build-image.sh` script allows flexible version management:

```bash
# Build Spark 2.4.8 with Livy 0.7.1
./build-image.sh 2.4.8 0.7.1 spark-livy

# Build and push to Docker Hub
./build-image.sh 2.4.8 0.7.1 spark-livy --push

# With custom registry
./build-image.sh 2.4.8 0.7.1 myregistry/spark-livy:custom --push
```

## Configuration

### Environment Variables

#### Spark Configuration
- `SPARK_LOCAL_IP` - Local IP for Spark communication (default: pod IP)
- `SPARK_MASTER` - Spark master URL (default: local[*])
- `DRIVER_MEMORY` - Driver memory allocation (default: 1g)
- `EXECUTOR_MEMORY` - Executor memory allocation (default: 1g)

#### Livy Configuration
- `LIVY_PORT` - Livy server port (default: 8998)
- `LIVY_SESSIONS_MAX` - Maximum concurrent sessions (default: 10)
- `LIVY_ENABLE_CSRF` - Enable CSRF protection (default: true)

#### Kubernetes Configuration
- `SPARK_KUBERNETES_NAMESPACE` - K8s namespace for executors (default: spark-livy)
- `SPARK_KUBERNETES_AUTHENTICATE_DRIVER_SERVICEACCOUNTNAME` - ServiceAccount (default: spark)
- `SPARK_KUBERNETES_DRIVER_POD_NAME` - Driver pod name (auto-detected)

### Configuration Files

Edit before building image:

- `config/spark-defaults.conf` - Spark settings
- `config/livy-server.conf` - Livy server settings
- `config/livy-client.conf` - Livy client settings
- `config/log4j.properties` - Logging configuration

## Usage Examples

### 1. Create Interactive PySpark Session

```bash
# Port-forward to Livy
kubectl port-forward -n spark-livy svc/spark-livy-service 8998:8998 &

# Create session
curl -X POST http://localhost:8998/sessions \
  -H "Content-Type: application/json" \
  -d '{"kind":"pyspark"}'

# Result
# {"id":0,"kind":"pyspark","state":"starting",...}

# Get session status
curl http://localhost:8998/sessions/0 | jq '.state'

# Submit code (wait for session to be "idle")
curl -X POST http://localhost:8998/sessions/0/statements \
  -H "Content-Type: application/json" \
  -d '{"code":"print(spark.version)"}'
```

### 2. Create Interactive Scala Session

```bash
# Create session
curl -X POST http://localhost:8998/sessions \
  -H "Content-Type: application/json" \
  -d '{"kind":"spark"}'

# Submit Scala code
curl -X POST http://localhost:8998/sessions/1/statements \
  -H "Content-Type: application/json" \
  -d '{"code":"println(spark.version)"}'
```

### 3. Run Automated Tests

Using kubectl exec method (most reliable):

```bash
./scripts/test-livy.sh localhost 8998 true
```

Output:
```
✅ PySpark session ready (state: idle)
✅ Scala session ready (state: idle)
✅ Code statement submitted
✅ TEST PASSED - Both PySpark and Scala sessions working
```

### 4. Check System Health

```bash
./scripts/health-check.sh
```

## Kubernetes Deployment

### Prerequisites

```bash
# Create namespace
kubectl create namespace spark-livy

# Create ServiceAccount and RBAC
kubectl apply -f k8s/spark-livy-manifest.yaml
```

### Deploy Image

```bash
# Deploy with pre-built image
kubectl apply -f k8s/spark-livy-manifest.yaml

# Verify pod is running
kubectl get pods -n spark-livy
# NAME                          READY   STATUS    RESTARTS   AGE
# spark-livy-744d4b455c-8lsfn   1/1     Running   0          2m

# Verify service
kubectl get svc -n spark-livy
# NAME                    TYPE        CLUSTER-IP    EXTERNAL-IP   PORT(S)
# spark-livy-service      ClusterIP   10.96.0.100   <none>        8998/TCP
```

### Resource Allocation

Default resource requests/limits (adjust in manifest):

```yaml
resources:
  requests:
    memory: "2Gi"
    cpu: "1"
  limits:
    memory: "4Gi"
    cpu: "2"
```

### Health Checks

The deployment includes automatic health checks:

- **Readiness Probe**: /sessions endpoint returns 200 (180s initial delay)
- **Liveness Probe**: /sessions endpoint returns 200 (300s initial delay)

These delays accommodate Spark startup time (~60s) and session initialization.

## Troubleshooting

### Pod Not Starting (Pending)

```bash
# Check pod events
kubectl describe pod -n spark-livy <pod-name>

# Common causes:
# - Insufficient resources (check node capacity)
# - Image pull issues (verify registry credentials)
# - Network issues (check DNS)
```

### Pod Crashes (CrashLoopBackOff)

```bash
# Check logs
kubectl logs -n spark-livy <pod-name>

# Common causes:
# - Java/JDK issues (check Java version)
# - Port conflicts (8998 in use)
# - Configuration errors (check config files)
```

### Sessions Not Initializing

```bash
# Check session logs
curl http://localhost:8998/sessions/0 | jq '.log'

# Common causes:
# - Memory constraints (increase DRIVER_MEMORY)
# - Python/Scala environment issues (check logs)
# - Version incompatibility (see VERSION_MATRIX.md)
```

### Slow Session Startup

Session initialization times:
- **PySpark**: 9-18 seconds (normal)
- **Scala**: 9-60 seconds (variable, can be slow)

If consistently slower, check:
- Pod resource utilization: `kubectl top pod -n spark-livy`
- Node resource availability: `kubectl top nodes`
- Network latency: `kubectl exec -n spark-livy <pod> -- ping -c 5 8.8.8.8`

### Port-Forward Disconnections

If using port-forward and connections drop:

```bash
# Use the exec-based test method instead (more reliable)
./scripts/test-livy.sh localhost 8998 true

# Or restart port-forward
pkill -f "kubectl port-forward"
kubectl port-forward -n spark-livy svc/spark-livy-service 8998:8998
```

## Scripts

### test-livy.sh
Automated test for PySpark and Scala session creation and code execution.

```bash
# Using kubectl exec (recommended)
./scripts/test-livy.sh localhost 8998 true

# Using port-forward
./scripts/test-livy.sh localhost 8998 false
```

### submit-k8s-job.sh
Example job submission to demonstrate job execution. **Note**: Currently uses port-forward; see test-livy.sh for exec-based alternative.

```bash
./scripts/submit-k8s-job.sh
```

### health-check.sh
Quick health verification script.

```bash
./scripts/health-check.sh
```

## Documentation

- [VERSION_MATRIX.md](./VERSION_MATRIX.md) - Version compatibility reference
- [project-plan.md](./project-plan.md) - Full project roadmap and status
- [PHASE6_TEST_RESULTS.md](./PHASE6_TEST_RESULTS.md) - Test results for Spark 2.4.8 + Livy 0.7.1

## Performance Considerations

### Memory Settings

Current defaults are optimized for testing/small deployments:

- Driver memory: 1GB
- Executor memory: 1GB per core

For production workloads, adjust:

```bash
# Edit config/spark-defaults.conf
spark.driver.memory 4g
spark.executor.memory 2g
```

### Kubernetes Scheduler

Dynamic executor pod creation is supported. Configure in `k8s/spark-livy-manifest.yaml`:

```yaml
SPARK_KUBERNETES_AUTHENTICATE_DRIVER_SERVICEACCOUNTNAME: spark
```

## Development

### Project Structure

```
spark-image/
├── Dockerfile                      # Multi-stage Docker build
├── build-image.sh                  # Flexible version-based build script
├── docker-compose.yml              # Local testing with docker-compose
├── config/                         # Configuration files
│   ├── spark-defaults.conf
│   ├── livy-server.conf
│   ├── livy-client.conf
│   └── log4j.properties
├── scripts/                        # Helper scripts
│   ├── entrypoint.sh
│   ├── test-livy.sh
│   ├── submit-k8s-job.sh
│   ├── health-check.sh
│   └── start-spark-cluster.sh
├── k8s/                            # Kubernetes manifests
│   └── spark-livy-manifest.yaml
└── docs/                           # Documentation
    ├── VERSION_MATRIX.md
    ├── PHASE6_TEST_RESULTS.md
    └── project-plan.md
```

### Building Modifications

To modify the image:

1. Edit configuration files in `config/`
2. Update `Dockerfile` for version changes
3. Build and test locally: `docker build -t spark-livy:test .`
4. Deploy to K8s and test with `./scripts/test-livy.sh`

## CI/CD Integration (Phase 8 Future Work)

Planned GitHub Actions workflows:

```
.github/workflows/
├── build-and-test.yml              # Build and test on every commit
├── multi-version-build.yml         # Build multiple version combinations
└── release.yml                     # Build and push on release tags
```

## Support & Issues

For issues or questions:

1. Check the [Troubleshooting](#troubleshooting) section
2. Review [VERSION_MATRIX.md](./VERSION_MATRIX.md) for compatibility issues
3. Check Kubernetes pod logs: `kubectl logs -n spark-livy <pod>`
4. Check Livy session logs: `curl http://localhost:8998/sessions/0 | jq '.log'`

## License

[Add your license information here]

## Contributing

[Add contribution guidelines here]

## Roadmap

**Phase 7** (Planned): Upgrade to Spark 3.5.x + Livy 0.8.0
**Phase 8** (In Progress): Complete testing suite and CI/CD
**Phase 9** (Planned): Optimization and production hardening

See [project-plan.md](./project-plan.md) for detailed roadmap.

## Version History

### v2.4.8-1 (January 2026)
- ✅ Spark 2.4.8 + Livy 0.7.1 stable version
- ✅ Full Kubernetes integration with RBAC
- ✅ PySpark and Scala session support
- ✅ Comprehensive testing and documentation

### v3.3.2-1 (January 2026) [DEPRECATED]
- ❌ Incompatibility with Livy 0.7.1 (interpreter crashes)
- Replaced with v2.4.8-1