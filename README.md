# SAS Analytics Pro (Cloud-Native)
## Overview
This repo contains info and scripts to help get you up and running with the new Cloud-Native (containerised) version of SAS Analytics Pro from the SAS Institute.  The first release of this software is version 2021.1.4 (August 2021).

This release is for version 2021.2.3 (January 2022).

This repo should be used in conjunction with the official [SAS Analytics Pro Deployment Guide](https://documentation.sas.com/doc/en/anprocdc/v_007/dplyviya0ctr/titlepage.htm).  The intention of this repo is to make a few things for the less technical user a bit easier to get up and running.

## Pre-requisites
* [Docker Desktop](https://www.docker.com/products/docker-desktop) for Windows or Mac (or "just docker" for Linux)
* Your Certificate (`*-certs.zip`) file from the `My Orders` section of my.sas.com
* Your License (`*.jwt`) from the `My Orders` section of my.sas.com
* Copy of this repo. The root of this repo is the `$deploy` directory mentioned in the SAS Deployment Guide.
  * Mac/Linux Users - a clone of this repo or a tgz/zip of a specific release
  * Windows - a zip of a specific release you want to use (you could also use a clone of this repo **but** you will need to set `git config auto.crlf false` after you clone in order for the launch to work)
* Instructions below assume you have a normal (i.e. _not elevated_) command prompt/terminal open and have changed directory into the top level of this repo.


## Docker on Linux
1. Follow Step 1 in the `Docker on Linux` section of the official Deployment Guide to make sure that you have your license and certificate files in the top level directory:
   * _SAS-certificates-file-name_.zip
   * _SAS-license-file-name_.jwt
2. Run `./launchapro.sh` from the Terminal.
3. The startup process will be displayed in the console, along with the generated password you will need to use.
4. If you need to manually grab the password later you can run the following command:
```
docker logs sas-analytics-pro 2>&1 | grep "Password="
```
1. In your browser navigate to http://localhost:81 and login using your normal username and the generated password.

## Docker Desktop on Mac
1. Follow Step 1 in the `Docker on Linux` section of the official Deployment Guide to make sure that you have your license and certificate files in the top level directory:
   * _SAS-certificates-file-name_.zip
   * _SAS-license-file-name_.jwt
2. Run `./launchapro.sh` from the Terminal.
3. The startup process will be displayed in the console, along with the generated password you will need to use.
4. If you need to manually grab the password later you can run the following command:
```
docker logs sas-analytics-pro 2>&1 | grep "Password="
```
1. In your browser navigate to http://localhost:81 and login using your normal username and the generated password.

## Docker Desktop on Windows (using WSL2)
1. Make sure you are using a directory on a local drive for these instructions - do not use a Network Drive (drive letter mapped to a UNC path) or a UNC Path.
2. Follow Step 1 in the `Docker Desktop on Windows` section of the official Deployment Guide to make sure that you your license and certificate files in the top level directory:
   * _SAS-certificates-file-name_.zip
   * _SAS-license-file-name_.jwt
3. Run `launchapro.ps1` from a Powershell command prompt.
   * If you have not previously enabled Powershell scripts to run you may get an error. If this is the case, you can enable scripts to run by executing the following command in an _elevated_ Powershell prompt:
```
Set-ExecutionPolicy Unrestricted
```
4. The startup process will be displayed in the console, along with the generated password you will need to use.
5. If you need to manually grab the password later you can run the following command:
```
docker logs sas-analytics-pro 2>&1 | Select-String "Password="
```
1. In your browser navigate to http://localhost:81 and login using your normal username and the generated password.

## Environment Notes
When you launch the new SAS Analytics Pro environment your user interface into SAS will be via your browser using SAS Studio.  Whether you are running your environment using Docker on Windows, Linux or Mac, all paths within the environment will use Unix paths.  With the default configuration the main file system location common to both your SAS environment and your local machine will be the `data` directory within this repo.

# License
(c) Selerity Pty. Ltd. 2021.  All Rights Reserved.

This work is licensed under the Creative Commons Attribution-NonCommercial-NoDerivitives License. To view a copy 
of the license, visit https://creativecommons.org/licenses/by-nc-nd/4.0/
