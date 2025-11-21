#!/usr/bin/env bash
#=============================================================================================================================================================================
#title: setup_cache.sh
#description: Sets up shared download and sstate cache directories inside the container for development builds.
#=============================================================================================================================================================================

if [ "${BUILD_VERSION}" = "development" ]; then
  export BB_ENV_PASSTHROUGH_ADDITIONS="DL_DIR SSTATE_DIR"
  export DL_DIR="/home/dev/downloads"
  export SSTATE_DIR="/home/dev/sstate-cache"
  echo "Using shared caches (DL_DIR=$DL_DIR, SSTATE_DIR=$SSTATE_DIR)"

fi