#!/bin/bash

#ensure that script exits on error and unset variables are errors
set -euo pipefail

usage() {
    echo "Usage: $0 --container-name <name> --bsp-dir <path> --docker-ver <version>"
    exit 1
}

#parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --container-name) container_name="$2"; shift ;;
        --bsp-dir) bsp_dir="$2"; shift ;;
        --docker-ver) docker_ver="$2"; shift ;;

        *) echo "Unknown option $1"; usage ;;
    esac
    shift
done

#if variables not set, show usage and exit
if [[ -z "${container_name}" || -z "${bsp_dir}" || -z "${docker_ver}" ]]; then
    usage
fi


# Display the provided arguments
# echo "Using SSH: $usessh"
# echo "Build SDK: $sdk"
# echo "Build SWU: $swu"
# echo "Build for V2N: $v2n"
# echo "Manifest Repo: $manifest_repo"
# echo "Manifest Branch: $manifest_branch"
# echo "Manifest XML: $manifest_xml"
echo "Container Name: $container_name"
echo "BSP Directory: $bsp_dir"
echo "Docker Version: $docker_ver"


# echo "# Running Qualcomm container: $container_name"
docker run -d --rm \
    --name "$container_name" \
        -v $(pwd)/for_docker:/workflows \
    imdtec/imdt-qualcomm-build-setup:${docker_ver} \
    sleep infinity

# docker run -it -d --rm -v ${BSP_DIR}/:/Qualcomm --name qualcomm-build-env imdtec/imdt-qualcomm-build-setup:${DOCKER_VERSION}

