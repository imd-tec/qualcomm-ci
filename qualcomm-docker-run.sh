#!/bin/bash

#soem arguments are from Lewis' ver that will probably not be needed...
usage() {
    echo "Usage: $0 --container-name <name> [--usessh] [--sdk] [--swu] --source-repo <repo_name> --docker-version <setup_version_num> --manifest-repo <repo_url> --manifest-branch <branch_name> --manifest-xml <filename>"
    exit 1
}

while [[ "$#" -gt 0 ]]; do
    case $1 in
        --usessh) usessh=1 ;;
        --sdk) sdk=1 ;;
        --swu) swu=1 ;;
        --v2n) v2n=1 ;;
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
echo "Using SSH: $usessh"
echo "Build SDK: $sdk"
echo "Build SWU: $swu"
echo "Build for V2N: $v2n"
echo "Container Name: $container_name"
echo "Build version: $docker_version"
echo "Source repo: $source_repo"
echo "Manifest Repo: $manifest_repo"
echo "Manifest Branch: $manifest_branch"
echo "Manifest XML: $manifest_xml"

# # Set SSH_DIR if usessh is enabled
# if [[ "$usessh" -eq 1 ]]; then
#     echo "# Horrid .ssh permissions hack"
#     echo "# setting SSH_DIR to ~/ssh_1000 if it exists, else ~/.ssh"
#     if [ -d ~/ssh_1000 ]; then
#         SSH_DIR=~/ssh_1000
#     else
#         SSH_DIR=~/.ssh
#     fi
# fi

set -euo pipefail -x



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
#Mount sources and netrc script from host machine. Mount build script from repo 
#include user intialization in docker build process
#ensure that image is based on my recent build ver
docker build -f "$CI_DIR/docker/qc_ci_docker" \
        -t imdt-qualcomm-ci:"$docker_version" \
        "$CI_DIR/docker"

docker run -d --rm \
    --name "$container_name" \
    -e SRC_REPO="$source_repo" -e MANI_REPO="$manifest_repo"\
    -e MANI_BRANCH="$manifest_branch" -e MANI_XML="$manifest_xml" \
    -v "$PWD/for_docker:/workflows"\
     -v "$CI_DIR/builds/:/home/dev/Qualcomm" \
     -v "$CI_DIR/scripts/:/home/dev/tools/" \
    imdt-qualcomm-ci:$docker_version $HOST_UID $HOST_GID\
    sleep infinity

# echo "[workflow] waiting for container to be ready…"
# timeout 120 bash -c 'until docker logs "$container_name" 2>&1 | grep -q "READY (uid="; do sleep 2; done'

echo "[workflow] entrypoint logs:"
docker logs "$container_name"


# execute build
docker exec -u dev "$container_name" bash -l -c "bash /workflows/bitbake-build.sh"

# # Copy the /output directory from the container to the local working_directory
# echo "# Copying the output directory from the container."
# mkdir working_directory
# docker cp "${container_name}:/home/imdt/output" "$(pwd)/working_directory"


