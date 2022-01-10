# Configuration

The SAS Analytics Pro environment can be configured using the `apro.settings` file.  The following settings can be used within this file:

## `CST`
If you have the SAS Clinical Standards Toolkit (CST) licensed for SAS 9.4 on Linux you can set this value to `true`.  To use the CST you must also specify the location of your SAS 9.4 Depot using the `SAS94DEPOT` option.

## `IMAGE`
This is the location of the SAS Analytics Pro docker image. The default value for this can be changed to a local docker registry if you have used `mirrormgr` or `docker` to copy the image to a different repository.

## `IMAGE_VERSION`
This is the docker tag and equates to the docker image version. The following list shows the equivalent docker tag for each SAS Analytics Pro relase:

| SAS Analytics Pro Release | Docker Tag |
| --- | --- |
| 2021.1.4 | 0.5.112-20210816.1629112810612 |
| 2021.1.5 | 0.6.24-20210917.1631905997915 |
| 2021.1.6 | 0.7.36-20211018.1634580897331 |
|          | 0.7.41-20211222.1640193731639 |
|          | 0.7.42-20220107.1641575975534 |
| 2021.2   | 0.8.27-20211115.1636974335897 |
| 2021.2.1 | 0.8.27-20211115.1636974335897 |
|          | 0.8.28-20220107.1641577455247 |
| 2021.2.2(?) | 0.9.24-20211217.1639784757479 |
|          | 0.9.25-20220107.1641578822369 |

## `JUPYTERLAB`
If you would like to enable the Jupyter Lab interface then set this value to `true`.  This creates a virtual Python environment within the `python` sub directory of this repo, which is accessed via `/python` within the container.  Your Jupyter Lab environment will contain the SAS Kernel pre-configured against the SAS Analytics Pro environment. By default you will access Jupyter Lab using http://localhost:8888 and use you generated password to login.

## `JUPYTERLAB_HTTP_PORT`
This is the HTTP port you want the Jupyter Lab interface to use. This repo uses port `8888` by default.  If you leave the default in place then you will access Jupyter Lab using the URL `http://localhost:8888`.  When running on Linux you will need to pick a port over `1024`.

## `SAS_DEBUG`
Setting this value to anything greater than `0` will cause SAS to show extra debug information in the log available using the `docker logs` command.

## `SAS_DEMO_USER`
This sets the user ID you will use to log into SAS Studio with.  If you set this value to `blank` (by deleting the value after the `=` sign) this will default to `sasdemo`.  This repo attempts to re-use the user name you have already logged into you machine with. e.g. if you log into your PC with the user name `michael` then you will also be able to log into SAS Studio using that same user name (_but SAS Studio will use a different password - which is available using the main instructions_).

## `SAS94DEPOT`
This option is used to locate your SAS 9.4 Depot when using the Clinical Standards Toolkit.  This can be a local or UNC path to your SAS 9.4 Depot.

## `SASLOCKDOWN`
Setting this value to `blank` (by deleting the value after the `=` sign) or `true` will cause your environment to be in [Lockdown mode](https://documentation.sas.com/doc/en/sasadmincdc/v_017/calsrvpgm/p04d9diqt9cjqnn1auxc3yl1ifef.htm?homeOnFail).  By setting this value to `false` your environment _will not_ be in Lockdown mode.

## `SASV9_OPTIONS`
There are two ways you can set SAS System Options that you want to be applied at startup to your SAS environment - using this configuration setting or by providing a `sasv9_usermods.cfg` file in the `sasinside` directory.  Please note that some system options (such as `DLCREATEDIR`) shouldn't be applied at startup due to the readonly nature of the SAS filesystem (startup will fail because some SASHELP directories don't exist, and SAS will try to create them if `DLCREATEDIR` is in effect but it won't be able to because the file system is readonly).

Our preference is to set system options using the `sasv9_usermods.cfg` file.

## `STUDIO_HTTP_PORT`
This is the HTTP port you want to use in the URL to access SAS Studio.  This repo uses port `81` by default just in case you already have a web server running on the standard port of `80`.  If you leave the default in place then you will access SAS Studio using the URL `http://localhost:81`.  When running on Linux you will need to pick a port over `1024`, and historically SAS has used `7080` for this purpose.
