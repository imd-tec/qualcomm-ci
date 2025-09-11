#!/bin/bash
#Commands
echo "====================BITBAKE-BUILD COMMANDS========================="
echo "CONTAINER USER DETAILS"
echo "PWD: $(pwd)"
echo "IDs: $(id)"
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
    bash /home/dev/tools/new_user_setup_1.sh
    id
fi
# source /home/host/.bashrc


#Patch and Synchronise Repos
# tar -xf /Qualcomm/patches.tar.gz -C /Qualcomm/
# ls /Qualcomm/