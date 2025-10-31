#!/usr/bin/env bash

cd "${QCOM_ROOT_DIR}/${QCS_RELEASE_TAG}/apps_proc"
pyenv global $PYENV
source poky/qti-conf/set_bb_env.sh
