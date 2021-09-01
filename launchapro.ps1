# (c) Selerity Pty. Ltd. 2021.  All Rights Reserved.
#
# This work is licensed under the Creative Commons Attribution-NonCommercial-NoDerivitives License. To view a copy 
# of the license, visit https://creativecommons.org/licenses/by-nc-nd/4.0/

# Ensure that apro.settings file is present
if (Test-Path -Path ".\apro.settings" -PathType Leaf) {
  $config = Get-Content .\apro.settings | Out-String | ConvertFrom-StringData
  if ($args[0] -eq "--batch") {
    $config.SAS_RUN_HTTPD = "false"
  } else {
    $config.SAS_RUN_HTTPD = "true"
  }
  if ($config.RUN_MODE -eq $null) {
    $config.RUN_MODE = "developer"
  }
  if ($config.SAS_DEMO_USER -eq '$USER') {
    $config.SAS_DEMO_USER = $env:USERNAME
  }

  $env:SAS_RUN_HTTPD = $config.SAS_RUN_HTTPD
  $env:STUDIO_HTTP_PORT = $config.STUDIO_HTTP_PORT
  $env:RUN_MODE = $config.RUN_MODE
  $env:SASLICENSEFILE = $config.SASLICENSEFILE
  $env:SAS_DEBUG = $config.SAS_DEBUG
  $env:SAS_DEMO_USER = $config.SAS_DEMO_USER
  $env:SASLOCKDOWN = $config.SASLOCKDOWN
  $env:SASV9_OPTIONS = $config.SASV9_OPTIONS

} else {
  Write-Host "ERROR: apro.settings file not found"
  Exit 1
}

# Ensure that sasinside directory exists
if (-Not(Test-Path -Path "sasinside")) {
  Write-Host "ERROR: sasinside directory not found"
  Exit 1
}

# Ensure that data directory exists
if (-Not(Test-Path -Path "data")) {
  Write-Host "ERROR: data directory not found"
  Exit 1
}

# Get latest license from sasinside directory
$config.SASLICENSEFILE = Get-ChildItem .\sasinside -Filter "*.jwt" | Sort-Object -Descending
if ($config.SASLICENSEFILE -eq $null) {
  Write-Host "ERROR: Could not locate SAS license file in sasinside directory"
  Exit 1
}

$env:SASLICENSEFILE = $config.SASLICENSEFILE.Name

$run_args = "-u root " +
"--name=sas-analytics-pro " +
"--rm " +
"--detach " +
"--hostname sas-analytics-pro " +
"--env SAS_RUN_HTTPD " +
"--env STUDIO_HTTP_PORT " +
"--env RUN_MODE " +
"--env SASLICENSEFILE " +
"--env SAS_DEBUG " +
"--env SAS_DEMO_USER " +
"--env SASLOCKDOWN " +
"--env SASV9_OPTIONS " +
"--publish " + $config.STUDIO_HTTP_PORT + ":80 " +
"--volume '$pwd\sasinside:/sasinside' " +
"--volume '$pwd\data:/data'"

$cmd = "docker run " + $run_args + " " + $config.IMAGE + ":" + $config.IMAGE_VERSION + " $args"

Invoke-Expression $cmd