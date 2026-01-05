#!/bin/bash
#=============================================================================================================================================================================
#title: generate-sdk.sh
#description: Generate a Yocto SDK for the specified image, rename and move to the release directory.
#=============================================================================================================================================================================

#cache distro name as yocto unsets the variable
DISTRO_NAME="${DISTRO}"

#set Yocto environment
source /home/dev/tools/container_scripts/setup-yocto-environment.sh

bitbake "${IMAGE}" -c populate_sdk

#locate generated SDK script and rename
SDK_DIR="${QCOM_ROOT_DIR}/LE.PRODUCT.2.1.r1/apps_proc/build-${DISTRO_NAME}/tmp-glibc/deploy/sdk/"

RELEASE_DIR="/home/dev/Qualcomm/release"
if [[ ! -d "$RELEASE_DIR" ]]; then
    mkdir -p "$RELEASE_DIR"
fi

#output name format: [release_name_without_prebuilt_suffix]-sdk-v[build_version].sh
OUTPUT_NAME="${RELEASE_DIR}/${RELEASE_NAME%_prebuilt*}-sdk-v${BUILD_VERSION}.sh"

#verify that there is exactly one sh script in SDK_DIR
cd "$SDK_DIR" || exit 1
sdk_sh="$(find -maxdepth 1 -type f -name '*.sh')"

if [[ -z "$sdk_sh" ]]; then
    echo "ERROR: No SDK files found in ${SDK_DIR}"
    exit 1
fi

#rename SDK script to output_name
mv "$sdk_sh" "$OUTPUT_NAME"
