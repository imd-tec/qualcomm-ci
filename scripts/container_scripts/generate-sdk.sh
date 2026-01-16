#!/bin/bash
#=============================================================================================================================================================================
#title: generate-sdk.sh
#description: Generate a Yocto SDK for the specified image, and locate, rename and move it to the release directory.
#=============================================================================================================================================================================

#cache distro name as yocto unsets the variable
DISTRO_NAME="${DISTRO}"

#set Yocto environment
source /home/dev/tools/container_scripts/setup-yocto-environment.sh

#generate SDK 
bitbake "${IMAGE}" -c populate_sdk

#locate generated SDK script
SDK_DIR="${QCOM_ROOT_DIR}/LE.PRODUCT.2.1.r1/apps_proc/build-${DISTRO_NAME}/tmp-glibc/deploy/sdk/"
cd "$SDK_DIR" || exit 1
SDK_SH="$(find -maxdepth 1 -type f -name '*.sh')"
if [[ -z "$SDK_SH" ]]; then
    echo "ERROR: No SDK files found in ${SDK_DIR}"
    exit 1
fi

#define release directory based on build type and set SDK filename
#sdk output name format: [release_name_without_prebuilt_suffix]-sdk-v[build_version].sh
if [ "$BUILD_VERSION" == "development" ]; then
    RELEASE_DIR="/home/dev/Qualcomm/release/${REPO_NAME}"
    SDK_FILENAME="${RELEASE_NAME%_prebuilt*}-sdk-${BUILD_VERSION}.sh"
else
    SDK_FILENAME="${RELEASE_NAME%_prebuilt*}-sdk-v${BUILD_VERSION}.sh"
    RELEASE_DIR="/home/dev/Qualcomm/release"
fi

#ensure release directory exists
if [[ ! -d "$RELEASE_DIR" ]]; then
    mkdir -p "$RELEASE_DIR"
fi


#move the SDK script to the release directory
mv "$SDK_SH" "$RELEASE_DIR/$SDK_FILENAME"
