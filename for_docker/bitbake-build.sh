#!/bin/bash
#Commands
echo "====================BITBAKE-BUILD COMMANDS========================="
echo "DETAILS"
echo "CONTAINER PWD: $(pwd)"
echo "CONTAINER USER IDs: $(id)"
echo "Who: $(whoami)"
echo "HOST IDs: $HOST_UID $HOST_GID"
echo $"MANI_REPO: $MANI_REPO\n MANI_BRANCH: $MANI_BRANCH\n MANI_XML: $MANI_XML"
echo "==================================================================="

set -euo pipefail -x
ls /Qualcomm
ls /home/dev/
ls /home/dev/tools/
export QCOM_ROOT_DIR=/Qualcomm/qcs8550-le-1-0_amss_standard_oem_apqgps
/home/dev/tools/build_netrc.sh

# cat /home/dev/.netrc

#Create new user with matching IDs if ID does not match host
# if [ "$HOST_UID" != $(id -u) ] || [ "$HOST_GID" != $(id -g) ]; then
# echo "Host and container user IDs do not match. Executing user initialization scripts."
id
sudo env HOST_UID="$HOST_UID" HOST_GID="$HOST_GID" bash -lc 'bash /home/dev/tools/new_user_setup_1.sh'
# sudo cat /etc/sudoers
# sudo getent group
sudo bash /home/dev/tools/new_user_setup_2.sh
source /home/host/.bashrc

# fi

sudo -u host -i bash -l <<'HOST_SHELL'
set -euo pipefail
id
ls -a
pwd

#Patch and Synchronise Repos
tar -xf /Qualcomm/patches.tar.gz -C /Qualcomm/
ls /Qualcomm/ 
patch ${QCOM_ROOT_DIR}/LE.PRODUCT.2.1.r1/apps_proc/sync_snap_v2.sh \ ~/Qualcomm/patches/sync_snap_v2_remove_chipcode_copy.patch
~/build_scripts/sync_repos.sh -u $MANI_REPO -b $MANI_BRANCH -m $MANI_XML
HOST_SHELL
