#!/bin/bash
#=============================================================================================================================================================================
#title: generate_sdk.sh
#description: Generates Yocto SDK using bitbake and renames the output SDK script. For use within the qualcomm-ci Docker container.
#=============================================================================================================================================================================

#cache distro name as yocto unsets the variable
DISTRO_NAME="${DISTRO}"

#set Yocto environment
source /home/dev/tools/setup_yocto_env.sh

bitbake ${IMAGE} -c populate_sdk

#locate generated SDK script and rename
SDK_DIR="${QCOM_ROOT_DIR}/LE.PRODUCT.2.1.r1/apps_proc/build-${DISTRO_NAME}/tmp-glibc/deploy/sdk/"

#output name format: [release_name_without_prebuilt_suffix]-sdk-v[build_version].sh
OUTPUT_NAME="${SDK_DIR}/${RELEASE_NAME%_prebuilt*}-sdk-v${BUILD_VERSION}.sh"

#verify that there is exactly one sh script in SDK_DIR
cd "$SDK_DIR" || exit 1
sdk_sh="$(find -maxdepth 1 -type f -name '*.sh')"

if [[ -z "$sdk_sh" ]]; then
echo "ERROR: No SDK files found in ${SDK_DIR}"
exit 1
fi

#rename SDK script to output_name
mv -- "$sdk_sh" "$OUTPUT_NAME"