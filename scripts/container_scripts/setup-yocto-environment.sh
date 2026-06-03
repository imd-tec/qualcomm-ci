#!/bin/bash
#=============================================================================================================================================================================
#title: setup-yocto-environment.sh
#description:   sets up yocto build environment
#               Additionally sets up shared download and sstate cache directories inside the container for development builds.
#=============================================================================================================================================================================

echo "Setting up Yocto build environment..."
cd "${QCOM_ROOT_DIR}/LE.PRODUCT.2.1.r1/apps_proc" || { echo "ERROR: Failed to change directory to ${QCOM_ROOT_DIR}/LE.PRODUCT.2.1.r1/apps_proc"; exit 1; }
pyenv global "$PYENV"
export MACHINE=$MACHINE
export DISTRO=$DISTRO
source poky/qti-conf/set_bb_env.sh

# if build version is development, override config cache directories 
if [ "${BUILD_VERSION}" = "development" ]; then
    echo "Appending CI cache paths to conf/auto.conf..."    
cat >> conf/auto.conf <<EOF
DL_DIR = "/home/dev/downloads"
SSTATE_DIR = "/home/dev/sstate-cache"
EOF
fi

echo "Yocto environment setup completed"
