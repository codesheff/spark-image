#!/bin/bash

# Improved Spark Job Submission Test Script
# Tests PySpark and Scala session creation and job execution

set -e

LIVY_HOST="${1:-localhost}"
LIVY_PORT="${2:-8998}"

echo "╔════════════════════════════════════════════════════════════════╗"
echo "║     Spark-Livy Job Submission Test (Kubernetes Backend)         ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""
echo "Configuration:"
echo "  Livy Server: http://${LIVY_HOST}:${LIVY_PORT}"
echo ""

# Function to wait for URL
wait_for_url() {
    local url=$1
    local max_attempts=5
    local attempt=0
    
    while [ $attempt -lt $max_attempts ]; do
        if curl -s "$url" > /dev/null 2>&1; then
            return 0
        fi
        echo "  Waiting for connectivity... (attempt $((attempt+1))/$max_attempts)"
        sleep 1
        ((attempt++))
    done
    
    return 1
}

# Test connectivity
echo "Step 1: Testing Livy Connectivity"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
if ! wait_for_url "http://${LIVY_HOST}:${LIVY_PORT}/sessions"; then
    echo "❌ ERROR: Cannot reach Livy at http://${LIVY_HOST}:${LIVY_PORT}"
    echo ""
    echo "Troubleshooting:"
    echo "1. Verify Kubernetes pod is running:"
    echo "   kubectl get pods -n spark-livy"
    echo ""
    echo "2. Verify port forward is active:"
    echo "   kubectl port-forward -n spark-livy svc/spark-livy-service 8998:8998"
    echo ""
    exit 1
fi

echo "✅ Livy is reachable"
echo ""

