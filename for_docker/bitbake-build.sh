#!/bin/bash
set -euo pipefail -x

#Commands
echo "====================BITBAKE-BUILD COMMANDS========================="
echo "USER DETAILS"
echo "PWD: $(pwd)"
echo "IDs: $(id)"
echo "==================================================================="
ls /Qualcomm
ls /home/dev/
ls /home/dev/tools/
export QCOM_ROOT_DIR=/Qualcomm/qcs8550-le-1-0_amss_standard_oem_apqgps
/home/dev/tools/build_netrc.sh
# cat /home/dev/.netrc

#Initialize user if UID/GID == 1000
if [ "$HOST_UID" != $(id -u) ] || [ "$HOST_GID" != $(id -g) ]; then
    echo "Host and container user IDs do not match. Executing user initialization scripts."
    
fi
# source /home/host/.bashrc


#Patch and Synchronise Repos
# tar -xf /Qualcomm/patches.tar.gz -C /Qualcomm/
# ls /Qualcomm/