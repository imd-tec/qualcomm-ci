#!/bin/bash
# Extracts Qualcomm source files and optional assets into build project directory.
set -euo pipefail

#verify that CI directory is included in project path
if grep -q "${CI_DIR}" <<< "${BUILD_PROJECT_PATH}"; then
echo "Using project path: ${BUILD_PROJECT_PATH}"
else
echo "ERROR: project path ${BUILD_PROJECT_PATH} is invalid. It must be under ${CI_DIR}."
exit 1
fi

#create build project directory
mkdir -p "${BUILD_PROJECT_PATH}" && cd "${BUILD_PROJECT_PATH}"

#extract optional assets (patch, cdt, etc.) as applicable
candidates=()
if [[ "$HAS_PATCHES" == "1" ]]; then
candidates+=("patches.tar.gz")
fi

#extend to handle other assets as required
#e.g., if [[ "$BUILD_CDT" == "1" ]]; then ...

for asset in "${candidates[@]}"; do
    if [[ -f "${BUILD_PROJECT_PATH}/SOURCES/$asset" ]]; then
    echo "Extracting $asset..."
    tar -xf "${BUILD_PROJECT_PATH}/SOURCES/$asset" -C .
    fi
done

#extract Qualcomm source files
tar -xf "${CI_DIR}/builds/SHARED_SOURCES/${QCS_SOURCES}.tar.gz" -C .