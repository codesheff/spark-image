#!/bin/bash

# Health check script for Livy Server
# This script is used to verify that the Livy server is healthy

set -e

LIVY_HOST="${LIVY_HOST:-localhost}"
LIVY_PORT="${LIVY_PORT:-8998}"
TIMEOUT="${TIMEOUT:-10}"

# Check if Livy API is responding
check_livy() {
    if curl -sf --connect-timeout "$TIMEOUT" \
        "http://${LIVY_HOST}:${LIVY_PORT}/sessions" > /dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

# Main health check
if check_livy; then
    echo "Livy server is healthy"
    exit 0
else
    echo "Livy server health check failed"
    exit 1
fi
