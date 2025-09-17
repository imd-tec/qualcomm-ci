#!/bin/bash
#Commands
set -euo pipefail -x

echo " "
echo "====================BITBAKE-BUILD COMMANDS========================="
echo "DETAILS"
echo "CONTAINER PWD: $(pwd)"
echo "CONTAINER USER IDs: $(id)"
echo "HOST IDs: $HOST_UID $HOST_GID"
echo "SOURCES_REPO: $SRC_REPO"
echo "MANI_REPO: $MANI_REPO"
echo "MANI_BRANCH: $MANI_BRANCH" 
echo "MANI_XML: $MANI_XML"
echo "==================================================================="

#set key environment variables
export MANI_REPO="$MANI_REPO" 
export MANI_BRANCH="$MANI_BRANCH" 
export MANI_XML="$MANI_XML" 
export QCOM_ROOT_DIR="/Qualcomm/${SRC_REPO}"

ls /Qualcomm/
ls /home/dev/
ls /home/dev/tools/


#execute user creation scripts to avoid mismatches with host and container IDs
sudo env HOST_UID="$HOST_UID" HOST_GID="$HOST_GID" bash /home/dev/tools/user_setup_1.sh
# sudo cat /etc/sudoers
# sudo getent group
sudo -u host -i bash /home/dev/tools/user_setup_2.sh


sudo --preserve-env=MANI_REPO,MANI_BRANCH,MANI_XML,QCOM_ROOT_DIR -u host -i bash -l <<'HOST_SHELL'
set -euo pipefail -x

whoami
source /home/host/.bashrc
echo
cat ~/.bashrc
echo 

#CREATE NETRC FILE
echo; echo "CREATING NETRC"
/home/host/tools/build_netrc.sh

#ENV VARIABLES
echo; echo "ENVIRONMENT VARIABLES
echo $QCOM_ROOT_DIR
echo $MANI_REPO
echo $MANI_BRANCH
echo $MANI_XML



#PATCH AND SYNCHRONISE REPOS
tar -xf /Qualcomm/patches.tar.gz -C /Qualcomm/
# ls /Qualcomm/

echo; echo "PATCHING"
PATCHFILE="/Qualcomm/patches/sync_snap_v2_remove_chipcode_copy.patch" 
TARGET="${QCOM_ROOT_DIR}/LE.PRODUCT.2.1.r1/apps_proc/sync_snap_v2.sh"
patch --batch "$TARGET" "$PATCHFILE" 

echo; echo "SYNCHRONISING REPOS"
~/build_scripts/sync_repos.sh -u $MANI_REPO -b $MANI_BRANCH -m $MANI_XML

# #configure kernel directories
# ~/build_scripts/setup_kernel.sh

# #apply IMDT patchs to QC source
# cd ${QCOM_ROOT_DIR}/LE.PRODUCT.2.1.r1/apps_proc
# ./imdt-patch-qcs8550-build.sh

HOST_SHELL
