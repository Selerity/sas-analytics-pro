#!/bin/bash

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

# Get latest license from sasinside directory
SASLICENSEFILE=$(basename $(ls -r sasinside/*.jwt 2>/dev/null | head -1) 2>/dev/null)
if [[ "x${SASLICENSEFILE}x" == "xx" ]]; then
  echo "ERROR: Could not locate SAS license file in sasinside directory"
  exit 1
fi

export SASLICENSEFILE

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
--volume ${PWD}/data:/data"

# Run Analytics Pro container with supplied arguments
docker run -u root "${RUN_ARGS}" "${IMAGE}:${IMAGE_VERSION}" "${@}"
