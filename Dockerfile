# Multi-stage Docker build for Spark and Livy
# This Dockerfile creates a production-ready image with Apache Spark and Livy
# Stage 1: Builder
FROM eclipse-temurin:11-jdk-jammy AS builder

WORKDIR /tmp

# Install build dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    wget \
    curl \
    ca-certificates \
    unzip \
    && rm -rf /var/lib/apt/lists/*

# Download Spark
ARG SPARK_VERSION=3.3.2
RUN wget https://archive.apache.org/dist/spark/spark-${SPARK_VERSION}/spark-${SPARK_VERSION}-bin-hadoop3.tgz && \
    tar -xzf spark-${SPARK_VERSION}-bin-hadoop3.tgz && \
    rm spark-${SPARK_VERSION}-bin-hadoop3.tgz

# Download Livy
ARG LIVY_VERSION=0.7.1
RUN wget https://archive.apache.org/dist/incubator/livy/${LIVY_VERSION}-incubating/apache-livy-${LIVY_VERSION}-incubating-bin.zip && \
    unzip apache-livy-${LIVY_VERSION}-incubating-bin.zip && \
    rm apache-livy-${LIVY_VERSION}-incubating-bin.zip

# Stage 2: Runtime
FROM eclipse-temurin:11-jdk-jammy

ARG SPARK_VERSION=3.3.2
ARG LIVY_VERSION=0.7.1

WORKDIR /opt

# Install runtime dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    bash \
    curl \
    ca-certificates \
    procps \
    && rm -rf /var/lib/apt/lists/*

# Copy Spark from builder
COPY --from=builder /tmp/spark-${SPARK_VERSION}-bin-hadoop3 /opt/spark

# Copy Livy from builder
COPY --from=builder /tmp/apache-livy-${LIVY_VERSION}-incubating-bin /opt/livy

# Create non-root user and directories
RUN useradd -m -s /bin/bash spark && \
    chown -R spark:spark /opt/spark /opt/livy && \
    mkdir -p /var/log/spark /var/log/livy && \
    chown -R spark:spark /var/log/spark /var/log/livy && \
    mkdir -p /tmp/spark-events && \
    chown -R spark:spark /tmp/spark-events

# Copy configuration files
COPY --chown=spark:spark config/spark-defaults.conf /opt/spark/conf/
COPY --chown=spark:spark config/log4j.properties /opt/spark/conf/
COPY --chown=spark:spark config/livy-server.conf /opt/livy/conf/
COPY --chown=spark:spark config/livy-client.conf /opt/livy/conf/

# Copy scripts
COPY --chown=spark:spark scripts/entrypoint.sh /opt/entrypoint.sh
COPY --chown=spark:spark scripts/setup-env.sh /opt/setup-env.sh
COPY --chown=spark:spark scripts/health-check.sh /opt/health-check.sh
COPY --chown=spark:spark scripts/start-spark-cluster.sh /opt/start-spark-cluster.sh

# Make scripts executable
RUN chmod +x /opt/entrypoint.sh /opt/setup-env.sh /opt/health-check.sh /opt/start-spark-cluster.sh

# Set environment variables
ENV SPARK_HOME=/opt/spark \
    LIVY_HOME=/opt/livy \
    PATH=$SPARK_HOME/bin:$LIVY_HOME/bin:$PATH \
    SPARK_USER=spark \
    SPARK_LOG_DIR=/var/log/spark \
    LIVY_LOG_DIR=/var/log/livy

# Labels for metadata
LABEL maintainer="Spark Image Project" \
      description="Apache Spark and Livy Docker image for Kubernetes" \
      spark.version="${SPARK_VERSION}" \
      livy.version="${LIVY_VERSION}"

# Expose ports
# 8998: Livy REST API
# 7077: Spark Master port
# 6066: Spark Web UI
# 8081: Spark Worker Web UI
EXPOSE 8998 7077 6066 8081

# Health check (using /sessions endpoint which is available in Livy 0.7.1)
HEALTHCHECK --interval=30s --timeout=10s --start-period=40s --retries=3 \
    CMD /bin/bash -c "curl -sf --connect-timeout 10 http://localhost:8998/sessions > /dev/null 2>&1 || exit 1"

# Switch to non-root user
USER spark

ENTRYPOINT ["/opt/entrypoint.sh"]
CMD ["livy-server"]
