#!/bin/bash
#=============================================================================================================================================================================
#title: generate-swu.sh
#description: Generate a SWUpdate for the specified image, and locate and move it to the release directory.
#=============================================================================================================================================================================
set -ex

#set Yocto environment
source /home/dev/tools/container_scripts/setup-yocto-environment.sh

#generate the SWU package
echo "Generating SWUpdate package for image: ${IMAGE}"
bitbake "${IMAGE}-swu"

#locate the generated swu package
SWU_DIR="${QCOM_ROOT_DIR}/LE.PRODUCT.2.1.r1/apps_proc/build-${DISTRO_NAME}/tmp-glibc/deploy/images/${MACHINE}/"

#find the SWU package
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

SWU_FILENAME="${IMAGE}-sdk-${MACHINE}.swu"

#move the SWU package to the release directory
mv "$swu" "$RELEASE_DIR/$SWU_FILENAME"
