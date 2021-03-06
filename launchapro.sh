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

  if [[ -n "${1}" && ${1} == "--batch" ]]; then
    ARGS="${@}"
    BATCH_MODE="true"
    SAS_RUN_HTTPD="false"
    NAME=""
    STUDIO=""
    SASOQ="false"
  elif [[ -n "${1}" && ${1} == "--sasoq" ]]; then
    if [[ "${2}" == "" ]]; then
      echo "ERROR: When SAS OQ is enabled you must specify test paramters."
      exit 1
    fi
    SASOQ="true"
    ARGS="${2}"
    PERL="true"
    BATCH_MODE="true"
    SAS_RUN_HTTPD="false"
    NAME=""
    STUDIO=""    
  else
    ARGS="${@}"
    SASOQ="false"
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
  export PRE_DEPLOY_SCRIPT
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
  # Check if we already have the required files extracted
  if [[ -f "${PWD}/addons/${CSTGLOBAL}/build/buildinfo.xml" && -f "${PWD}/addons/${CSTSAMPLE}/build/buildinfo.xml" && -d "${PWD}/addons/${CSTMACROS}" ]]; then
    CST_ARGS="--volume ${PWD}/addons/${CSTGLOBAL}:/data/cstGlobalLibrary --volume ${PWD}/addons/${CSTSAMPLE}:/data/cstSampleLibrary --volume ${PWD}/addons/${CSTMACROS}:/addons/cstautos"
    SASV9_OPTIONS="${SASV9_OPTIONS} -CSTGLOBALLIB=/data/cstGlobalLibrary -CSTSAMPLELIB=/data/cstSampleLibrary -insert sasautos \"/addons/cstautos\" -set CLASSPATH=/addons/cstautos/sas.cdisc.transforms.jar"
  else
    # Check if we can download the CST
    curl -Ifs ${CSTHF} > /dev/null
    if [ $? == 0 ]; then
      CSTDL=$(mktemp)
      echo "# Add-on: CST being downloaded from SAS     #"
      curl ${CSTHF} -o ${CSTDL}
      unzip -q -u ${CSTDL} -d ${PWD}/addons/${CSTBASE}/source
      rm -f ${CSTDL}
      # Prepare CST files
      unzip -q -u "${PWD}/addons/${CSTBASE}/source/products/cstframework__Z46002__lax__en__sp0__1/en_sasautos.zip" -d ${PWD}/addons/${CSTBASE}
      unzip -q -u "${PWD}/addons/${CSTBASE}/source/products/cstgblstdlib__Z48002__prt__xx__sp0__1/cstgblstdlib_gen.zip" -d ${PWD}/addons/${CSTGLOBAL}
      unzip -q -u "${PWD}/addons/${CSTBASE}/source/products/cstgblstdlib__Z48002__prt__xx__sp0__1/native_lax.zip" -d ${PWD}/addons/${CSTGLOBAL}
      unzip -q -u "${PWD}/addons/${CSTBASE}/source/products/cstsamplelib__Z49002__prt__xx__sp0__1/cstsamplelib_gen.zip" -d ${PWD}/addons/${CSTSAMPLE}
      unzip -q -u "${PWD}/addons/${CSTBASE}/source/products/cstsamplelib__Z49002__prt__xx__sp0__1/native_lax.zip" -d ${PWD}/addons/${CSTSAMPLE}
      unzip -q -u -j "${PWD}/addons/${CSTBASE}/source/products/cstfrmwrkjar__Z47002__prt__xx__sp0__1/cstfrmwrkjar_vjr.zip" eclipse/plugins/sas.cdisc.transforms_107000.0.0.20160913165121_f0cltk17/sas.cdisc.transforms.jar -d ${PWD}/addons/${CSTMACROS}
      rm -Rf "${PWD}/addons/${CSTBASE}/source"
      # Fix SAS Macro code
      sed -i '' 's/%sysevalf(&sysver)/\&sysver/g' ${PWD}/addons/${CSTMACROS}/cstutilgetattribute.sas
      sed -i '' 's/%sysevalf(&sysver)/\&sysver/g' ${PWD}/addons/${CSTMACROS}/cstutilwriteresultsintro.sas
      find ${PWD}/addons/${CSTBASE} -name "*.sas" -exec sed -i '' 's/\/ picklist="&_cstJavaPicklist"//g' {} \;

      CST_ARGS="--volume ${PWD}/addons/${CSTGLOBAL}:/data/cstGlobalLibrary --volume ${PWD}/addons/${CSTSAMPLE}:/data/cstSampleLibrary --volume ${PWD}/addons/${CSTMACROS}:/addons/cstautos"
      SASV9_OPTIONS="${SASV9_OPTIONS} -CSTGLOBALLIB=/data/cstGlobalLibrary -CSTSAMPLELIB=/data/cstSampleLibrary -insert sasautos \"/addons/cstautos\" -set CLASSPATH=/addons/cstautos/sas.cdisc.transforms.jar"
      echo "# Add-on: CST prepared                      #"
    else
      echo "ERROR: CST=true but required files are not available from SAS for download."
      exit 1
    fi
  fi
