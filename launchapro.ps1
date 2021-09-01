# (c) Selerity Pty. Ltd. 2021.  All Rights Reserved.
#
# This work is licensed under the Creative Commons Attribution-NonCommercial-NoDerivitives License. To view a copy 
# of the license, visit https://creativecommons.org/licenses/by-nc-nd/4.0/

$ScriptDir = Split-Path $script:MyInvocation.MyCommand.Path
Set-Location -Path $ScriptDir

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

# Get latest certificate ZIP
$config.SASCERTFILE = Get-ChildItem . -Filter "SASViyaV4_*_certs.zip" | Sort-Object -Descending
if ($config.SASCERTFILE -eq $null) {
  Write-Host "ERROR: Could not locate SAS certificates file in current directory"
  Exit 1
}
# Check if Docker has previously authenticate to cr.sas.com
if (-Not (Select-String -Path $env:USERPROFILE\.docker\config.json -Pattern "cr.sas.com" -Quiet) ) {
  # Previous authentication not found, so we need to get login using mirrormgr
  Write-Host "Existing login to SAS Docker Registry not found. Attempting to authenticate..."
  # Download mirrormgr
  # create temp with zip extension (or Expand will complain)
  $tmp = New-TemporaryFile | Rename-Item -NewName { $_ -replace 'tmp$', 'zip' } -PassThru
  #download
  Invoke-WebRequest -OutFile $tmp "https://support.sas.com/installation/viya/4/sas-mirror-manager/wx6/mirrormgr-windows.zip"
  # Create temp directory
  $mirrormgr_dir = New-Item -ItemType "directory" -Path "$env:TEMP\mirrormgr"
  #exract to same folder 
  $tmp | Expand-Archive -DestinationPath $mirrormgr_dir -Force
  # remove temporary file
  $tmp | Remove-Item
  # Log into the SAS docker registry
  $docker_user = Invoke-Expression -Command $(-join($mirrormgr_dir.FullName, "\mirrormgr.exe list remote docker login user --deployment-data ", $config.SASCERTFILE))
  $docker_pass = Invoke-Expression -Command $(-join($mirrormgr_dir.FullName, "\mirrormgr.exe list remote docker login password --deployment-data ", $config.SASCERTFILE))
  $docker_pass | docker login cr.sas.com --username $docker_user --password-stdin
  # clean up
  $mirrormgr_dir | Remove-Item -Force -Recurse
}

# Get Local Windows Drives
$drives = [System.IO.DriveInfo]::GetDrives() | Where-Object { $_.DriveType -eq [System.IO.DriveType]::Fixed}
foreach ($drive in $drives)  { 
    $windows_drives = -join (" ", $windows_drives, " --volume '", $drive.RootDirectory, ":/mnt/", $drive.RootDirectory.ToString().SubString(0,1).ToLower(), "'")
}

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
"--volume '$pwd\data:/data' " +
$windows_drives

$cmd = "docker run " + $run_args + " " + $config.IMAGE + ":" + $config.IMAGE_VERSION + " $args"

Invoke-Expression $cmd