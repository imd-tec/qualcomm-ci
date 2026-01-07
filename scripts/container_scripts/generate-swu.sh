#!/bin/bash
#=============================================================================================================================================================================
#title: generate-swu.sh
#description: Generate an swu update image, then locate and move it to the build release directory.
#=============================================================================================================================================================================
set -ex

#cache build variables to avoid yocto environment setup unsetting the variables
DISTRO_NAME="${DISTRO}"
MACHINE_NAME="${MACHINE}"    
IMAGE_NAME="${IMAGE}"

#set Yocto environment
source /home/dev/tools/container_scripts/setup-yocto-environment.sh

#generate the SWU image
bitbake "${IMAGE_NAME}-swu"

#locate the generated swu image
SWU_DIR="${QCOM_ROOT_DIR}/LE.PRODUCT.2.1.r1/apps_proc/build-${DISTRO_NAME}/tmp-glibc/deploy/images/${MACHINE_NAME}/"

cd "$SWU_DIR" || exit 1

swu="$(find -maxdepth 1 -type f -name '*.swu')"
if [[ -z "$swu" ]]; then
    echo "ERROR: No .swu files found in ${SWU_DIR}"
    exit 1
fi

#ensure release directory exists
RELEASE_DIR="/home/dev/Qualcomm/release"
if [[ ! -d "$RELEASE_DIR" ]]; then
    mkdir -p "$RELEASE_DIR"
fi

SWU_FILENAME="${IMAGE_NAME}-sdk-${MACHINE_NAME}.swu"

#move the SWU image to the release directory
mv "$swu" "$RELEASE_DIR/$SWU_FILENAME"
