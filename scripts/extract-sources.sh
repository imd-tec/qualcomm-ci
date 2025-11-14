#!/bin/bash
#=============================================================================================================================================================================
#title: extract.sources.sh
#description:
#   For use in the build-qc-bsp-reusable reusable workflow.
#   Extract Qualcomm source files and optional assets into build project directory.
#   Tarballs to be extracted should be located under:
#       /mnt/nvme1/qcom_ci/builds/SHARED_SOURCES for Qualcomm source files
#       /mnt/nvme1/qcom_ci/builds/<project>/<version>/SOURCES for optional assets (patches, cdt, etc.)
#assumes:
#   BUILD_PROJECT_PATH is set to the CI build project directory path.
#   QCS_SOURCES is set to the Qualcomm source file name.
#   CI_DIR is set to the root CI directory path.
#   HAS_PATCHES is set to 0 or 1.
#outputs:
#   Extracted qcs source files and build-specific assets in the build project directory.
#=============================================================================================================================================================================
set -eu

function check_required_vars() {
    local missing_vars=()
    required_vars=("BUILD_PROJECT_PATH" "QCS_SOURCES" "CI_DIR" "HAS_PATCHES")
    for var_name in "${required_vars[@]}"; do
        if [[ -z "${var_name:-}" ]]; then
            missing_vars+=("$var_name")
        fi
    done

    if [[ ${#missing_vars[@]} -gt 0 ]]; then
        echo "Error: The following required environment variables are not set: ${missing_vars[*]}"
        exit 1
    fi
}

function extract_sources() {
    #set sources path
    SOURCES_PATH=${BUILD_PROJECT_PATH}/SOURCES

    #check if source files are already present in build project path
    if [[ -d "${BUILD_PROJECT_PATH}/${QCS_SOURCES}" ]]; then
        echo "Warning: ${BUILD_PROJECT_PATH}/${QCS_SOURCES} already exists. Cleaning up..."
        rm -rf "${BUILD_PROJECT_PATH:?}/${QCS_SOURCES:?}"
    fi

    #extract build-specific assets (patch, cdt, etc.), as applicable
    candidates=()
    if [[ "$HAS_PATCHES" == "1" ]]; then
    candidates+=("patches.tar.gz")
    fi

    #TODO: Added logic for using previous patch if current patch file is not found

    #extend to handle other assets as required
    #e.g., if [[ "$BUILD_CDT" == "1" ]]; then candidates+=("cdt.tar.gz"); fi 
    
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
}


check_required_vars
extract_sources
