#!/bin/bash
#Commands
set -euo pipefail

echo " "
echo "====================BITBAKE-BUILD COMMANDS========================="
echo "DETAILS"
echo "CONTAINER PWD: $(pwd)"
echo "CONTAINER USER IDs: $(id)"
# echo "HOST IDs: $HOST_UID $HOST_GID"
echo "SOURCES_REPO: $SRC_REPO"
echo "MANI_REPO: $MANI_REPO"
echo "MANI_BRANCH: $MANI_BRANCH" 
echo "MANI_XML: $MANI_XML"
echo "==================================================================="

# #set key environment variables
# export MANI_REPO="$MANI_REPO" 
# export MANI_BRANCH="$MANI_BRANCH" 
# export MANI_XML="$MANI_XML" 
export QCOM_ROOT_DIR="/home/dev/Qualcomm/${SRC_REPO}"

#VERIFY THAT FILES OWNERSHIP WAS CHANGED CORRECTLY
ls -la


#CREATE NETRC FILE
echo; echo "CREATING NETRC"
bash /home/dev/tools/build_netrc.sh

#PATCH AND SYNCHRONISE REPOS
tar -xf /home/dev/Qualcomm/patches.tar.gz -C /home/dev/Qualcomm/
# ls /Qualcomm/
echo; echo "PATCHING"
PATCHFILE="/home/dev/Qualcomm/patches/sync_snap_v2_remove_chipcode_copy.patch" 
TARGET="${QCOM_ROOT_DIR}/LE.PRODUCT.2.1.r1/apps_proc/sync_snap_v2.sh"
patch --batch "$TARGET" "$PATCHFILE" 

echo; echo "SYNCHRONISING REPOS"
# ~/build_scripts/sync_repos.sh -u $MANI_REPO -b $MANI_BRANCH -m $MANI_XML

# #configure kernel directories
# ~/build_scripts/setup_kernel.sh

# #apply IMDT patchs to QC source
# cd ${QCOM_ROOT_DIR}/LE.PRODUCT.2.1.r1/apps_proc
# ./imdt-patch-qcs8550-build.sh
