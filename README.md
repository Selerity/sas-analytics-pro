# SAS Analytics Pro (Cloud-Native)
## Overview
This repo contains info and scripts to help get you up and running with the new Cloud-Native (containerised) version of SAS Analytics Pro from the SAS Institute.  The first release of this software is version 2021.1.4 (August 2021).

This repo should be used in conjunction with the official [SAS Analytics Pro Deployment Guide](https://go.documentation.sas.com/doc/en/anprocdc/default/anprowlcm/home.htm).  The intention of this repo is to make a few things for the less technical user a bit easier to get up and running.

## Pre-requisites
* [Docker Desktop](https://www.docker.com/products/docker-desktop)
* Your Certificate (`*-certs.zip`) file from the `My Orders` section of my.sas.com
* Your License (`*.jwt`) from the `My Orders` section of my.sas.com
* Clone of this repo. The root of this repo is the `$deploy` directory mentioned in the SAS Deployment Guide.
* Instructions below assume you have a command prompt/terminal open and have changed directory into the top level of this repo.


## Docker on Linux
1. Follow Step 1 in the `Docker on Linux` section of the official Deployment Guide to make sure that you have your license and certificate files in the top level directory:
   * _SAS-certificates-file-name_.zip
   * _SAS-license-file-name_.jwt
2. Copy your license `jwt` file into the `sasinside` directory of this repo.
3. Run `./launchapro.sh` from the Terminal.
4. Run the following command to get your password:
```
docker logs sas-analytics-pro 2>&1 | grep "Password="
```
6. In your browser navigate to http://localhost:81 and login using your normal username and the password from step 5.

## Docker Desktop on Mac
1. Follow Step 1 in the `Docker on Linux` section of the official Deployment Guide to make sure that you have your license and certificate files in the top level directory:
   * _SAS-certificates-file-name_.zip
   * _SAS-license-file-name_.jwt
2. Copy your license `jwt` file into the `sasinside` directory of this repo.
3. Run `./launchapro.sh` from the Terminal.
4. Run the following command to get your password:
```
docker logs sas-analytics-pro 2>&1 | grep "Password="
```
5. In your browser navigate to http://localhost:81 and login using your normal username and the password from step 5.
## Docker Desktop on Windows (using WSL2)
1. Make sure you are using a directory on a local drive for these instructions - do not use a Network Drive (drive letter mapped to a UNC path) or a UNC Path.
2. Follow Step 1 in the `Docker Desktop on Windows` section of the official Deployment Guide to make sure that you your license and certificate files in the top level directory:
   * _SAS-certificates-file-name_.zip
   * _SAS-license-file-name_.jwt
3. Copy your license `jwt` file into the `sasinside` directory of this repo.
4. Run `launchapro.ps1` from a Powershell command prompt.
5. Run the following command to get your password:
```
docker logs sas-analytics-pro 2>&1 | Select-String "Password="
```
6. In your browser navigate to http://localhost:81 and login using your normal username and the password from step 5.

## Environment Notes
When you launch the new SAS Analytics Pro environment your user interface into SAS will be via your browser using SAS Studio.  Whether you are running your environment using Docker on Windows, Linux or Mac, all paths within the environment will use Unix paths.  With the default configuration the only file system location common to both your SAS environment and your local machine will be the `data` directory within this repo.

# License
(c) Selerity Pty. Ltd. 2021.  All Rights Reserved.

This work is licensed under the Creative Commons Attribution-NonCommercial-NoDerivitives License. To view a copy 
of the license, visit https://creativecommons.org/licenses/by-nc-nd/4.0/