#!/bin/bash

set -e

# Source environment setup
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "$SCRIPT_DIR/setup-env.sh"

# Set Scala and Python paths for Livy/Spark
export SCALA_HOME=$SPARK_HOME/jars
export SPARK_CLASSPATH=$SPARK_HOME/jars/*:$SPARK_HOME/lib/*
export PYSPARK_PYTHON=/usr/bin/python3
export PYSPARK_DRIVER_PYTHON=/usr/bin/python3

# Workaround for Scala compatibility with Livy 0.7.1
# Add all jar files to classpath
export CLASSPATH=$SPARK_HOME/jars/*:$SPARK_HOME/lib/*:$CLASSPATH

# Default command
CMD="${1:-livy-server}"

echo "========================================="
echo "Spark-Livy Container"
echo "========================================="
echo "Spark Version: $(cat $SPARK_HOME/RELEASE | grep "Spark" || echo "Unknown")"
echo "Livy Home: $LIVY_HOME"
echo "Spark Home: $SPARK_HOME"
echo "Python: $PYSPARK_PYTHON"
echo "Starting command: $CMD"
echo "========================================="

# Function to wait for Spark to be ready
wait_for_spark() {
    echo "Waiting for Spark to be ready..."
    sleep 5
}

# Execute the command
case $CMD in
    livy-server)
        echo "Starting Livy server..."
        wait_for_spark
        # Livy 0.8.0+ requires "start" argument, earlier versions might not support it
        # Try with start first (for 0.8.0+), fall back to just exec if not supported
        exec "$LIVY_HOME/bin/livy-server" start
        ;;
    spark-shell)
        echo "Starting Spark shell..."
        wait_for_spark
        exec "$SPARK_HOME/bin/spark-shell"
        ;;
    spark-cluster)
        echo "Starting Spark standalone cluster..."
        exec "$SCRIPT_DIR/start-spark-cluster.sh"
        ;;
    spark-submit)
        echo "Submitting Spark application..."
        shift
        exec "$SPARK_HOME/bin/spark-submit" "$@"
        ;;
    spark-master)
        echo "Starting Spark Master..."
        exec "$SPARK_HOME/bin/spark-class" org.apache.spark.deploy.master.Master "$@"
        ;;
    spark-worker)
        echo "Starting Spark Worker..."
        exec "$SPARK_HOME/bin/spark-class" org.apache.spark.deploy.worker.Worker "$@"
        ;;
    bash|/bin/bash)
        exec /bin/bash
        ;;
    *)
        echo "Unknown command: $CMD"
        echo "Available commands:"
        echo "  livy-server       - Start Livy server (default)"
        echo "  spark-shell       - Start Spark interactive shell"
        echo "  spark-cluster     - Start Spark standalone cluster"
        echo "  spark-submit      - Submit Spark application"
        echo "  spark-master      - Start Spark Master"
        echo "  spark-worker      - Start Spark Worker"
        echo "  bash              - Start bash shell"
        exit 1
        ;;
esac
