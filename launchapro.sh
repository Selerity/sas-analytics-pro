#!/bin/bash
# (c) Selerity Pty. Ltd. 2021.  All Rights Reserved.
#
# This work is licensed under the Creative Commons Attribution-NonCommercial-NoDerivitives License. To view a copy 
# of the license, visit https://creativecommons.org/licenses/by-nc-nd/4.0/

echo "#############################################"
echo "#    SAS Analytics Pro Personal Launcher    #"
echo "#-------------------------------------------#"

# change to repo root directory
if ! cd "$(dirname "${0}")"; then
  echo "ERROR: Unable to change to root directory of repository."
  exit 1
fi

# determine host operating system
HOST_OS=$(uname|tr '[:lower:]' '[:upper:]')

# Check that docker is running
if ! docker version > /dev/null 2>&1; then
  echo "ERROR: A running docker client is required to use this software.  Please install or start your instance of Docker before proceeding."
  exit 1
fi

# Ensure that apro.settings file is present
if [[ -f apro.settings ]]; then
  source apro.settings

  if [[ -n "${1}" && ${1} == *"--batch"* ]]; then
    BATCH_MODE="true"
    SAS_RUN_HTTPD="false"
    NAME=""
    STUDIO=""
  else
    BATCH_MODE="false"
    SAS_RUN_HTTPD="true"
    STUDIO="--publish ${STUDIO_HTTP_PORT}:80"
    NAME="--name=sas-analytics-pro"
    if [[ "$(docker inspect --format='{{.State.Status}}' sas-analytics-pro 2>&1)" == "running" ]]; then
      echo "ERROR: SAS Analytics Pro is already running."
      exit 1
    fi
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
  echo "ERROR: apro.settings file not found."
  exit 1
fi

# Ensure that sasinside directory exists
if [[ ! -d sasinside ]]; then
  echo "ERROR: sasinside directory not found."
  exit 1
fi

# Ensure that data directory exists
if [[ ! -d data ]]; then
  echo "ERROR: data directory not found."
  exit 1
fi

# Get latest license file, then move to sasinside/
LINUX_LICENSEFILE=$(find ~+ -maxdepth 1 -type f -iname "SASViyaV4_*_license_*.jwt" -printf '%T@ %p\n' 2>/dev/null | sort -nr | awk 'NR<=1 {$1=""; print}')
DARWIN_LICENSEFILE=$(find ~+ -maxdepth 1 -type f -iname "SASViyaV4_*_license_*.jwt" -print0 | xargs -0 stat -f "%m %N" 2>/dev/null | sort -nr | awk 'NR<=1 {$1=""; print}')
LICENSEFILE="${HOST_OS}_LICENSEFILE"
# test that license file exists and we can copy it
if [[ -n "${!LICENSEFILE}" ]]; then
  if ! cp ${!LICENSEFILE} "sasinside/${!LICENSEFILE##*/}"; then
    echo "ERROR: Copying licence file failed."
    exit 1 
  fi
else
  echo "ERROR: Could not locate SAS license file."
  exit 1
fi

# set SAS License file variable after tests have been run
SASLICENSEFILE="${!LICENSEFILE##*/}"
export SASLICENSEFILE

# Get latest certificate ZIP
LINUX_CERTFILE=$(find ~+ -maxdepth 1 -type f -iname "SASViyaV4_*_certs.zip" -printf '%T@ %p\n' 2>/dev/null | sort -nr | awk 'NR<=1 {$1=""; sub(/^[ \t]+/, ""); print}')
DARWIN_CERTFILE=$(find ~+ -maxdepth 1 -type f -iname "SASViyaV4_*_certs.zip" -print0 | xargs -0 stat -f "%m %N" 2>/dev/null | sort -nr | awk 'NR<=1 {$1=""; sub(/^[ \t]+/, ""); print}')
SASCERTFILE="${HOST_OS}_CERTFILE"
if [[ -z "${!SASCERTFILE}" ]]; then
  echo "ERROR: Could not locate SAS certificate file."
  exit 1
