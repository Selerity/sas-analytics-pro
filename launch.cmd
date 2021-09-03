@echo off 2>nul

goto(){
## Run Linux / MACOS Launcher
rm -f nul && cd "$(dirname "${BASH_SOURCE[0]}")"
bash "lib/launchapro.sh" ${@}
}

goto ${@}
exit

:(){
rem Run Windows Launcher
set basepath=%~dp0 & cd "%basepath%"
powershell -noexit "& "".\lib\launchapro.ps1""" %*
exit
