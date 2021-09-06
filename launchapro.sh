#!/bin/bash
# (c) Selerity Pty. Ltd. 2021.  All Rights Reserved.
#
# This work is licensed under the Creative Commons Attribution-NonCommercial-NoDerivitives License. To view a copy 
# of the license, visit https://creativecommons.org/licenses/by-nc-nd/4.0/

SCRIPT_ROOT=$(dirname $0)
cd ${SCRIPT_ROOT}

# determine host operating system
HOST_OS=$(uname)

# Ensure that apro.settings file is present
if [[ -f apro.settings ]]; then
  source apro.settings

  if [[ -n "${1}" && ${1} == *"--batch"* ]]; then
    SAS_RUN_HTTPD="false"
  else
    SAS_RUN_HTTPD="true"
  fi

  if [[ -z "${RUN_MODE}" ]]; then
    RUN_MODE="developer"
  fi
  export SAS_RUN_HTTPD
  export STUDIO_HTTP_PORT
  export RUN_MODE
  export SASLICENSEFILE
  export SAS_DEBUG
  export SAS_DEMO_USER
  export SASLOCKDOWN
  export SASV9_OPTIONS
else
  echo "ERROR: apro.settings file not found"
  exit 1
fi

# Ensure that sasinside directory exists
if [[ ! -d sasinside ]]; then
  echo "ERROR: sasinside directory not found"
  exit 1
fi

# Ensure that data directory exists
if [[ ! -d data ]]; then
  echo "ERROR: data directory not found"
  exit 1
fi

# Get latest license file, then move to sasinside/
LINUX_LICENSEFILE=$(find ~+ -maxdepth 1 -type f -iname "SASViya4_*_license_*.jwt" -printf '%T@ %p\n' 2>/dev/null | sort -nr | awk 'NR<=1 {$1=""; print}')
DARWIN_LICENSEFILE=$(find ~+ -maxdepth 1 -type f -iname "SASViya4_*_license_*.jwt" -print0 | xargs -0 stat -f "%m %N" 2>/dev/null | sort -nr | awk 'NR<=1 {$1=""; print}')
LICENSEFILE="${HOST_OS^^}_LICENSEFILE"
if [[ -n "${!LICENSEFILE}" ]]; then
  cp "${!LICENSEFILE}" "sasinside/${!LICENSEFILE##*/}"
  SASLICENSEFILE="${!LICENSEFILE##*/}"
else
  echo "ERROR: Could not locate SAS license file"
  exit 1
fi

export SASLICENSEFILE

# Get latest certificate ZIP
LINUX_CERTFILE=$(find ~+ -maxdepth 1 -type f -iname "SASViyaV4_*_certs.zip" -printf '%T@ %p\n' 2>/dev/null | sort -nr | awk 'NR<=1 {$1=""; print}')
DARWIN_CERTFILE=$(find ~+ -maxdepth 1 -type f -iname "SASViyaV4_*_certs.zip" -print0 | xargs -0 stat -f "%m %N" 2>/dev/null | sort -nr | awk 'NR<=1 {$1=""; print}')
SASCERTFILE="${HOST_OS^^}_CERTFILE"
if [[ -z "${!SASCERTFILE}" ]]; then
  echo "ERROR: Could not locate SAS certificate file"
  exit 1
fi

# Check if Docker has previously authenticate to cr.sas.com
if ! grep -q cr.sas.com ~/.docker/config.json; then
  # Previous authentication not found, so we need to get login using mirrormgr
  echo "Previous login to the SAS Docker registry not found. Attempting to get login..."
  case "${HOST_OS}" in
    "Linux")
      MIRRORURL="https://support.sas.com/installation/viya/4/sas-mirror-manager/lax/mirrormgr-linux.tgz"
      ;;
    "Darwin")
      MIRRORURL="https://support.sas.com/installation/viya/4/sas-mirror-manager/mac/mirrormgr-osx.tgz"
      ;;
  esac
  # Download mirrormgr
  curl -s ${MIRRORURL} | tar xz mirrormgr
  # Log into the SAS docker registry
  eval $(./mirrormgr list remote docker login --deployment-data ${!SASCERTFILE}) 2>&1 | grep -vi WARNING
fi

# Jupyter Lab
if [[ ${JUPYTERLAB} == "true" ]]; then
  JUPYTERLAB_ARGS="--env POST_DEPLOY_SCRIPT=/sasinside/jupyterlab.sh --publish ${JUPYTERLAB_HTTP_PORT}:8888"
else
  JUPYTERLAB_ARGS=""
fi

# Create runtime arugments
RUN_ARGS="
--name=sas-analytics-pro
--rm
--detach
--hostname sas-analytics-pro
--env SAS_RUN_HTTPD
--env STUDIO_HTTP_PORT
--env RUN_MODE
--env SASLICENSEFILE
--env SAS_DEBUG
--env SAS_DEMO_USER
--env SASLOCKDOWN
--env SASV9_OPTIONS
--publish ${STUDIO_HTTP_PORT}:80
--volume ${PWD}/sasinside:/sasinside
--volume ${PWD}/python:/python
--volume ${PWD}/data:/data
${JUPYTERLAB_ARGS}"

# Run Analytics Pro container with supplied arguments
docker run -u root ${RUN_ARGS} "${IMAGE}:${IMAGE_VERSION}" "${@}"
