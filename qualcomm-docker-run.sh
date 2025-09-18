#!/bin/bash

#some arguments are from Lewis' ver that will probably not be needed...
usage() {
    echo "Usage: $0 --container-name <name> [--sdk] [--cdt] --source-repo <repo_name> --docker-version <setup_version_num> --manifest-repo <repo_url> --manifest-branch <branch_name> --manifest-xml <filename>"
    exit 1
}

while [[ "$#" -gt 0 ]]; do
    case $1 in
        --sdk) sdk=1 ;;
        --cdt) cdt=1 ;;
        --container-name) container_name="$2"; shift ;;
        --docker-version) docker_version="$2"; shift ;;
        --source-repo) source_repo="$2"; shift ;;
        --manifest-repo) manifest_repo="$2"; shift ;;
        --manifest-xml) manifest_xml="$2"; shift ;;
        --manifest-branch) manifest_branch="$2"; shift ;;
        *) echo "Unknown parameter passed: $1"; usage ;;
    esac
    shift
done

# Validate arguments
if [[ -z "$container_name" || -z "$source_repo" || -z "$docker_version" || -z "$manifest_repo" || -z "$manifest_xml" || -z "$manifest_branch" ]]; then
    echo "Error: Missing required arguments."
    usage
fi

# Display the provided arguments
echo "Build SDK: $sdk"
echo "Build CDT: $cdt"
echo "Container Name: $container_name"
echo "Build version: $docker_version"
echo "Source repo: $source_repo"
echo "Manifest Repo: $manifest_repo"
echo "Manifest Branch: $manifest_branch"
echo "Manifest XML: $manifest_xml"

set -euo pipefail

#set environment variables for ID and directory
export CI_DIR="/mnt/nvme1/qcom_ci"
export HOST_UID=$(id -u)
export HOST_GID=$(id -g)
echo "HOST IDs are $(id)"

#verify that (some) build files are present
if [[ -z "$(ls -A "$CI_DIR/builds/" 2>/dev/null)" ]]; then 
    echo "Error: no files found in /mnt/nvme1/qcom_ci/builds/"
    exit 1
fi

#CREATE THE CONTAINER
#include user intialization in docker build process
#ensure that image is based on my recent build ver
docker build -f "$CI_DIR/docker/qc_ci_docker" \
        -t imdt-qualcomm-ci:"$docker_version" \
        "$CI_DIR/actions-runner/_work/qualcomm-ci/qualcomm-ci/for_docker"


#detached does not wait for the entry script to finsih
#attached completes the script but exits immediately after initial run
docker run --rm -d \
    --name "$container_name" \
    -e SRC_REPO="$source_repo" -e MANI_REPO="$manifest_repo"\
    -e MANI_BRANCH="$manifest_branch" -e MANI_XML="$manifest_xml" \
    -v "$PWD/for_docker:/workflows"\
     -v "$CI_DIR/builds/:/home/dev/Qualcomm" \
     -v "$CI_DIR/scripts/:/home/dev/tools/" \
    imdt-qualcomm-ci:$docker_version $HOST_UID $HOST_GID\
    sleep infinity

#WAIT FOR ENTRY SCRIPT TO CONCLUDE
timeout=300
i=0

# while true; do
#   if docker logs "$container_name" 2>&1 | grep -m1 -q "READY"; then
#     echo "[workflow] READY seen."
#     break
#   fi
#   i=$((i+1))
#   if [ "$i" -ge "$timeout" ]; then
#     echo "[workflow] timed out waiting for READY after ${timeout}s" >&2
#     break
#   fi
#   sleep 1
# done

# docker logs -f --tail 0 "$container_name" 2>&1 \
#  | awk '!seen[$0]++ { print; if (index($0,"[entrypoint] READY")) exit 0 }'
# echo "[workflow] READY seen."

#VERIFY THAT ENTRY POINT FULLY EXECUTED SCRIPT
DEV_UID="$(docker exec -u root "$container_name" bash -lc 'id -u dev')"
if [ $DEV_UID != $HOST_UID ]; then
    echo "WARNING: ENTRY POINT FAILED TO SET CONTAINER USER IDs - EXECUTING DIRECTLY INSTEAD"
    docker exec -u root "$container_name" bash -l -c "bash /workflows/docker_entry_point.sh $HOST_UID $HOST_GID"
    else
    echo "IDs set. Continuing..."
fi

#EXECUTE BUILD
docker exec -t -u dev  "$container_name" bash -l -c "bash /workflows/bitbake-build.sh"

# # Copy the /output directory from the container to the local working_directory
# echo "# Copying the output directory from the container."
# mkdir working_directory
# docker cp "${container_name}:/home/imdt/output" "$(pwd)/working_directory"


