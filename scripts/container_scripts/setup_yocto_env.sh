#!/bin/bash
#=============================================================================================================================================================================
#title: setup_yocto_env.sh
#description:   sets up yocto build environment
#               Additionally sets up shared download and sstate cache directories inside the container for development builds.
#=============================================================================================================================================================================

if [ "${BUILD_VERSION}" = "development" ]; then
    echo "Setting up shared caches for development build..."
    export BB_ENV_PASSTHROUGH_ADDITIONS="DL_DIR SSTATE_DIR"
    export DL_DIR="/home/dev/downloads"
    export SSTATE_DIR="/home/dev/sstate-cache"
    echo "Using shared caches (DL_DIR=$DL_DIR, SSTATE_DIR=$SSTATE_DIR)"

fi
echo "Setting up Yocto build environment..."
cd "${QCOM_ROOT_DIR}/LE.PRODUCT.2.1.r1/apps_proc" || exit 1
pyenv global "$PYENV"
export MACHINE=$MACHINE
export DISTRO=$DISTRO
source poky/qti-conf/set_bb_env.sh
echo "Yocto environment setup completed"

