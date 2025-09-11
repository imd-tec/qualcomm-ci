#!/bin/bash
set -euo pipefail -x

#Commands
echo "====================BITBAKE-BUILD COMMANDS========================="
pwd
id
ls /Qualcomm
ls /home/dev/
export QCOM_ROOT_DIR=/Qualcomm/qcs8550-le-1-0_amss_standard_oem_apqgps
echo $QCOM_ROOT_DIR
/home/dev/build_netrc.sh
# cat /home/dev/.netrc

#Initialize user if UID/GID == 1000
if [ "$HOST_UID" != $(id -u) || "$HOST_GID" != $(id -g) ]; then
    echo "Host and container user IDs do not match. Executing user initialization scripts."
fi
# source /home/host/.bashrc

#Synchronise Repos
# tar -xf /Qualcomm/patches.tar.gz -C /Qualcomm/
# ls /Qualcomm/