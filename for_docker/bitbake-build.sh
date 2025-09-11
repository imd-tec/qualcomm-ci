#!/bin/bash

# Function to display usage
usage() {
    echo "Usage: $0 --manifest-repo <repo_url> --manifest-branch <branch_name>--manifest-xml <filename> [--sdk] [--swu] [--v2n]"
    exit 1
}

# Parse arguments
while [[ "$#" -gt 0 ]]; do
    case $1 in
        --manifest-repo) manifest_repo="$2"; shift ;;
        --manifest-xml) manifest_xml="$2"; shift ;;
        --manifest-branch) manifest_branch="$2"; shift ;;
        --sdk) sdk=1 ;;
        --swu) swu=1 ;;
        --v2n) v2n=1 ;;
        *) echo "Unknown parameter passed: $1"; usage ;;
    esac
    shift
done

# Validate arguments
if [[ -z "$manifest_repo" || -z "$manifest_xml" || -z "$manifest_branch" ]]; then
    echo "Error: Missing required arguments."
    usage
fi

# Display the provided arguments
echo "Manifest Repo: $manifest_repo"
echo "Manifest XML: $manifest_xml"
echo "Manifest Branch: $manifest_branch"
echo "Build SDK: $sdk"
echo "Build SWU: $swu"
echo "Build for V2N: $v2n"

echo "# Script running inside docker container."
git config --global user.name "CI machine"
git config --global user.email "imdt@imd-tec.com"

echo "# Test github authentication"
ssh git@github.com

set -e

echo "# repo init."
repo init -u ${manifest_repo} -b ${manifest_branch} -m ${manifest_xml}.xml

# echo "# repo sync."
# repo sync

# TEMPLATECONF=${PWD}/sources/meta-imdt-renesas/docs/template/conf/ source sources/poky/oe-init-build-env

# echo "# Prepare build environment"

# echo "# Building the image."
# export MACHINE=imdt-v2h-sbc
# bitbake imdt-image-weston
# bitbake imdt-image-core

# mkdir -p ~/output/image/v2h

# if [[ "$swu" -eq 1 ]]; then
#     bitbake imdt-image-weston-swu
#     cp tmp/deploy/images/imdt-v2h-sbc/imdt-image-weston-swu-imdt-v2h-sbc-*.swu ~/output/image/v2h

#     bitbake imdt-image-core-swu
#     cp tmp/deploy/images/imdt-v2h-sbc/imdt-image-core-swu-imdt-v2h-sbc-*.swu ~/output/image/v2h
# fi

# if [[ "$sdk" -eq 1 ]]; then
#     bitbake -c populate_sdk imdt-image-weston
#     mkdir -p ~/output/sdk
# fi

# cp tmp/deploy/images/imdt-v2h-sbc/imdt-image-weston-imdt-v2h-sbc-*.wic.gz  ~/output/image/v2h
# cp tmp/deploy/images/imdt-v2h-sbc/imdt-image-core-imdt-v2h-sbc-*.wic.gz  ~/output/image/v2h
# cp tmp/deploy/images/imdt-v2h-sbc/Flash_Writer_SCIF_RZV2H_DEV_INTERNAL_MEMORY.mot ~/output/image/v2h
# cp tmp/deploy/images/imdt-v2h-sbc/bl2_bp_spi-imdt-v2h-sbc.srec ~/output/image/v2h
# cp tmp/deploy/images/imdt-v2h-sbc/bl2_bp_emmc-imdt-v2h-sbc.srec ~/output/image/v2h
# cp tmp/deploy/images/imdt-v2h-sbc/fip-imdt-v2h-sbc.srec ~/output/image/v2h


# if [[ "$v2n" -eq 1 ]]; then
#     export MACHINE=imdt-v2n-sbc
#     bitbake imdt-image-weston
#     bitbake imdt-image-core

#     mkdir -p ~/output/image/v2n

#     if [[ "$swu" -eq 1 ]]; then
#         bitbake imdt-image-weston-swu
#         cp tmp/deploy/images/imdt-v2n-sbc/imdt-image-weston-swu-imdt-v2n-sbc-*.swu ~/output/image/v2n

#         bitbake imdt-image-core-swu
#         cp tmp/deploy/images/imdt-v2n-sbc/imdt-image-core-swu-imdt-v2n-sbc-*.swu ~/output/image/v2n
#     fi

#     cp tmp/deploy/images/imdt-v2n-sbc/imdt-image-weston-imdt-v2n-sbc-*.wic.gz  ~/output/image/v2n
#     cp tmp/deploy/images/imdt-v2n-sbc/imdt-image-core-imdt-v2n-sbc-*.wic.gz  ~/output/image/v2n
#     cp tmp/deploy/images/imdt-v2n-sbc/Flash_Writer_SCIF_RZV2N_EVK_LPDDR4X.mot ~/output/image/v2n
#     cp tmp/deploy/images/imdt-v2n-sbc/bl2_bp_spi-imdt-v2n-sbc.srec ~/output/image/v2n
#     cp tmp/deploy/images/imdt-v2n-sbc/bl2_bp_mmc-imdt-v2n-sbc.srec ~/output/image/v2n
#     cp tmp/deploy/images/imdt-v2n-sbc/fip-imdt-v2n-sbc.srec ~/output/image/v2n
    
#     if [[ "$sdk" -eq 1 ]]; then
#         bitbake -c populate_sdk imdt-image-weston
#     fi
# fi

# if [[ "$sdk" -eq 1 ]]; then
#     cp tmp/deploy/sdk/*.sh ~/output/sdk
# fi