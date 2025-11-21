#!/bin/bash
#=============================================================================================================================================================================
#title: create-docker-build-env.sh
#description
#     For use exclusively within the build-qc-bsp-reusable.yml workflow.
#     Creates a docker image based on the specified BUILD_DOCKER base image and runs a container from that image to provide a reproducible build environment.
#     Passes necessary build parameters and mounts the build project directory, release directory and relevant scripts into the container.
#     Entry point script (scripts/docker/docker_entry_point.sh) sets up user permissions and ownership inside the container to match the host runner user.
#assumes:
#     BUILD_DOCKER is set to the base docker image to use for the build environment (i.e., imdtec/imdt-qualcomm-build-setup:0.5.1).
#     CI_DIR is set to the root CI directory path on the runner.
#     BUILD_PROJECT_PATH is set to the build project directory path.
#     CONTAINER_NAME is set to 'ci_qualcomm_[unique_id]'.
#     DOCKER_EXEC is set to 'docker exec -t -u dev'.
#     DL_DIR and SSTATE_DIR are set to host paths for Yocto shared download and sstate cache directories.
#     MANIFEST_REPOSITORY, MANIFEST_BRANCH, MANIFEST_XML, IMAGE, RELEASE_NAME, BUILD_VERSION, KERNEL_VARIANT, QCS_SOURCES, PYENV, MACHINE, DISTRO, PATCH_SCRIPT_PATH are set to build parameters.
#=============================================================================================================================================================================

set -e

function create_container_image() {
    local path_to_dockerfiles="${GITHUB_WORKSPACE}/qualcomm_ci/scripts/docker/"
    #get host user and group IDs to pass to container
    HOST_UID=$(id -u)
    HOST_GID=$(id -g)
    export HOST_UID
    export HOST_GID

    #affix base BUILD_DOCKER version to new image name
    IMAGE_NAME="imdt-qualcomm-ci:${BUILD_DOCKER##*:}"
    echo "IMAGE_NAME=$IMAGE_NAME" >> "$GITHUB_ENV"

    #build container image from BASE_IMAGE and set entry point scripts/docker_entry_point.sh (final positional arg) 
    docker build -f "${path_to_dockerfiles}/qc_ci_docker" \
    --build-arg BASE_IMAGE="${BUILD_DOCKER}" \
    --tag "$IMAGE_NAME" \
    "$path_to_dockerfiles"
}

function run_container() {
    #pass ID's to entry-point script (scripts/for_docker/docker_entry_point.sh) to setup user permissions and ownership
    docker run --rm -d \
        --name "$CONTAINER_NAME" \
        -e MANIFEST_REPOSITORY="$MANIFEST_REPOSITORY" \
        -e MANIFEST_BRANCH="$MANIFEST_BRANCH" \
        -e MANIFEST_XML="$MANIFEST_XML" \
        -e IMAGE="$IMAGE" \
        -e RELEASE_NAME="$RELEASE_NAME" \
        -e BUILD_VERSION="$BUILD_VERSION" \
        -e KERNEL_VARIANT="$KERNEL_VARIANT" \
        -e QCOM_ROOT_DIR="/home/dev/Qualcomm/${QCS_SOURCES}" \
        -e PYENV="$PYENV" \
        -e MACHINE="$MACHINE" \
        -e DISTRO="$DISTRO" \
        -e PATCH_SCRIPT_PATH="$PATCH_SCRIPT_PATH" \
        -v "${BUILD_PROJECT_PATH}:/home/dev/Qualcomm" \
        -v "${BUILD_PROJECT_PATH}/release:/home/dev/Qualcomm/release" \
        -v "${CI_DIR}/scripts/docker_scripts/:/home/dev/tools/" \
        -v "${GITHUB_WORKSPACE}/qualcomm_ci/scripts/container_scripts/:/home/dev/tools/container_scripts/" \
        -v "${DL_DIR}:/home/dev/downloads" \
        -v "${SSTATE_DIR}:/home/dev/sstate-cache" \
        "$IMAGE_NAME" "$HOST_UID" "$HOST_GID" \
        sleep infinity

    #ENTRY POINT SCRIPT EXECUTION AND LOGGING
    #stream entry point script logs
    docker logs -f "${CONTAINER_NAME}" &
    LOG_PID=$!

    #once the entry script completes, it writes to /tmp/ready. Wait for that file to appear before continuing.
    until docker exec "${CONTAINER_NAME}" test -f /tmp/ready; do sleep 2; done

    #kill log stream
    kill $LOG_PID || true

    #verify that IDs are correct and ownership has been transferred correctly
    result=$($DOCKER_EXEC "${CONTAINER_NAME}" bash -c 'id')
    if [[ $result != *"uid=$HOST_UID"* && $result != *"gid=$HOST_GID"* ]]; then
        echo "ERROR: User IDs do not match"
        exit 1
    fi
}

create_container_image
run_container