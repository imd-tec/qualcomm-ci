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


#Commands
set -euo pipefail -x
ls /Qualcomm
ls /home/dev/
export QCOM_ROOT_DIR=/Qualcomm/qcs8550-le-1-0_amss_standard_oem_apqgps
$QCOM_ROOT_DIR
/home/dev/build_netrc.sh
# cat /home/dev/.netrc

#Synchronise Repos
tar -xf /Qualcomm/patches.tar.gz -C /Qualcomm/
ls /Qualcomm/