# Get current session count
INITIAL_SESSIONS=$(curl -s http://${LIVY_HOST}:${LIVY_PORT}/sessions | jq '.total')
echo "Initial session count: $INITIAL_SESSIONS"
echo ""

# Test 1: Create PySpark Session
echo "Step 2: Creating PySpark Session"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

SESSION_JSON=$(curl -s -X POST "http://${LIVY_HOST}:${LIVY_PORT}/sessions" \
    -H "Content-Type: application/json" \
    -d '{"kind":"pyspark"}')

PYSPARK_ID=$(echo "$SESSION_JSON" | jq -r '.id')
if [ -z "$PYSPARK_ID" ] || [ "$PYSPARK_ID" = "null" ]; then
    echo "❌ Failed to create PySpark session"
    echo "Response: $SESSION_JSON"
    exit 1
fi

echo "✅ PySpark session created: ID=$PYSPARK_ID"
echo "   Waiting for initialization (may take 15-30 seconds)..."
echo ""

# Wait for PySpark session to be ready
MAX_WAIT=90
WAIT_TIME=0
PYSPARK_READY=0

while [ $WAIT_TIME -lt $MAX_WAIT ]; do
    STATE=$(curl -s "http://${LIVY_HOST}:${LIVY_PORT}/sessions/$PYSPARK_ID" | jq -r '.state')
    
    if [ "$STATE" = "idle" ]; then
        echo "✅ PySpark session ready (state: idle)"
        PYSPARK_READY=1
        break
    elif [ "$STATE" = "error" ] || [ "$STATE" = "dead" ]; then
        echo "❌ PySpark session failed with state: $STATE"
        break
    fi
    
    printf "   Status: %-20s (waited %3ds)\n" "$STATE" "$WAIT_TIME"
    sleep 3
    ((WAIT_TIME+=3))
done

echo ""

if [ $PYSPARK_READY -eq 0 ]; then
    echo "⚠️  PySpark session did not reach 'idle' state within timeout"
    echo "   Continuing with test anyway..."
fi

# Test 2: Create Scala Session
echo "Step 3: Creating Scala Session"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

SESSION_JSON=$(curl -s -X POST "http://${LIVY_HOST}:${LIVY_PORT}/sessions" \
    -H "Content-Type: application/json" \
    -d '{"kind":"spark"}')

SCALA_ID=$(echo "$SESSION_JSON" | jq -r '.id')
if [ -z "$SCALA_ID" ] || [ "$SCALA_ID" = "null" ]; then
    echo "❌ Failed to create Scala session"
    echo "Response: $SESSION_JSON"
    exit 1
fi

echo "✅ Scala session created: ID=$SCALA_ID"
echo "   Waiting for initialization (Scala takes longer, may take 30-60 seconds)..."
echo ""

# Wait for Scala session to be ready
MAX_WAIT=120
WAIT_TIME=0
SCALA_READY=0

while [ $WAIT_TIME -lt $MAX_WAIT ]; do
    STATE=$(curl -s "http://${LIVY_HOST}:${LIVY_PORT}/sessions/$SCALA_ID" | jq -r '.state')
    
    if [ "$STATE" = "idle" ]; then
        echo "✅ Scala session ready (state: idle)"
        SCALA_READY=1
        break
    elif [ "$STATE" = "error" ] || [ "$STATE" = "dead" ]; then
        echo "❌ Scala session failed with state: $STATE"
        break
    fi
    
    printf "   Status: %-20s (waited %3ds)\n" "$STATE" "$WAIT_TIME"
    sleep 3
    ((WAIT_TIME+=3))
done

echo ""

# Test 3: Submit Code to PySpark Session
if [ $PYSPARK_READY -eq 1 ]; then
    echo "Step 4: Testing PySpark Code Execution"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    CODE='print("Hello from PySpark on Spark 2.4.8!")'
    STMT_JSON=$(curl -s -X POST "http://${LIVY_HOST}:${LIVY_PORT}/sessions/$PYSPARK_ID/statements" \
        -H "Content-Type: application/json" \
        -d "{\"code\":\"$CODE\"}")
    
    STMT_ID=$(echo "$STMT_JSON" | jq -r '.id')
    if [ -z "$STMT_ID" ] || [ "$STMT_ID" = "null" ]; then
        echo "❌ Failed to submit code"
        echo "Response: $STMT_JSON"
    else
        echo "✅ Code statement submitted: ID=$STMT_ID"
        echo "   Statement: $CODE"
        echo ""
        echo "   Result: Code queued for execution"
    fi
    
    echo ""
fi

# Test 4: Submit Code to Scala Session
if [ $SCALA_READY -eq 1 ]; then
    echo "Step 5: Testing Scala Code Execution"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    CODE='println("Hello from Scala on Spark 2.4.8!")'
    STMT_JSON=$(curl -s -X POST "http://${LIVY_HOST}:${LIVY_PORT}/sessions/$SCALA_ID/statements" \
        -H "Content-Type: application/json" \
        -d "{\"code\":\"$CODE\"}")
    
    STMT_ID=$(echo "$STMT_JSON" | jq -r '.id')
    if [ -z "$STMT_ID" ] || [ "$STMT_ID" = "null" ]; then
        echo "❌ Failed to submit code"
        echo "Response: $STMT_JSON"
    else
        echo "✅ Code statement submitted: ID=$STMT_ID"
        echo "   Statement: $CODE"
        echo ""
        echo "   Result: Code queued for execution"
    fi
    
    echo ""
fi

# Summary
echo "Step 6: Summary"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

FINAL_SESSIONS=$(curl -s http://${LIVY_HOST}:${LIVY_PORT}/sessions | jq '.total')

echo "Session Summary:"
if [ $PYSPARK_READY -eq 1 ]; then
    echo "  ✅ PySpark Session $PYSPARK_ID: READY"
else
    echo "  ⚠️  PySpark Session $PYSPARK_ID: NOT READY (status: $STATE)"
fi

if [ $SCALA_READY -eq 1 ]; then
    echo "  ✅ Scala Session $SCALA_ID: READY"
else
    echo "  ⚠️  Scala Session $SCALA_ID: NOT READY (status: $STATE)"
fi

echo ""
echo "Statistics:"
echo "  Sessions created this test: $((FINAL_SESSIONS - INITIAL_SESSIONS))"
echo "  Total active sessions: $FINAL_SESSIONS"
echo ""

if [ $PYSPARK_READY -eq 1 ] && [ $SCALA_READY -eq 1 ]; then
    echo "✅ TEST PASSED - Both PySpark and Scala sessions working"
    exit 0
else
    echo "⚠️  PARTIAL SUCCESS - Some sessions did not initialize"
    exit 1
fi
