#!/bin/bash
#Commands
set -euo pipefail

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

#build netrc file

# cat /home/dev/.netrc

#Create new user with matching IDs if ID does not match host
# if [ "$HOST_UID" != $(id -u) ] || [ "$HOST_GID" != $(id -g) ]; then
# echo "Host and container user IDs do not match. Executing user initialization scripts."
id
sudo env HOST_UID="$HOST_UID" HOST_GID="$HOST_GID" bash -lc 'bash /home/dev/tools/user_setup_1.sh'
# sudo cat /etc/sudoers
# sudo getent group
sudo /home/dev/tools/bash user_setup_2.sh
# fi

sudo --preserve-env=MANI_REPO,MANI_BRANCH,MANI_XML,QCOM_ROOT_DIR -u host -i bash -l \
 <<'HOST_SHELL'
set -euo pipefail -x
source /home/host/.bashrc
/home/host/tools/build_netrc.sh
# id
# ls -a
# pwd
# sudo cat ~/.netrc

echo $QCOM_ROOT_DIR
echo $MANI_REPO
echo $MANI_BRANCH
echo $MANI_XML

#PATCH AND SYNCHRONISE REPOS
tar -xf /Qualcomm/patches.tar.gz -C /Qualcomm/
# ls /Qualcomm/

echo "PATCHING"
PATCHFILE="/Qualcomm/patches/sync_snap_v2_remove_chipcode_copy.patch"
TARGET="${QCOM_ROOT_DIR}/LE.PRODUCT.2.1.r1/apps_proc/sync_snap_v2.sh"
patch --batch "$TARGET" "$PATCHFILE" 

echo "SYNCHRONISING REPOS"
~/build_scripts/sync_repos.sh -u $MANI_REPO -b $MANI_BRANCH -m $MANI_XML

# #configure kernel directories
# ~/build_scripts/setup_kernel.sh

# #apply IMDT patchs to QC source
# cd ${QCOM_ROOT_DIR}/LE.PRODUCT.2.1.r1/apps_proc
# ./imdt-patch-qcs8550-build.sh

HOST_SHELL
