# **Advanced Usage**

# Running SAS in batch
You can utilise the SAS Analytics Pro container to run your SAS programs in batch. This is achieved by following these steps:
1. Save your `program.sas` file in the `data` directory.
2. Run the following command:
```
./launchapro.sh --batch /data/program.sas
```

**Note:** You will notice that we saved the program file into the `data` directory, which is a subdirectory of this repo, but then referenced that same program with the absolute path `/data/program.sas` on the command line. This is because the `data` directory in this repo is mounted as `/data` _within_ the SAS Analytics Pro environment.

# Running SAS OQ Mode
SAS Analytics Pro can be run in **SAS Operational Qualification Tool** (SASOQ) mode.  SAS Analytics Pro consists of Base SAS, SAS/STAT and SAS.GRAPH. The SAS testware for these products can be run using the `--sasoq` command line parameter of the launcher:
```
./launcher.[sh|ps1] --sasoq "-outdir /data/sasoq_results -tables *:base *:stat *:graph"
```
In the above example output will be written to the `data/sasoq_results` directory, and all tests for Base SAS, SAS/STAT and SAS/GRAPH will be executed.

Parameters to the SAS OQ tool can be specified within double quotes following the `--sasoq` launcher parameter.  Further details can be found in the [SAS 9.4 Qualification Tools User's Guide](https://support.sas.com/documentation/installcenter/en/ikinstqualtoolug/66614/PDF/default/qualification_tools_guide.pdf).

# Custom Settings
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