else
  CST_ARGS=""
fi

# Perl for SAS
if [[ "${PERL}" == "true" ]]; then
  echo "# Add-on: Perl Enabled                      #"
  # Check if we already have the required files extracted
  if [[ -f "${PWD}/addons/perl/bin/perl5" ]]; then
    PERL_ARGS="--volume ${PWD}/addons/perl:/opt/sas/viya/home/SASFoundation/perl"
    PERL_PREDEPLOY="chmod 755 /opt/sas/viya/home/SASFoundation/perl/bin/*"
  else
    # Check if we can download Perl for SAS
    curl -Ifs ${PERLFORSAS} > /dev/null
    if [ $? == 0 ]; then
      P4SDL=$(mktemp)
      echo "# Add-on: Perl for SAS being downloaded     #"
      curl ${PERLFORSAS} -o ${P4SDL}
      unzip -q -u ${P4SDL} -d ${PWD}/addons/perl
      rm -f ${P4SDL}
      PERL_ARGS="--volume ${PWD}/addons/perl:/opt/sas/viya/home/SASFoundation/perl"
      PERL_PREDEPLOY="chmod 755 /opt/sas/viya/home/SASFoundation/perl/bin/*"
      echo "# Add-on: Perl prepared                     #"
    else
      echo "ERROR: PERL=true but required files cannot be downloaded."
      exit 1
    fi
  fi
else
  PERL_ARGS=""
fi

# SAS Operational Qualification
if [[ "${SASOQ}" == "true" ]]; then
  echo "# SAS OQ Mode                               #"
  ENTRYPOINT="--entrypoint /addons/sasoq/sasoq.sh"
  SASOQ_ARGS="--volume ${PWD}/addons/sasoq:/addons/sasoq"
else
  ENTRYPOINT=""
fi

# Collect Add-Ons
ADDONS="${JUPYTERLAB_ARGS}  ${CST_ARGS} ${PERL_ARGS} ${SASOQ_ARGS}"

# Collect Pre Deploy Commands
PRE_DEPLOY_SCRIPT="echo $(date);${PRE_DEPLOY_SCRIPT}
${PERL_PREDEPLOY}"

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
--env PRE_DEPLOY_SCRIPT
${STUDIO}
--volume ${PWD}/sasinside:/sasinside
--volume ${PWD}/data:/data
--volume ${PWD}/addons/python:/python
${ADDONS}"

# Run Analytics Pro container with supplied arguments
CONTAINER=$(docker run ${ENTRYPOINT} -u root ${RUN_ARGS} "${IMAGE}:${IMAGE_VERSION}" ${ARGS})

# Check if there were any problems with the launch
if [[ $? > 0 ]]; then
  echo "ERROR: Something went wrong trying to launch SAS Analytics Pro. Please refer to the documentation."
  exit 1
fi

if [[ ${SASOQ} == "true" ]]; then
  echo "# Streaming OQ Logs                         #"
  echo "#############################################"
  CONTAINER_NAME=$(docker inspect --format='{{.Name}}' ${CONTAINER})
  echo "Name: ${CONTAINER_NAME}"
  docker logs ${CONTAINER_NAME} -f
elif [[ ${BATCH_MODE} == "true" ]]; then
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
  if [[ ${JUPYTERLAB} == "true" ]]; then
    echo "JupyterLab: http://localhost:${JUPYTERLAB_HTTP_PORT}"
  fi
  echo "User ID=${SAS_DEMO_USER}"

  if [[ -n ${APRO_PASSWORD} ]]; then
    echo -e "${APRO_PASSWORD}\n"
  fi

  echo -e "To stop your SAS Analytics Pro instance, use \"docker stop sas-analytics-pro\"\n"
fi