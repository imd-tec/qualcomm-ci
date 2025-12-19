#!/bin/bash
#=============================================================================================================================================================================
#title: extract-sources.sh
#description:
#   For use in the build-qc-bsp-reusable reusable workflow.
#   Extract Qualcomm source files and optional assets into build project directory.
#   Tarballs to be extracted should be located under:
#       /mnt/nvme1/qcom_ci/builds/SHARED_SOURCES for Qualcomm source files
#       /mnt/nvme1/qcom_ci/builds/<project>/<version>/sources for build specific assets (patches, cdt, etc.)
#   In the event that build patches cannot be located in the specified build folder, the script will default to patches located in:
#      /mnt/nvme1/qcom_ci/builds/SHARED_SOURCES/fallback_patches/<project>/ for fallback patch files
#assumes:
#   BUILD_PROJECT_PATH is set to the CI build project directory path.
#   QCS_SOURCES is set to the Qualcomm source file name.
#   PATCH_FALLBACK_PATH is set to the fallback patch directory path..
#   CI_DIR is set to the root CI directory path.
#outputs:
#   Extracted qcs source files and build-specific assets in the build project directory.
#=============================================================================================================================================================================
set -eux

#set sources path
SOURCES_PATH=${BUILD_PROJECT_PATH}/sources

#check if source files are already present in build project path
if [[ -d "${BUILD_PROJECT_PATH}/${QCS_SOURCES}" ]]; then
    echo "Warning: ${BUILD_PROJECT_PATH}/${QCS_SOURCES} already exists. Cleaning up..."
    rm -rf "${BUILD_PROJECT_PATH:?}/${QCS_SOURCES:?}"
fi

#locate and extract build-specific assets arhives(patch, cdt, etc.), as applicable
assets_to_extract=()


if [ -f "${SOURCES_PATH}/patches.tar.gz" ]; then
    assets_to_extract+=("patches.tar.gz")
else
    echo "Warning: required patches.tar.gz not found in ${SOURCES_PATH}. Please ensure that the correct patch files are present in the build directory. "
    echo "Attempting to locate fallback patches... "

    if [ -f "${PATCH_FALLBACK_PATH}/patches.tar.gz" ]; then
        echo "Fallback patches found. Extracting to build sources directory..."
        tar -xf "${PATCH_FALLBACK_PATH}/patches.tar.gz" -C "$BUILD_PROJECT_PATH"
    else
        echo "Error: No fallback patches found. Exiting."
        exit 1
    fi
fi

#extend to handle other assets as required
#e.g., if [[ "$BUILD_CDT" == "1" ]]; then assets_to_extract+=("cdt.tar.gz"); fi 

for asset in "${assets_to_extract[@]}"; do
    if [[ -f "${SOURCES_PATH}/$asset" ]]; then
    echo "Extracting $asset..."
    tar -xf "${SOURCES_PATH}/$asset" -C "$BUILD_PROJECT_PATH"
        if [[ -f "$BUILD_PROJECT_PATH/$asset"  ]]; then
            echo "$asset extracted to ""$BUILD_PROJECT_PATH/$asset"
        fi
    fi
done

#extract Qualcomm source files
tar -xf "${CI_DIR}/builds/SHARED_SOURCES/${QCS_SOURCES}.tar.gz" -C "$BUILD_PROJECT_PATH"
if [[ -d "${BUILD_PROJECT_PATH}/${QCS_SOURCES}" ]]; then
    echo " ${QCS_SOURCES} extracted to ${BUILD_PROJECT_PATH}/"
else
    echo "Error: ${QCS_SOURCES} failed to extract to ${BUILD_PROJECT_PATH}/${QCS_SOURCES}"
    exit 1
fi

