#!/bin/bash

# Environment setup script
# Initializes environment variables and performs pre-startup checks

set -e

# Source default environment variables
export SPARK_HOME=${SPARK_HOME:-/opt/spark}
export LIVY_HOME=${LIVY_HOME:-/opt/livy}
export SPARK_USER=${SPARK_USER:-spark}
export SPARK_LOG_DIR=${SPARK_LOG_DIR:-/var/log/spark}
export LIVY_LOG_DIR=${LIVY_LOG_DIR:-/var/log/livy}

# Create log directories
mkdir -p "$SPARK_LOG_DIR" "$LIVY_LOG_DIR"

# Ensure proper permissions
if [ "$SPARK_USER" != "root" ]; then
    chown -R "$SPARK_USER:$SPARK_USER" "$SPARK_LOG_DIR" "$LIVY_LOG_DIR" 2>/dev/null || true
fi

# Additional environment variables
export SPARK_OPTS="${SPARK_OPTS:-}"
export LIVY_CONF_DIR=${LIVY_CONF_DIR:-/opt/livy/conf}
export SPARK_CONF_DIR=${SPARK_CONF_DIR:-/opt/spark/conf}

# Export for child processes
export SPARK_HOME LIVY_HOME SPARK_USER SPARK_LOG_DIR LIVY_LOG_DIR
export SPARK_OPTS LIVY_CONF_DIR SPARK_CONF_DIR

echo "Environment initialized successfully"
echo "SPARK_HOME: $SPARK_HOME"
echo "LIVY_HOME: $LIVY_HOME"
echo "SPARK_USER: $SPARK_USER"
