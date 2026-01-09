#!/bin/bash

# Script to submit a Spark job to Livy for execution on Kubernetes
# This demonstrates how to submit jobs to Livy which will create executor pods

set -e

# Configuration
LIVY_HOST="${1:-localhost}"
LIVY_PORT="${2:-8998}"
JOB_NAME="${3:-spark-pi-job}"

echo "========================================="
echo "Spark Job Submission to Livy (K8s Backend)"
echo "========================================="
echo "Livy Server: http://${LIVY_HOST}:${LIVY_PORT}"
echo "Job Name: ${JOB_NAME}"
echo "========================================="

# Function to submit a PySpark job via Livy
submit_pyspark_job() {
    local livy_url="http://${LIVY_HOST}:${LIVY_PORT}"
    
    echo "Creating a new PySpark session..."
    
    # Create session
    SESSION_RESPONSE=$(curl -s -X POST "${livy_url}/sessions" \
        -H "Content-Type: application/json" \
        -d '{
            "kind": "pyspark",
            "conf": {
                "spark.kubernetes.container.image": "spark-livy:latest",
                "spark.executor.instances": "2",
                "spark.executor.memory": "2g",
                "spark.executor.cores": "1"
            }
        }')
    
    echo "Session Response: $SESSION_RESPONSE"
    
    # Extract session ID
    SESSION_ID=$(echo "$SESSION_RESPONSE" | grep -o '"id":[0-9]*' | head -1 | cut -d: -f2)
    
    if [ -z "$SESSION_ID" ]; then
        echo "ERROR: Failed to create session"
        echo "Response: $SESSION_RESPONSE"
        return 1
    fi
    
    echo "Session created with ID: $SESSION_ID"
    
    # Wait for session to be ready (can take 15-30 seconds)
    echo "Waiting for session to be ready (this may take 15-30 seconds)..."
    max_wait=60
    waited=0
    
    while [ $waited -lt $max_wait ]; do
        STATUS=$(curl -s "${livy_url}/sessions/${SESSION_ID}" | grep -o '"state":"[^"]*"' | cut -d'"' -f4)
        echo "  Session Status: $STATUS (waited ${waited}s)"
        
        if [ "$STATUS" = "idle" ]; then
            echo "✓ Session ready!"
            break
        fi
        
        sleep 2
        ((waited+=2))
    done
    
    if [ "$STATUS" != "idle" ]; then
        echo "ERROR: Session failed to initialize. Final status: $STATUS"
        return 1
    fi
    
    echo "Session ready! Submitting job..."
    
    # Submit a simple Pi calculation job
    JOB_RESPONSE=$(curl -s -X POST "${livy_url}/sessions/${SESSION_ID}/statements" \
        -H "Content-Type: application/json" \
        -d '{
            "code": "import random\nNUM_SAMPLES = 100000\ncount = sum(1 for _ in range(NUM_SAMPLES) if random.random()**2 + random.random()**2 <= 1)\npi = (4.0 * count / NUM_SAMPLES)\nprint(f\"Pi is approximately {pi}\")"
        }')
    
    echo "Job Response: $JOB_RESPONSE"
    
    # Extract statement ID
    STATEMENT_ID=$(echo "$JOB_RESPONSE" | grep -o '"id":[0-9]*' | head -1 | cut -d: -f2)
    
    if [ -z "$STATEMENT_ID" ]; then
        echo "ERROR: Failed to submit job"
        return 1
    fi
    
    echo "Job submitted with Statement ID: $STATEMENT_ID"
    
    # Wait for job completion
    echo "Waiting for job to complete..."
    max_attempts=60
    attempt=0
    
    while [ $attempt -lt $max_attempts ]; do
        JOB_STATUS=$(curl -s "${livy_url}/sessions/${SESSION_ID}/statements/${STATEMENT_ID}" | grep -o '"state":"[^"]*"' | cut -d'"' -f4)
        
        if [ "$JOB_STATUS" = "available" ]; then
            echo "Job completed!"
            
            # Get the result
            RESULT=$(curl -s "${livy_url}/sessions/${SESSION_ID}/statements/${STATEMENT_ID}" | grep -o '"data":{"text/plain":"[^"]*"}' | sed 's/"data":{"text\/plain":"\(.*\)"}/\1/')
            echo "Result: $RESULT"
            break
        fi
        
        echo "Job Status: $JOB_STATUS (attempt $((attempt+1))/$max_attempts)"
        sleep 2
        ((attempt++))
    done
    
    # Clean up - delete session
    echo "Cleaning up session..."
    curl -s -X DELETE "${livy_url}/sessions/${SESSION_ID}" > /dev/null
    echo "Session deleted"
}

# Function to submit a Scala Spark job
submit_scala_job() {
    local livy_url="http://${LIVY_HOST}:${LIVY_PORT}"
    
    echo "Creating a new Scala Spark session..."
    
    # Create session
    SESSION_RESPONSE=$(curl -s -X POST "${livy_url}/sessions" \
        -H "Content-Type: application/json" \
        -d '{
            "kind": "spark",
            "conf": {
                "spark.kubernetes.container.image": "spark-livy:latest",
                "spark.executor.instances": "2",
                "spark.executor.memory": "2g",
                "spark.executor.cores": "1"
            }
        }')
    
    echo "Session Response: $SESSION_RESPONSE"
    
    # Extract session ID
    SESSION_ID=$(echo "$SESSION_RESPONSE" | grep -o '"id":[0-9]*' | head -1 | cut -d: -f2)
    
    if [ -z "$SESSION_ID" ]; then
        echo "ERROR: Failed to create session"
        return 1
    fi
    
    echo "Session created with ID: $SESSION_ID"
    echo "Note: Scala sessions may take longer to initialize"
}

# Check if Livy is reachable
echo "Checking Livy connectivity..."
if ! curl -s "${LIVY_HOST}:${LIVY_PORT}" > /dev/null 2>&1; then
    echo "ERROR: Cannot reach Livy at http://${LIVY_HOST}:${LIVY_PORT}"
    echo "Make sure Livy is running and accessible"
    exit 1
fi

echo "Livy is reachable!"
echo ""

# Submit job
if [ "$JOB_NAME" = "scala" ]; then
    submit_scala_job
else
    submit_pyspark_job
fi

echo "========================================="
echo "Job submission completed"
echo "========================================="
