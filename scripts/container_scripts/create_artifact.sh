#!/bin/bash
#=============================================================================================================================================================================
#title: create_artifact.sh
#description: Creates output release artifact tarball from built source.
#=============================================================================================================================================================================
set -xe
FULL_RELEASE_NAME="${RELEASE_NAME}_v${BUILD_VERSION}"
RELEASE_DIR="/home/dev/Qualcomm/release/${FULL_RELEASE_NAME}"
OUTPUT_TAR="${RELEASE_DIR}.tar.gz"

#if release directory already exists, remove it
if [ -d "$RELEASE_DIR" ]; then
rm -rf "$RELEASE_DIR"
fi

#if previous prebuilt tarball exists, remove it
if [ -f "$OUTPUT_TAR" ]; then
rm -f "$OUTPUT_TAR"
fi

#create new prebuilt release directory
cd /home/dev/build_scripts
python3 create_release.py \
    -r "$RELEASE_DIR" \
    -x "${QCOM_ROOT_DIR}/contents.xml" \
    -b "${QCOM_ROOT_DIR}"

#create fresh prebuilt tarball 
ls -la /home/dev/Qualcomm
cd /home/dev/Qualcomm
tar -czvf "$OUTPUT_TAR" "$FULL_RELEASE_NAME"

#verify tarball creation and remove non-compresssed release directory
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