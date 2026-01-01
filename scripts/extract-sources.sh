#!/bin/bash
#=============================================================================================================================================================================
#title: extract-sources.sh
#description:
#   For use in the imdt-build-qcom-bsp reusable workflow.
#   Extracts Qualcomm source files and additional assets (e.g., patches) into the specified build project directory.
#   Tarballs to be extracted should be located under $BSP_SOURCES_DIR.
#assumes:
#   BUILD_PROJECT_DIR is set to the CI build project directory path.
#   QCS_SOURCES is set to the Qualcomm source file name, as specified in the manifest yaml config.
#=============================================================================================================================================================================
set -eu

#ensure that QCS_SOURCES does not contain any .tar.gz extension
QCS_SOURCES=${QCS_SOURCES%.tar.gz}

#set sources path
PROJECT_SOURCES_DIR=${BSP_SOURCES_DIR}/${QCS_SOURCES}

#check if source files are already present in build project path; clean if so
if [[ -d "${BUILD_PROJECT_DIR}/${QCS_SOURCES}" ]]; then
    echo "Warning: ${BUILD_PROJECT_DIR}/${QCS_SOURCES} already exists. Cleaning up..."
    rm -rf "${BUILD_PROJECT_DIR:?}/${QCS_SOURCES:?}"
fi

#extract build-specific assets archives(patch, cdt, etc.), as applicable
assets_to_extract=()

#extend to handle other assets as required
if [ -f "${PROJECT_SOURCES_DIR}/patches.tar.gz" ]; then
    assets_to_extract+=("patches.tar.gz")
else
    echo "Warning: 'patches.tar.gz' not found in ${PROJECT_SOURCES_DIR}. Continuing without extracting patches..."
fi

#extract additional build assets
for asset_tar in "${assets_to_extract[@]}"; do
    asset_name="${asset_tar%.tar.gz}"
    #check if asset tarball exists
    if [[ -f "${PROJECT_SOURCES_DIR}/${asset_tar}" ]]; then
        #check if extracted directory already exists; clean if so
        if [[ -d "${BUILD_PROJECT_DIR}/${asset_name}" ]]; then
            echo "Warning: ${BUILD_PROJECT_DIR}/${asset_name} already exists. Cleaning up..."
            rm -rf "${BUILD_PROJECT_DIR:?}/${asset_name:?}"
        fi

        #extract fresh asset tarball
        echo "Extracting ${asset_tar} to ${BUILD_PROJECT_DIR}/"
        tar -xf "${PROJECT_SOURCES_DIR}/${asset_tar}" -C "$BUILD_PROJECT_DIR"
        #verify extraction
        if [[ -d "${BUILD_PROJECT_DIR}/${asset_name}"  ]]; then
            echo "${asset_name} extracted to '${BUILD_PROJECT_DIR}/${asset_name}' successfully."
        else
            echo "Error: ${asset_tar} failed to extract to ${BUILD_PROJECT_DIR}"
            exit 1
        fi
    fi
done

#extract Qualcomm source files
if [[ -f "${PROJECT_SOURCES_DIR}/${QCS_SOURCES}.tar.gz" ]]; then
    echo "Extracting ${QCS_SOURCES}.tar.gz to ${BUILD_PROJECT_DIR}/"
    #create target directory
    mkdir -p "${BUILD_PROJECT_DIR}/${QCS_SOURCES}"
    #extract under target directory, stripping top-level component
    tar -xf "${PROJECT_SOURCES_DIR}/${QCS_SOURCES}.tar.gz" -C "${BUILD_PROJECT_DIR}/${QCS_SOURCES}" \
        --strip-components=1
else
    echo "Error: Source tarball '${PROJECT_SOURCES_DIR}/${QCS_SOURCES}.tar.gz' not found"
    exit 1
fi

#verify extraction
if [[ -d "${BUILD_PROJECT_DIR}/${QCS_SOURCES}" ]]; then
    echo " ${QCS_SOURCES} extracted to ${BUILD_PROJECT_DIR}/${QCS_SOURCES} successfully."
else
    echo "Error: ${QCS_SOURCES}.tar.gz failed to extract to ${BUILD_PROJECT_DIR}"
    exit 1
fi
