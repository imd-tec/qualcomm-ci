#!/bin/bash

# Usage: stop-container.sh <container-name> <docker-version>
# Example: stop-container.sh qualcomm-ci v1.0

if [ "$#" -ne 2 ]; then
    echo "Usage: $0 <container-name> <docker-version>"
    echo "Example: $0 qualcomm-ci v1.0"
    exit 1
fi

CONTAINER_NAME=$1
DOCKER_VER=$2

#remove container if present
docker rm -f "$CONTAINER_NAME" 2>/dev/null || true

#remove image
docker rmi -f "imdt-qualcomm-ci:${DOCKER_VER}" 2>/dev/null || true

#verify container status
if docker ps -q -f "name=^/${CONTAINER_NAME}$" | grep -q .; then
    echo "ERROR: container '$CONTAINER_NAME' still running"
    exit 1
fi
