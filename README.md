# SAS Analytics Pro (Cloud-Native)
## Overview
This repo contains info and scripts you help get you up and running with the new Cloud-Native (containerised) version of SAS Analytics Pro from the SAS Institute.  The first release of this software is version 2021.1.4 (August 2021).

This repo should be used in conjunction with the official [SAS Analytics Pro Deployment Guide](https://go.documentation.sas.com/doc/en/anprocdc/default/anprowlcm/home.htm).  The intention of this repo is to make a few things for the less technical user a bit easier to get up and running.

## Pre-requisites
* [Docker Desktop](https://www.docker.com/products/docker-desktop)
* [SAS Mirror Manager](https://support.sas.com/en/documentation/install-center/viya/deployment-tools/4/mirror-manager.html)
* Your Certificate (`*-certs.zip`) file from the `My Orders` section of my.sas.com
* Your License (`*.jwt`) from the `My Orders` section of my.sas.com
* Clone of this repo. The root of this repo is the `$deploy` directory mentioned in the SAS Deployment Guide.
* Instructions below assume you have a command prompt/terminal open and have changed directory into the top level of this repo.


## Docker Desktop on Linux
1. Follow Step 1 in the `Docker on Linux` section of the official Deployment Guide to make sure that you have the following three files in the top level directory:
   * _SAS-certificates-file-name_.zip
   * _SAS-license-file-name_.jwt
   * `mirrormgr`
2. Run the following command to log into the SAS Container Registry (this equates to Step 2 of the Deployment Guide):
```
eval $(./mirrormgr list remote docker login --deployment-data SAS-certificates-file-name.zip)
```
3. Copy your license `jwt` file into the `sasinside` directory of this repo.
4. Run `./launchapro.sh` from the Terminal.
5. Run the following command to get your password:
```
docker logs sas-analytics-pro 2>&1 | grep "Password="
```
6. In your browser navigate to http://localhost:81 and login using your normal username and the password from step 5.

## Docker Desktop on Mac
1. Follow Step 1 in the `Docker on Linux` section of the official Deployment Guide to make sure that you have the following three files in the top level directory:
   * _SAS-certificates-file-name_.zip
   * _SAS-license-file-name_.jwt
   * `mirrormgr`
2. Run the following command to log into the SAS Container Registry (this equates to Step 2 of the Deployment Guide):
```
eval $(./mirrormgr list remote docker login --deployment-data SAS-certificates-file-name.zip)
```
3. Copy your license `jwt` file into the `sasinside` directory of this repo.
4. Run `./launchapro.sh` from the Terminal.
5. Run the following command to get your password:
```
docker logs sas-analytics-pro 2>&1 | grep "Password="
```
6. In your browser navigate to http://localhost:81 and login using your normal username and the password from step 5.
## Docker Desktop on Windows
TBD

## Environment Notes
When you launch the new SAS Analytics Pro environment your user interface into SAS will be via your browser using SAS Studio.  Whether you are running your environment using Docker on Windows, Linux or Mac, all paths within the environment will use Unix paths.  With the default configuration the only file system location common to both your SAS environment and your local machine will be the `data` directory within this repo.

## Running SAS in batch
You can utilise the SAS Analytics Pro container to run your SAS programs in batch. This is achieved by following these steps:
1. Save your `program.sas` file in the `data` directory.
2. Run the following command:
```
./launchapro.sh --batch /data/program.sas
```

**Note:** You will notice that we saved the program file into the `data` directory, which is a subdirectory of this repo, but then referenced that same program with the absolute path `/data/program.sas` on the command line. This is because the `data` directory in this repo is mounted as `/data` _within_ the SAS Analytics Pro environment.