fi

# Check if Docker has previously authenticate to cr.sas.com
if ! grep -q cr.sas.com ~/.docker/config.json; then
  # Previous authentication not found, so we need to get login using mirrormgr
  echo "Previous login to the SAS Docker registry not found. Attempting to get login..."
  case "${HOST_OS}" in
    "LINUX")  MIRRORURL="https://support.sas.com/installation/viya/4/sas-mirror-manager/lax/mirrormgr-linux.tgz" ;;
    "DARWIN") MIRRORURL="https://support.sas.com/installation/viya/4/sas-mirror-manager/mac/mirrormgr-osx.tgz" ;;
  esac
  
  # Download mirrormgr
  curl -s ${MIRRORURL} | tar xz mirrormgr
  
  # Log into the SAS docker registry
  eval "$(./mirrormgr list remote docker login --deployment-data "${!SASCERTFILE}") 2>&1 | grep -vi WARNING"
fi

# Add-Ons
ADDONS=""

# Jupyter Lab
if [[ "${JUPYTERLAB}" == "true" && "${BATCH_MODE}" == "false" ]]; then
  echo "# Add-on: JupyterLab Enabled                #"
  JUPYTERLAB_ARGS="--env POST_DEPLOY_SCRIPT=/sasinside/jupyterlab.sh --publish ${JUPYTERLAB_HTTP_PORT}:8888"
else
  JUPYTERLAB_ARGS=""
fi

