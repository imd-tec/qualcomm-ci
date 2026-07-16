#!/bin/bash
#=============================================================================================================================================================================
#title: create-docker-build-env.sh
#description
#     For use exclusively within the imdt-build-qcom-bsp.yml workflow.
#     Creates Docker image and build container for Qualcomm CI environment via docker compose.
#     Exports host UID/GID for container user initialisation.
#assumes:
#     The host must have their .netrc file configured for repo access.
#     BASE_DOCKER_IMAGE is set to the base docker image to use for the build environment (i.e., imdtec/imdt-qualcomm-build-setup:0.5.1).
#=============================================================================================================================================================================
set -e

#get host user and group IDs for container permission and ownership setup
HOST_UID=$(id -u)
HOST_GID=$(id -g)
export HOST_UID
export HOST_GID

#affix base BASE_DOCKER_IMAGE version to CI image name
export IMAGE_NAME="imdt-qualcomm-ci:${BASE_DOCKER_IMAGE##*:}"
echo "IMAGE_NAME=$IMAGE_NAME" >> "$GITHUB_ENV"

#verify that the host .netrc file exists before attempting to mount it
if [ ! -f "${HOME}/.netrc" ]; then
    echo "ERROR: ${HOME}/.netrc not found."
    echo "Docker Compose cannot mount a missing file."
    exit 1
fi

docker compose \
    -f "${GITHUB_WORKSPACE}"/qualcomm_ci/docker/docker-compose.yaml \
    up -d 
