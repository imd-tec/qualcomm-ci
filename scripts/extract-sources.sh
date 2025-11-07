#!/bin/bash
# Extracts Qualcomm source files and optional assets into build project directory.
set -euo pipefail

#set sources path
SOURCES_PATH=${BUILD_PROJECT_PATH}/SOURCES

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
    echo "Qualcomm sources ${QCS_SOURCES} extracted to "${BUILD_PROJECT_PATH}/"
else
    echo "Error: Qualcomm sources "${QCS_SOURCES}" failed to extract to "${BUILD_PROJECT_PATH}/${QCS_SOURCES}"
    exit 1
fi