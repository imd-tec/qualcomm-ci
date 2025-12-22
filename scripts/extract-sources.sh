#!/bin/bash
#=============================================================================================================================================================================
#title: extract-sources.sh
#description:
#   For use in the imdt-build-qcom-bsp reusable workflow.
#   Extract Qualcomm source files and optional assets into build project directory.
#   Tarballs to be extracted should be located under:
#       $SHARED_SOURCES_DIR for Qualcomm source files
#       $BUILD_PROJECT_DIR/sources for build specific assets (patches, cdt, etc.)
#   In the event that build patches cannot be located in the specified build folder, the script will default to patches located in:
#       $SHARED_SOURCES_DIR/fallback_patches/<project>/ for fallback patch files
#assumes:
#   BUILD_PROJECT_DIR is set to the CI build project directory path.
#   QCS_SOURCES is set to the Qualcomm source file name.
#   PATCH_FALLBACK_PATH is set to the fallback patch directory path.
#outputs:
#   Extracted qcs source files and build-specific assets in the build project directory.
#=============================================================================================================================================================================
set -eux

#set sources path
PROJECT_SOURCES_DIR=${BUILD_PROJECT_DIR}/sources

#check if source files are already present in build project path
if [[ -d "${BUILD_PROJECT_DIR}/${QCS_SOURCES}" ]]; then
    echo "Warning: ${BUILD_PROJECT_DIR}/${QCS_SOURCES} already exists. Cleaning up..."
    rm -rf "${BUILD_PROJECT_DIR:?}/${QCS_SOURCES:?}"
fi

#locate and extract build-specific assets archives(patch, cdt, etc.), as applicable
assets_to_extract=()


if [ -f "${PROJECT_SOURCES_DIR}/patches.tar.gz" ]; then
    assets_to_extract+=("patches.tar.gz")
else
    echo "Warning: required patches.tar.gz not found in ${PROJECT_SOURCES_DIR}. Please ensure that the correct patch files are present in the build directory. "
    echo "Attempting to locate fallback patches... "

    if [ -f "${PATCH_FALLBACK_PATH}/patches.tar.gz" ]; then
        echo "Fallback patches found. Extracting to build sources directory..."
        tar -xf "${PATCH_FALLBACK_PATH}/patches.tar.gz" -C "$BUILD_PROJECT_DIR"
    else
        echo "Error: No fallback patches found. Exiting."
        exit 1
    fi
fi

#extend to handle other assets as required
#e.g., if [[ "$BUILD_CDT" == "1" ]]; then assets_to_extract+=("cdt.tar.gz"); fi 

for asset in "${assets_to_extract[@]}"; do
    if [[ -f "${PROJECT_SOURCES_DIR}/$asset" ]]; then
    echo "Extracting $asset..."
    tar -xf "${PROJECT_SOURCES_DIR}/$asset" -C "$BUILD_PROJECT_DIR"
        if [[ -f "$BUILD_PROJECT_DIR/$asset"  ]]; then
            echo "$asset extracted to ""$BUILD_PROJECT_DIR/$asset"
        fi
    fi
done

#extract Qualcomm source files
tar -xf "${SHARED_SOURCES_DIR}/${QCS_SOURCES}.tar.gz" -C "$BUILD_PROJECT_DIR"
if [[ -d "${BUILD_PROJECT_DIR}/${QCS_SOURCES}" ]]; then
    echo " ${QCS_SOURCES} extracted to ${BUILD_PROJECT_DIR}/"
else
    echo "Error: ${QCS_SOURCES} failed to extract to ${BUILD_PROJECT_DIR}/${QCS_SOURCES}"
    exit 1
fi
