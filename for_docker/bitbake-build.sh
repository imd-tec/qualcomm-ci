#!/bin/bash
#Commands
set -euo pipefail

echo "====================BITBAKE-BUILD COMMANDS========================="
echo "DETAILS"
echo "CONTAINER PWD: $(pwd)"
echo "CONTAINER USER IDs: $(id)"
echo "SOURCES_REPO: $SRC_REPO"
echo "MANI_REPO: $MANI_REPO"
echo "MANI_BRANCH: $MANI_BRANCH" 
echo "MANI_XML: $MANI_XML"

export QCOM_ROOT_DIR="/home/dev/Qualcomm/${SRC_REPO}"

#VERIFY THAT FILES OWNERSHIP WAS CHANGED CORRECTLY
ls -la

#CREATE NETRC FILE
echo "CREATING NETRC"
bash /home/dev/tools/build_netrc.sh

#PATCH AND SYNCHRONISE REPOS
tar -xf /home/dev/Qualcomm/patches.tar.gz -C /home/dev/Qualcomm/
echo "PATCHING"
PATCHFILE="/home/dev/Qualcomm/patches/sync_snap_v2_remove_chipcode_copy.patch" 
TARGET="${QCOM_ROOT_DIR}/LE.PRODUCT.2.1.r1/apps_proc/sync_snap_v2.sh"
patch --batch "$TARGET" "$PATCHFILE" 

echo "=============================SYNCHRONISING REPOS============================="
bash -x /home/dev/build_scripts/sync_repos.sh -u $MANI_REPO -b $MANI_BRANCH -m $MANI_XML

#CONFIGURE KERNEL DIRECTORIES
echo "CONFIGURING KERNEL DIRECTORIES"
bash -x /home/dev/build_scripts/setup_kernel.sh

#APPLYING IMDT PATCHES TO QC SOURCE
echo "APPLYING IMDT PATCHES TO QC SOURCE"
cd ${QCOM_ROOT_DIR}/LE.PRODUCT.2.1.r1/apps_proc
bash -x ./imdt-patch-qcs8550-build.sh

#BUILD KERNEL
echo "=============================BUILDING KERNEL================================="
bash -x /home/dev/build_scripts/build_kernel.sh --lto "thin" --jobs 8

#BUILD HLOS
echo "=============================BUILDING HLOS=================================="

#patch bitbake recipe
cd ${QCOM_ROOT_DIR}/LE.PRODUCT.2.1.r1/apps_proc/poky
patch ./meta-qti-bsp/classes/populate_sdk_qti.bbclass \
 ${HOME}/Qualcomm/patches/populate_sdk_qti_remove_llvm_native.patch

#copy extra files from latest release
cp -rn ${QCOM_ROOT_DIR}/LE.FRAMEWORK.2.0.r1/apps_proc/poky/* ${QCOM_ROOT_DIR}/LE.PRODUCT.2.1.r1/apps_proc/poky/
cp -rn ${QCOM_ROOT_DIR}/LE.FRAMEWORK.2.0.r1/apps_proc/src/* ${QCOM_ROOT_DIR}/LE.PRODUCT.2.1.r1/apps_proc/src/

#setup Yocto env
cd ${QCOM_ROOT_DIR}/LE.PRODUCT.2.1.r1/apps_proc
pyenv global 3.8.16
export MACHINE=imdt-qcs8550-sbc
export DISTRO=imdt-qcom-distro-debug 
source poky/qti-conf/set_bb_env.sh

#BUILD IMAGE
echo "=============================BUILDING IMAGE=================================="
bitbake -k imdt-image-weston --runall=fetch
bitbake -k imdt-image-weston

#SDK? 

#BUILD NON-HLOS COMPONENTS
echo "=============================BUILDING NON-HLOS==============================="
bash -x /home/build_scripts/build_non_hlos.sh --build all 

#CDT?