#!/bin/bash
#Commands
echo "====================BITBAKE-BUILD COMMANDS========================="
echo "DETAILS"
echo "CONTAINER PWD: $(pwd)"
echo "CONTAINER USER IDs: $(id)"
echo "Who: $(who)"
echo "HOST IDs: $HOST_UID $HOST_GID"
echo "==================================================================="

set -euo pipefail -x
ls /Qualcomm
ls /home/dev/
ls /home/dev/tools/
export QCOM_ROOT_DIR=/Qualcomm/qcs8550-le-1-0_amss_standard_oem_apqgps
/home/dev/tools/build_netrc.sh

# cat /home/dev/.netrc

#Initialize user if UID/GID == 1000
if [ "$HOST_UID" != $(id -u) ] || [ "$HOST_GID" != $(id -g) ]; then
    echo "Host and container user IDs do not match. Executing user initialization scripts."
    id
    # sudo bash /home/dev/tools/new_user_setup_1.sh
    sudo env HOST_UID="$HOST_UID" HOST_GID="$HOST_GID" bash -lc 'bash /home/dev/tools/new_user_setup_1.sh'
    # sudo cat /etc/sudoers
    # sudo getent group
fi
source /home/host/.bashrc
id



#Patch and Synchronise Repos
# tar -xf /Qualcomm/patches.tar.gz -C /Qualcomm/
# ls /Qualcomm/ 