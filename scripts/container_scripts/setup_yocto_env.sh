#!/bin/bash
#=============================================================================================================================================================================
#title: create-docker-build-env.sh
#description: sets up yocto build environment
#=============================================================================================================================================================================

cd "${QCOM_ROOT_DIR}/LE.PRODUCT.2.1.r1/apps_proc" || exit 1
pyenv global "$PYENV"
export MACHINE=$MACHINE
export DISTRO=$DISTRO
source poky/qti-conf/set_bb_env.sh
echo "Yocto environment setup completed"

