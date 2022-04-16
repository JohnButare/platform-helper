@echo off
REM bootstrap-setup.cmd - create and run bootstrap.cmd on the users Desktop to run the bootstrap process
REM bootstrap-setup.cmd -> bootstrap-wsl.cmd -> bootstrap-init -> bootstrap -> inst

REM create bootstrap.cmd on the users Desktop
set file=%HOMEPATH%\bootstrap.cmd
set unc=%~dp0
echo @echo off > %file%
echo net use %unc% >> %file%
echo %unc%\bootstrap-wsl.cmd >> %file%

REM run bootstrap.cmd
%file%