# Clinical Standards Toolkit
if [[ "${CST}" == "true" ]]; then
  echo "# Add-on: CST Enabled                       #"
  # Check that required files can be found in SAS 9.4 Depot
  if [[ -f "${SAS94DEPOT}/${CSTMACROSGEN}" && 
        -f "${SAS94DEPOT}/${CSTGLOBALGEN}" && -f "${SAS94DEPOT}/${CSTGLOBALLAX}" && 
        -f "${SAS94DEPOT}/${CSTSAMPLEGEN}" && -f "${SAS94DEPOT}/${CSTSAMPLELAX}" ]]; then
    # Prepare CST files
    unzip -q -u "${SAS94DEPOT}/${CSTMACROSGEN}" -d ${PWD}/addons/${CSTBASE}
    unzip -q -u "${SAS94DEPOT}/${CSTGLOBALGEN}" -d ${PWD}/addons/${CSTGLOBAL}
    unzip -q -u "${SAS94DEPOT}/${CSTGLOBALLAX}" -d ${PWD}/addons/${CSTGLOBAL}
    unzip -q -u "${SAS94DEPOT}/${CSTSAMPLEGEN}" -d ${PWD}/addons/${CSTSAMPLE}
    unzip -q -u "${SAS94DEPOT}/${CSTSAMPLELAX}" -d ${PWD}/addons/${CSTSAMPLE}
    # Fix SAS Macro code
    sed -i '' 's/%sysevalf(&sysver)/&sysver/g' ${PWD}/addons/${CSTMACROS}/*

    CST_ARGS="--volume ${PWD}/addons/${CSTGLOBAL}:/data/cstGlobalLibrary --volume ${PWD}/addons/${CSTSAMPLE}:/data/cstSampleLibrary --volume ${PWD}/addons/${CSTMACROS}:/addons/cstautos"
    SASV9_OPTIONS="${SASV9_OPTIONS} -CSTGLOBALLIB=/data/cstGlobalLibrary -CSTSAMPLELIB=/data/cstSampleLibrary -insert sasautos \"/addons/cstautos\""
  else
    # Depot cannot be found, but check if we already have the required files extracted
    if [[ -f "${PWD}/addons/${CSTGLOBAL}/build/buildinfo.xml" && -f "${PWD}/addons/${CSTSAMPLE}/build/buildinfo.xml" && -d "${PWD}/addons/${CSTMACROS}" ]]; then
      CST_ARGS="--volume ${PWD}/addons/${CSTGLOBAL}:/data/cstGlobalLibrary --volume ${PWD}/addons/${CSTSAMPLE}:/data/cstSampleLibrary --volume ${PWD}/addons/${CSTMACROS}:/addons/cstautos"
      SASV9_OPTIONS="${SASV9_OPTIONS} -CSTGLOBALLIB=/data/cstGlobalLibrary -CSTSAMPLELIB=/data/cstSampleLibrary -insert sasautos \"/addons/cstautos\""
    else
      echo "ERROR: CST=true but required files from SAS 9.4 Depot cannot be found. SAS 9.4 Depot: ${SAS94DEPOT}"
      exit 1
    fi
  fi
else
  CST_ARGS=""
fi

# Collect Add-Ons
ADDONS="${JUPYTERLAB_ARGS}  ${CST_ARGS}"

# Create runtime arugments
RUN_ARGS="
${NAME}
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
${STUDIO}
--volume ${PWD}/sasinside:/sasinside
--volume ${PWD}/data:/data
--volume ${PWD}/addons/python:/python
${ADDONS}"

# Run Analytics Pro container with supplied arguments
CONTAINER=$(docker run -u root ${RUN_ARGS} "${IMAGE}:${IMAGE_VERSION}" "${@}")

# Check if there were any problems with the launch
if [[ $? > 0 ]]; then
  echo "ERROR: Something went wrong trying to launch SAS Analytics Pro. Please refer to the documentation."
  exit 1
fi

if [[ ${BATCH_MODE} == "true" ]]; then
  echo "# Batch Mode                                #"
  echo "#############################################"
  CONTAINER_NAME=$(docker inspect --format='{{.Name}}' ${CONTAINER})
  echo "Name: ${CONTAINER_NAME}"
else
  # Monitor SAS Analytics Pro as it starts up
  echo "# S = SAS Studio has started                #"
  if [[ ${JUPYTERLAB} == "true" ]]; then
    echo "# J = Jupyter Lab has started               #"
  fi
  echo "#############################################"
  echo -n "."
  TIMING="5 5 5 5 10 10 30 30 30 60"
  for _check in ${TIMING}; do
    sleep ${_check}
    DOCKER_LOGS="$(docker logs "${CONTAINER}" 2>&1)"
    APRO_PASSWORD=${APRO_PASSWORD:-$(grep ^Password= <<< "${DOCKER_LOGS}")}
    STUDIO_START=${STUDIO_START:-$(grep "service Root WebApplicationContext: initialization completed" <<< "${DOCKER_LOGS}")}
    if [[ ${JUPYTERLAB} == "true" ]]; then
      JUPYTER_START=${JUPYTER_START:-$(grep "Jupyter Server " <<< "${DOCKER_LOGS}")}
    fi

    echo -n "."

    if [[ -n ${STUDIO_START} ]]; then
      # SAS Studio has started
      if [[ -z ${STUDIO_FLAG} ]]; then 
        echo -n "S"
        STUDIO_FLAG=1
      fi
      if [[ ${JUPYTERLAB} == "true" ]]; then
        if [[ -n ${JUPYTER_START} ]]; then
          # Jupyter Lab has started
          echo -n "J"
          break
        fi
      else
        break
      fi
    fi
  done

  if [[ -z ${STUDIO_START} ]]; then
    echo "WARNING: Could not detect startup of SAS Studio.  Please manually check status with \"docker logs sas-analytics-pro\""
    exit 1
  fi

  echo -e "\n#############################################"

  echo "Browser Access: http://localhost:${STUDIO_HTTP_PORT}"
  echo "User ID=${SAS_DEMO_USER}"

  if [[ -n ${APRO_PASSWORD} ]]; then
    echo -e "${APRO_PASSWORD}\n"
  fi

  echo -e "To stop your SAS Analytics Pro instance, use \"docker stop sas-analytics-pro\"\n"
fi