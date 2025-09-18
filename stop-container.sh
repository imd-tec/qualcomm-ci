container_name=$1
DOCKER_VER=$2

#remove image
docker rmi -f "imdt-qualcomm-ci:${DOCKER_VER}" 2>/dev/null || true

# Check if container is running
echo "Checking status of container '${container_name}'..."
container_id=$(docker ps -q -f name="${container_name}")

if [[ -z "$container_id" ]]; then
    echo "Container '${container_name}' is not running."
    exit 0
fi

# Attempt to stop the container
echo "Stopping container '${container_name}'..."
# Attempt to stop the container gracefully with a SIGTERM signal
if docker stop -t 5 "${container_name}" &> /dev/null; then
    echo "Successfully sent SIGTERM to container '${container_name}'."
else
    echo "Failed to stop container '${container_name}' gracefully. Proceeding with docker kill."
fi

# Check if container is running
echo "Checking status of container '${container_name}'..."
container_id=$(docker ps -q -f name="${container_name}")

if [[ -n "$container_id" ]]; then
    echo "killing container '${container_name}'..."
    # Kill the container forcefully if it hasn't stopped
    if docker kill "${container_name}" &> /dev/null; then
        echo "Container '${container_name}' killed successfully."
    else
        echo "Failed to execute kill on container '${container_name}'."
    fi
else
    echo "container not running"
    exit 0
fi

echo "Checking status of container '${container_name}'..."
container_id=$(docker ps -q -f name="${container_name}")
if [[ -n "$container_id" ]]; then
    echo "Failed: container '${container_name}' still running?."
    exit 1
else
    echo "container not running"
    exit 0
fi