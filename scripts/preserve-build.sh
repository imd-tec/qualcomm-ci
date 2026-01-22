#!/bin/bash
#=============================================================================================================================================================================
#title: preserve-build.sh
#description:
#   Provided PRESERVE_BUILD_DIR is enabled on workflow dispatch, build source files are moved to
#   the PRESERVED_BUILDS directory under a timestamped directory named after the build.
#   A BUILD_INFO.txt log file is created in the preserved build directory containing build metadata.
#usage: 
#   preserve-build.sh <build_status> <run_url> <branch> <actor>
#=============================================================================================================================================================================
set -e

echo "'PRESERVE_BUILD_DIR' is 'true'. Preserving build source files..."

STATUS=$1
RUN_URL=$2
BRANCH=$3
ACTOR=$4 
          
if [ "${BUILD_VERSION}" == "development" ]; then
    REPO_NAME=$(basename "${MANIFEST_REPOSITORY}")
    BUILD_NAME="${REPO_NAME}_development"
fi

timestamp=$(date +%Y%m%d_%H%M%S)
preserved_dirname="${BUILD_NAME}_${timestamp}"
preserved_path="${CI_DIR}/builds/PRESERVED_BUILDS/${preserved_dirname}"
mkdir -p "${preserved_path}"

if [ -d "${BUILD_PROJECT_DIR:?}/${QCS_SOURCES}" ]; then           
    mv "${BUILD_PROJECT_DIR}/${QCS_SOURCES}" "${preserved_path}/${QCS_SOURCES}"
fi

if [ -d "${BUILD_PROJECT_DIR:?}/patches" ]; then
    mv "${BUILD_PROJECT_DIR}/patches" "${preserved_path}/patches"
fi

log_file="${preserved_path}/BUILD_INFO.txt"

echo "==========================================" >> "$log_file"
echo "         PRESERVED BUILD METADATA         " >> "$log_file"
echo "==========================================" >> "$log_file"
echo "Repository   : $MANIFEST_REPOSITORY"        >> "$log_file"
echo "Branch       : $BRANCH"                     >> "$log_file"
echo "Manifest:    : $MANIFEST_XML"               >> "$log_file"
echo "Build Name   : $BUILD_NAME"                 >> "$log_file"
echo "Build Status : $STATUS"                     >> "$log_file"
echo "Triggered By : $ACTOR"                      >> "$log_file"
echo "------------------------------------------" >> "$log_file"
echo "Run Link     : $RUN_URL"                    >> "$log_file"
echo "==========================================" >> "$log_file"

echo "Preserved build files moved to: ${preserved_path}/"
