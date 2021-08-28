# Advanced Usage

Startup behaviour of some components of SAS Analytics Pro can be configured using `usermod` files, just like in SAS 9.4.  These are:

## Autoexec File
You can add SAS statements to run at startup by creating a `autoexec_usermods.sas` file in the `sasinside` directory.

## SAS Configuration File
To set SAS System Options at startup, you can create a `sasv9_usermods.cfg` file in the `sasinside` directory.

## SAS Spawner Environment
The Spawner is what starts your SAS session behind the scenes, and to customise it you can add a `spawner_usermods.sh` file in the `sasinside` directory. A common use for this is to allow SAS to run external commands (i.e. setting the `-allowxcmd` option).

## SAS Workspace Environment
When using SAS Studio your SAS session under the covers is running a "workspace".  To configure this environment you can add a `workspaceserver_usermods.sh` file to the `sasinside` directory.

## SAS Batch Server Environment
If you run SAS programs in batch (using the `--batch` option) you can configure this SAS environment by adding a `batchserver_usermods.sh` file to the `sasinside` directory.

## SAS Studio
If you need to configure the SAS Studio application then you can add those configuration settings to a `init_usermods.properties` file in the `sasinside` directory.  A common example of this is to allow password based authentication to your git repositories by adding `sas.studio.allowGitPassword=True`.