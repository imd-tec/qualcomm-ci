#!/bin/bash
#=============================================================================================================================================================================
#title: create-artifact.sh
#description: Creates output release artifact tarball from built source.
#=============================================================================================================================================================================
set -e
FULL_RELEASE_NAME="${RELEASE_NAME}_v${BUILD_VERSION}"
RELEASE_DIR="/home/dev/Qualcomm/release/${FULL_RELEASE_NAME}"
OUTPUT_TAR="${RELEASE_DIR}.tar.gz"

#remove existing release directory if present
if [ -d "$RELEASE_DIR" ]; then
    rm -rf "$RELEASE_DIR"
fi

mkdir -p "$RELEASE_DIR"

#create new prebuilt release
cd /home/dev/build_scripts
python3 create_release.py \
    -r "$RELEASE_DIR" \
    -x "${QCOM_ROOT_DIR}/contents.xml" \
    -b "${QCOM_ROOT_DIR}"

#create prebuilt tarball 
cd /home/dev/Qualcomm/release
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
