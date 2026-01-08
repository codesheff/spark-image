#!/bin/bash

# Start Spark standalone cluster
# This script starts a Spark Master and Worker nodes

set -e

# Source environment
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "$SCRIPT_DIR/setup-env.sh"

MASTER_HOST="${MASTER_HOST:-localhost}"
MASTER_PORT="${MASTER_PORT:-7077}"
WORKER_CORES="${WORKER_CORES:-2}"
WORKER_MEMORY="${WORKER_MEMORY:-4g}"
WORKER_PORT="${WORKER_PORT:-8081}"

echo "Starting Spark standalone cluster..."
echo "Master: spark://$MASTER_HOST:$MASTER_PORT"

# Start Master
echo "Starting Spark Master..."
"$SPARK_HOME/bin/spark-class" org.apache.spark.deploy.master.Master \
    --host "$MASTER_HOST" \
    --port "$MASTER_PORT" \
    --webui-port 6066 \
    &

MASTER_PID=$!
echo "Master started with PID: $MASTER_PID"

# Wait for master to be ready
sleep 5

# Start Worker
echo "Starting Spark Worker..."
"$SPARK_HOME/bin/spark-class" org.apache.spark.deploy.worker.Worker \
    "spark://$MASTER_HOST:$MASTER_PORT" \
    --host "localhost" \
    --port "$WORKER_PORT" \
    --cores "$WORKER_CORES" \
    --memory "$WORKER_MEMORY" \
    &

WORKER_PID=$!
echo "Worker started with PID: $WORKER_PID"

# Keep processes running
wait $MASTER_PID $WORKER_PID
