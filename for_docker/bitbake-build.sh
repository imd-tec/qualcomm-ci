#!/bin/bash
#Commands
set -euo pipefail

echo "\n\n====================BITBAKE-BUILD COMMANDS========================="
echo "DETAILS"
echo "CONTAINER PWD: $(pwd)"
echo "CONTAINER USER IDs: $(id)"
# echo "HOST IDs: $HOST_UID $HOST_GID"
echo "SOURCES_REPO: $SRC_REPO"
echo "MANI_REPO: $MANI_REPO"
echo "MANI_BRANCH: $MANI_BRANCH" 
echo "MANI_XML: $MANI_XML"

export QCOM_ROOT_DIR="/home/dev/Qualcomm/${SRC_REPO}"

#VERIFY THAT FILES OWNERSHIP WAS CHANGED CORRECTLY
ls -la


#CREATE NETRC FILE
printf "\n\nCREATING NETRC"
bash /home/dev/tools/build_netrc.sh

#PATCH AND SYNCHRONISE REPOS
tar -xf /home/dev/Qualcomm/patches.tar.gz -C /home/dev/Qualcomm/
# ls /Qualcomm/

printf "\n\nPATCHING"
PATCHFILE="/home/dev/Qualcomm/patches/sync_snap_v2_remove_chipcode_copy.patch" 
TARGET="${QCOM_ROOT_DIR}/LE.PRODUCT.2.1.r1/apps_proc/sync_snap_v2.sh"
patch --batch "$TARGET" "$PATCHFILE" 

printf "\n\nSYNCHRONISING REPOS"
bash home/dev/build_scripts/sync_repos.sh -u $MANI_REPO -b $MANI_BRANCH -m $MANI_XML

#CONFIGURE KERNEL DIRECTORIES
printf "\n\nCONFIGURING KERNEL DIRECTORIES"
bash home/dev/build_scripts/setup_kernel.sh

#APPLY IMDT PATCHES TO QC SOURCE
printf "\n\nAPPLY IMDT PATCHES TO QC SOURCE"
cd ${QCOM_ROOT_DIR}/LE.PRODUCT.2.1.r1/apps_proc
bash home/dev/imdt-patch-qcs8550-build.sh


