#!/bin/bash
# (c) Selerity Pty. Ltd. 2021.  All Rights Reserved.
#
# This work is licensed under the Creative Commons Attribution-NonCommercial-NoDerivitives License. To view a copy 
# of the license, visit https://creativecommons.org/licenses/by-nc-nd/4.0/

SCRIPT_ROOT=$(dirname $0)
cd ${SCRIPT_ROOT}

# Check that docker is running
DOCKER_STATUS=$(docker version 2>&1 > /dev/null)
if [[ $? > 0 ]]; then
  echo "ERROR: A running docker client is required to use this software.  Please install or start your instance of Docker before proceeding."
  exit 1
fi

# Ensure that apro.settings file is present
if [[ -f apro.settings ]]; then
  source apro.settings

  if [[ -n "${1}" && ${1} == *"--batch"* ]]; then
    BATCH_MODE="true"
    SAS_RUN_HTTPD="false"
    $NAME=""
  else
    BATCH_MODE="false"
    SAS_RUN_HTTPD="true"
    NAME="sas-analytics-pro"
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

# Get latest license from sasinside directory
SASLICENSEFILE=$(basename $(ls -r sasinside/*.jwt 2>/dev/null | head -1) 2>/dev/null)
if [[ "x${SASLICENSEFILE}x" == "xx" ]]; then
  echo "ERROR: Could not locate SAS license file in sasinside directory"
  exit 1
fi
export SASLICENSEFILE

# Get latest certificate ZIP
SASCERTFILE=$(basename $(ls -r ./SASViyaV4_*_certs.zip 2>/dev/null | head -1) 2>/dev/null)
if [[ "x${SASCERTFILE}x" == "xx" ]]; then
  echo "ERROR: Could not locate SAS certificate file in current directory"
  exit 1
fi
# Check if Docker has previously authenticate to cr.sas.com
if ! grep -q cr.sas.com ~/.docker/config.json; then
  # Previous authentication not found, so we need to get login using mirrormgr
  echo "Previous login to the SAS Docker registry not found. Attempting to get login..."
  case "$(uname)" in
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
  eval $(./mirrormgr list remote docker login --deployment-data ${SASCERTFILE}) 2>&1 | grep -vi WARNING
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
CONTAINER=$(docker run -u root ${RUN_ARGS} "${IMAGE}:${IMAGE_VERSION}" "${@}")

# Check if there were any problems with the launch
if [[ $? > 0 ]]; then
  echo "ERROR: Something went wrong trying to launch SAS Analytics Pro. Please refer to the documentation."
  exit 1
fi

if [[ ${BATCH_MODE} == "true" ]]; then
  echo "############################################"
  echo "#    SAS Analytic Pro Personal Launcher    #"
  echo "#------------------------------------------#"
  echo "# Batch Mode                               #"
  echo "############################################"
  CONTAINER_NAME=$(docker inspect --format='{{.Name}}' ${CONTAINER})
  echo "Name: ${CONTAINER_NAME}"
else
  # Monitor SAS Analytics Pro as it starts up
  echo "############################################"
  echo "#    SAS Analytic Pro Personal Launcher    #"
  echo "#------------------------------------------#"
  echo "# S = SAS Studio has started               #"
  if [[ ${JUPYTERLAB} == "true" ]]; then
    echo "# J = Jupyter Lab has started              #"
  fi
  echo "############################################"
  echo -n "."
  TIMING="5 5 5 5 10 10 30 30 30 60"
  for _check in ${TIMING}; do
    sleep ${_check}
    APRO_PASSWORD=${APRO_PASSWORD:-$(docker logs $CONTAINER 2>&1 | grep ^Password=)}
    STUDIO_START=${STUDIO_START:-$(docker logs $CONTAINER 2>&1 | grep "service Root WebApplicationContext: initialization completed")}
    if [[ ${JUPYTERLAB} == "true" ]]; then
      JUPYTER_START=${JUPYTER_START:-$(docker logs $CONTAINER 2>&1 | grep "Jupyter Server ")}
    fi

    echo -n "."

    if [[ ! -z ${STUDIO_START} ]]; then
      # SAS Studio has started
      if [[ -z ${STUDIO_FLAG} ]]; then 
        echo -n "S"
        STUDIO_FLAG=1
      fi
      if [[ ${JUPYTERLAB} == "true" ]]; then
        if [[ ! -z ${JUPYTER_START} ]]; then
          # Jupyter Lab has started
          echo -e "J"
          break
        fi
      else
        break
      fi
    fi
  done

  if [[ -z ${STUDIO_START} ]]; then
    echo "WARNING: Cloud not detect startup of SAS Studio.  Please manually check status with \"docker logs sas-analytics-pro\""
    exit 1
  fi

  if [[ ! -z ${APRO_PASSWORD} ]]; then
    echo ${APRO_PASSWORD}
  fi

  echo -e "To stop your SAS Analytics Pro instance, use \"docker stop sas-analytics-pro\"\n"
fi