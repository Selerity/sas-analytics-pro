# (c) Selerity Pty. Ltd. 2021.  All Rights Reserved.
#
# This work is licensed under the Creative Commons Attribution-NonCommercial-NoDerivitives License. To view a copy 
# of the license, visit https://creativecommons.org/licenses/by-nc-nd/4.0/

Write-Host "#############################################"
Write-Host "#    SAS Analytics Pro Personal Launcher    #"
Write-Host "#-------------------------------------------#"

$ScriptDir = Split-Path $script:MyInvocation.MyCommand.Path
Set-Location -Path $ScriptDir

# Check that docker is running
$docker_status=(docker version 2>&1)
if ($LASTEXITCODE -gt 0) {
  Write-Host "ERROR: A running docker client is required to use this software.  Please install or start your instance of Docker before proceeding."
  Exit 1
}

# Ensure that apro.settings file is present
if (Test-Path -Path ".\apro.settings" -PathType Leaf) {
  $config = (Get-Content .\apro.settings | Out-String) -replace '\\','\\' | ConvertFrom-StringData
  if ($args[0] -eq "--batch") {
    $config.SAS_RUN_HTTPD = "false"
    $config.BATCH_MODE = "true"
    $config.NAME = ""
    $config.STUDIO = ""
    $config.SASOQ = $False
  } elseif ($args[0] -eq "--sasoq") {
    if ( -Not $args[1] ) {
      Write-Host "ERROR: When SAS OQ is enabled you must specify test parameters."
      Exit 1
    }
    $config.SAS_RUN_HTTPD = "false"
    $config.BATCH_MODE = "true"
    $config.NAME = ""
    $config.STUDIO = ""
    $config.SASOQ = $True
    $config.PERL = $True
  } else {
    $config.SASOQ = $False
    $config.SAS_RUN_HTTPD = "true"
    $config.BATCH_MODE = "false"
    $config.STUDIO = "--publish " + $config.STUDIO_HTTP_PORT + ":80 "
    $config.NAME="--name=sas-analytics-pro"

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
$config.SASLICENSEFILE = Get-ChildItem . -Filter "SASViyaV4_*_license_*.jwt" | Sort-Object -Descending
if ($config.SASLICENSEFILE -eq $null) {
  Write-Host "ERROR: Could not locate SAS license file."
  Exit 1
}
# Copy found license to sasinside directory
Copy-Item $config.SASLICENSEFILE -Destination ".\sasinside\"
$env:SASLICENSEFILE = $config.SASLICENSEFILE.Name

# Get latest certificate ZIP
$config.SASCERTFILE = Get-ChildItem . -Filter "SASViyaV4_*_certs.zip" | Sort-Object -Descending
if ($config.SASCERTFILE -eq $null) {
  Write-Host "ERROR: Could not locate SAS certificates file."
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
  $mirrormgr_dir = New-Item -ItemType "directory" -Path "$env:TEMP\mirrormgr" -Force
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

# Jupyter Lab
if ( $config.JUPYTERLAB -eq $True -And $config.BATCH_MODE -eq 'false' ) {
  Write-Host "# Add-on: JupyterLab Enabled                #"
  $jupyterlab_args = -join ("--env POST_DEPLOY_SCRIPT=/sasinside/jupyterlab.sh --publish ", $config.JUPYTERLAB_HTTP_PORT, ":8888")
} else {
  $jupyterlab_args = ""
}

# Clinical Standards Toolkit
if ( $config.CST -eq $True ) {
  Write-Host "# Add-on: CST Enabled                       #"
  # Check if we already have the required files extracted
  if ( (Test-Path -Path $(-join($pwd, "\addons\", $config.CSTGLOBAL, "/build/buildinfo.xml")) -PathType Leaf) -eq $True -And `
        (Test-Path -Path $(-join($pwd, "\addons\", $config.CSTSAMPLE, "/build/buildinfo.xml")) -PathType Leaf) -eq $True -And `
        (Test-Path -Path $(-join ($pwd, "\addons\", $config.CSTMACROS)) -PathType Container) -eq $True ) {
        $cst_args = -join (" --volume '", $pwd, "\addons\", $config.CSTGLOBAL, ":/data/cstGlobalLibrary' --volume '", $pwd, "\addons\", $config.CSTSAMPLE, ":/data/cstSampleLibrary' --volume '", $pwd, "\addons\", $config.CSTMACROS, ":/addons/cstautos'")
        $env:SASV9_OPTIONS = -join ($env:SASV9_OPTIONS, " -CSTGLOBALLIB=/data/cstGlobalLibrary -CSTSAMPLELIB=/data/cstSampleLibrary -insert sasautos /addons/cstautos -set CLASSPATH=/addons/cstautos/eclipse/plugins/sas.cdisc.transforms_107000.0.0.20160913165121_f0cltk17/sas.cdisc.transforms.jar")
  } else {
    # Download the CST
    # create temp with zip extension (or Expand will complain)
    $tmp = New-TemporaryFile | Rename-Item -NewName { $_ -replace 'tmp$', 'zip' } -PassThru
    #download
    Write-Host "# Add-on: CST being downloaded from SAS     #"
    Invoke-WebRequest -OutFile $tmp $config.CSTHF
    # Create temp directory
    $cst_dir = New-Item -ItemType "directory" -Path "$env:TEMP\cstsource" -Force
    #exract to same folder 
    $tmp | Expand-Archive -DestinationPath $cst_dir -Force
    # remove temporary file
    $tmp | Remove-Item

    if ( (Test-Path -Path $($cst_dir.FullName + "\products") -PathType Container) -eq $True ) {

      # Prepare CST files
      Expand-Archive -LiteralPath $((-join($cst_dir.FullName, "/products/cstframework__Z46002__lax__en__sp0__1/en_sasautos.zip")) -replace '/','\') -DestinationPath $(-join($pwd, "\addons\", $config.CSTBASE))
      Expand-Archive -LiteralPath $((-join($cst_dir.FullName, "/products/cstgblstdlib__Z48002__prt__xx__sp0__1/cstgblstdlib_gen.zip")) -replace '/','\') -DestinationPath $(-join($pwd, "\addons\", $config.CSTGLOBAL))
      Expand-Archive -LiteralPath $((-join($cst_dir.FullName, "/products/cstgblstdlib__Z48002__prt__xx__sp0__1/native_lax.zip")) -replace '/','\') -DestinationPath $(-join($pwd, "\addons\", $config.CSTGLOBAL))
      Expand-Archive -LiteralPath $((-join($cst_dir.FullName, "/products/cstsamplelib__Z49002__prt__xx__sp0__1/cstsamplelib_gen.zip")) -replace '/','\') -DestinationPath $(-join($pwd, "\addons\", $config.CSTSAMPLE))
      Expand-Archive -LiteralPath $((-join($cst_dir.FullName, "/products/cstsamplelib__Z49002__prt__xx__sp0__1/native_lax.zip")) -replace '/','\') -DestinationPath $(-join($pwd, "\addons\", $config.CSTSAMPLE))
      Expand-Archive -LiteralPath $((-join($cst_dir.FullName, "/products/cstfrmwrkjar__Z47002__prt__xx__sp0__1/cstfrmwrkjar_vjr.zip")) -replace '/','\') -DestinationPath $(-join($pwd, "\addons\", $config.CSTMACROS))
      $cst_dir | Remove-Item -Recurse -Force
      # Fix SAS Macro code
      Get-ChildItem -Recurse -Path (-join ($pwd, "\addons\", $config.CSTBASE)) -Include "*.sas" |
      Foreach-Object {
        (Get-Content $_.FullName).replace('%sysevalf(&sysver)', '&sysver') | Set-Content $_.FullName
        (Get-Content $_.FullName).replace('/ picklist="&_cstJavaPicklist"', '') | Set-Content $_.FullName
      }
      $cst_args = -join (" --volume '", $pwd, "\addons\", $config.CSTGLOBAL, ":/data/cstGlobalLibrary' --volume '", $pwd, "\addons\", $config.CSTSAMPLE, ":/data/cstSampleLibrary' --volume '", $pwd, "\addons\", $config.CSTMACROS, ":/addons/cstautos'")
      $env:SASV9_OPTIONS = -join ($env:SASV9_OPTIONS, " -CSTGLOBALLIB=/data/cstGlobalLibrary -CSTSAMPLELIB=/data/cstSampleLibrary -insert sasautos /addons/cstautos -set CLASSPATH=/addons/cstautos/eclipse/plugins/sas.cdisc.transforms_107000.0.0.20160913165121_f0cltk17/sas.cdisc.transforms.jar")
      Write-Host "# Add-on: CST prepared                      #"
    } else {
      Write-Host "ERROR: CST=true but required files are not available from SAS for download."
      Exit 1
    }
  }
} else {
  $cst_args = ""
}

# Perl for SAS
if ( $config.PERL -eq $True ) {
  Write-Host "# Add-on: Perl Enabled                      #"
  # Check if we already have the required files extracted
  if ( (Test-Path -Path $(-join($pwd, "\addons\perl\bin\perl5")) -PathType Leaf) -eq $True ) {
        $perl_args = -join (" --volume '", $pwd, "\addons\perl", ":/opt/sas/viya/home/SASFoundation/perl'")
        $perl_predeploy = "chmod 755 /opt/sas/viya/home/SASFoundation/perl/bin/*"
  } else {
    # Download Perl for SAS
    # create temp with zip extension (or Expand will complain)
    $tmp = New-TemporaryFile | Rename-Item -NewName { $_ -replace 'tmp$', 'zip' } -PassThru
    #download
    Write-Host "# Add-on: Perl for SAS being downloaded     #"
    Invoke-WebRequest -OutFile $tmp $config.PERLFORSAS
    # Prepare Perl for SAS files
    $tmp | Expand-Archive -DestinationPath $(-join($pwd, "\addons\perl")) -Force
    # remove temporary file
    $tmp | Remove-Item

    $perl_args = -join (" --volume '", $pwd, "\addons\perl", ":/opt/sas/viya/home/SASFoundation/perl'")
    $perl_predeploy = "chmod 755 /opt/sas/viya/home/SASFoundation/perl/bin/*"
    Write-Host "# Add-on: Perl prepared                     #"

  }
} else {
  $perl_args = ""
}

# SAS Operational Qualification
if ( $config.SASOQ -eq $True ) {
  Write-Host "# SAS OQ Mode                               #"
  $entrypoint="--entrypoint /addons/sasoq/sasoq.sh"
  $sasoq_args = -join (" --volume '", $pwd, "\addons\sasoq", ":/addons/sasoq'")
} else {
  $entrypoint=""
  $sasoq_args = ""
}

# Collect Add-Ons
$addons = "$jupyterlab_args $cst_args $perl_args $sasoq_args"

# Collect Pre Deploy Commands
$env:PRE_DEPLOY_SCRIPT = $config.PRE_DEPLOY_SCRIPT + "`n" + $perl_predeploy

# Get Local Windows Drives
$drives = [System.IO.DriveInfo]::GetDrives() | Where-Object { $_.DriveType -eq [System.IO.DriveType]::Fixed}
foreach ($drive in $drives)  { 
    $windows_drives = -join (" ", $windows_drives, " --volume '", $drive.RootDirectory, ":/mnt/", $drive.RootDirectory.ToString().SubString(0,1).ToLower(), "'")
}

$run_args = "-u root " +
$config.NAME + " " +
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
"--env PRE_DEPLOY_SCRIPT " +
$config.STUDIO + " " +
"--volume '$pwd\sasinside:/sasinside' " +
"--volume '$pwd\python:/python' " +
"--volume '$pwd\data:/data' " +
$windows_drives +
$addons

$cmd = "docker run " + $entrypoint + " " + $run_args + " " + $config.IMAGE + ":" + $config.IMAGE_VERSION + " $args" -replace "--sasoq",""

$container=(Invoke-Expression $cmd)

if ( $LASTEXITCODE -gt 0 ) {
  Write-Host "ERROR: Something went wrong trying to launch SAS Analytics Pro. Please refer to the documentation."
  Exit 1
}

if ( $config.SASOQ -eq $True ) {
  Write-Host "# Streaming OQ Logs                         #"
  Write-Host "#############################################"
  $container_name = (docker inspect --format='{{.Name}}' $container)
  Write-Host "Name: " $container_name
  Invoke-Expression ("docker logs " + $container_name + " -f")
} elseif ( $config.BATCH_MODE -eq $True ) {
  Write-Host "# Batch Mode                                #"
  Write-Host "#############################################"
  $container_name = (docker inspect --format='{{.Name}}' $container)
  Write-Host "Name: " $container_name
} else {
  # Monitor SAS Analytics Pro as it starts up
  Write-Host "# S = SAS Studio has started                #"
  if ( $config.JUPYTERLAB -eq "true" ) {
    Write-Host "# J = Jupyter Lab has started               #"
  }
  Write-Host "#############################################"
  Write-Host -NoNewline "."
  $timing = 5,5,5,5,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10
  foreach ($_check in $timing) {
    Start-Sleep -s $_check
    $apro_password = if ($null -eq $apro_password) { (docker logs $container 2>&1 | Select-String "Password=") }
    $studio_start = if ($null -eq $studio_start) { (docker logs $container 2>&1 | Select-String "service Root WebApplicationContext: initialization completed") }
    if ( $config.JUPYTERLAB -eq "true" ) {
      $jupyter_start = if ($null -eq $jupyter_start) { (docker logs $container 2>&1 | Select-String "Jupyter Server ") }
    }

    Write-Host -NoNewline "."

    if ( -Not $studio_start -eq "" ) {
      # SAS Studio has started
      if ( $null -eq $studio_flag ) {
        Write-Host -NoNewLine "S"
        $studio_flag = 1
      }
      if ( $config.JUPYTERLAB -eq $True ) {
        if ( -Not $jupyter_start -eq "" ) {
          # Jupyter Lab has started
          Write-Host -NoNewline "J"
          Break
        }
      } else {
        Break
      }
    }
  }

  if ( $null -eq $studio_start ) {
    Write-Host "WARNING: Could not detect startup of SAS Studio.  Please manually check status with ""docker logs sas-analytics-pro"""
    Exit 1
  }

  Write-Host "`n#############################################"
  Write-Host "Browser Access: http://localhost:$env:STUDIO_HTTP_PORT"
  if ( $config.JUPYTERLAB -eq $True ) {
    Write-Host "JupyterLab: http://localhost:$config.JUPYTERLAB_HTTP_PORT"
  }
  Write-Host "User ID=$env:SAS_DEMO_USER"

  if ( -Not $null -eq $apro_password ) {
    Write-Host $apro_password
  }

  Write-Host "`n`To stop your SAS Analytics Pro instance, use ""docker stop sas-analytics-pro"" `n"
}