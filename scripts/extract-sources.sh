#!/bin/bash
# Extracts Qualcomm source files and optional assets into build project directory.
# ASSUMES:
#   - BUILD_PROJECT_PATH is set to the CI build project directory path
#   - QCS_SOURCES is set to the Qualcomm source file name
#   - CI_DIR is set to the root CI directory path
#   - HAS_PATCHES is set to 0 or 1
set -euo pipefail

#set sources path
SOURCES_PATH=${BUILD_PROJECT_PATH}/SOURCES

#check if source files are already present in build project path
if [[ -d "${BUILD_PROJECT_PATH}/${QCS_SOURCES}" ]]; then
    echo "Warning: ${BUILD_PROJECT_PATH}/${QCS_SOURCES} already exists. Cleaning up..."
    rm -rf "${BUILD_PROJECT_PATH:?}/${QCS_SOURCES:?}"
fi

#extract optional assets (patch, cdt, etc.) as applicable
candidates=()
if [[ "$HAS_PATCHES" == "1" ]]; then
candidates+=("patches.tar.gz")
fi


#extend to handle other assets as required
#e.g., if [[ "$BUILD_CDT" == "1" ]]; then ...

for asset in "${candidates[@]}"; do
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
    echo "Qualcomm sources ${QCS_SOURCES} extracted to ${BUILD_PROJECT_PATH}/"
else
    echo "Error: Qualcomm sources ${QCS_SOURCES} failed to extract to ${BUILD_PROJECT_PATH}/${QCS_SOURCES}"
    exit 1
fi