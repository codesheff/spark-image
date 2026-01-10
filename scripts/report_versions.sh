#!/bin/bash

# Get current pod name
NAMESPACE="spark-livy"
POD_NAME=$(kubectl get pods -n $NAMESPACE -l app=spark-livy -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)

if [ -z "$POD_NAME" ]; then
    echo "❌ Error: No spark-livy pod found in namespace $NAMESPACE"
    exit 1
fi

# Run comprehensive version check
kubectl exec -n $NAMESPACE $POD_NAME -- bash -c '
echo "╔════════════════════════════════════════╗"
echo "║     Spark & Livy Version Report        ║"
echo "╚════════════════════════════════════════╝"
echo ""
echo "📦 Spark Version:"
SPARK_VERSION=$(/opt/spark/bin/spark-submit --version 2>&1 | grep -oE "version [0-9]+\.[0-9]+\.[0-9]+" | head -1 || echo "version unknown")
echo "Spark $SPARK_VERSION"
echo ""
echo "📦 Livy Version:"
LIVY_VERSION=$(ls /opt/livy/jars/livy-server-*.jar 2>/dev/null | head -1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+[^.]*' || echo "unknown")
echo "Apache Livy $LIVY_VERSION"
echo ""
echo "📦 Java Version:"
java -version 2>&1 | head -1
echo ""
echo "📦 Python Version:"
python3 --version
echo ""
echo "📦 Pod & Deployment:"
' && echo "Pod Name: $POD_NAME" && echo "Namespace: $NAMESPACE"