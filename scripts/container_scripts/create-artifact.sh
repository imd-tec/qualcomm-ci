#!/bin/bash
#=============================================================================================================================================================================
#title: create-artifact.sh
#description:  Creates output release artifact tarball from built source. 
#              Non-development builds are stored in $CI_DIR/builds/<versioned-build>/release/.
#              Development builds are stored in $CI_DIR/builds/development/release/<triggering-manifest-name>/.
#assumes:      BUILD_VERSION, RELEASE_NAME, MANIFEST_REPOSITORY, QCOM_ROOT_DIR environment variables are set.
#=============================================================================================================================================================================
set -e

#define release path and name based on build type
if [ "$BUILD_VERSION" == "development" ]; then
    REPO_NAME=$(basename "$MANIFEST_REPOSITORY")
    RELEASE_PATH="/home/dev/Qualcomm/release/${REPO_NAME}"
    FULL_RELEASE_NAME="${RELEASE_NAME}_${BUILD_VERSION}"
else
    FULL_RELEASE_NAME="${RELEASE_NAME}_v${BUILD_VERSION}"
    RELEASE_PATH="/home/dev/Qualcomm/release"
fi

RELEASE_DIR="${RELEASE_PATH}/${FULL_RELEASE_NAME}"
OUTPUT_TAR="${RELEASE_DIR}.tar.gz"

#if present, remove previous release directory and tarball
if [ -d "$RELEASE_DIR" ]; then rm -rf "$RELEASE_DIR"; fi
if [ -f "$OUTPUT_TAR" ]; then rm -f "$OUTPUT_TAR"; fi

#create new prebuilt release
cd /home/dev/build_scripts
python3 create_release.py \
    -r "$RELEASE_DIR" \
    -x "${QCOM_ROOT_DIR}/contents.xml" \
    -b "${QCOM_ROOT_DIR}"

#create fresh prebuilt tarball 
cd "$RELEASE_PATH"
tar -czvf "$OUTPUT_TAR" "$FULL_RELEASE_NAME"

#verify tarball creation and remove un-compresssed release directory
if [ -f "$OUTPUT_TAR" ]; then
    echo "Release artifact compressed at $OUTPUT_TAR"
    echo "Removing uncompressed release directory..."
    if [ -d "$RELEASE_DIR" ]; then
        echo "Removing $RELEASE_DIR"
        rm -rf "$RELEASE_DIR"
    fi
else
    echo "ERROR: Release artifact creation failed at $OUTPUT_TAR"
    exit 1
fi
