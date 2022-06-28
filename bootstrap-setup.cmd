@echo off
REM bootstrap-setup.cmd - create and run bootstrap.cmd on the users Desktop to run the bootstrap process
REM bootstrap-setup.cmd -> bootstrap.cmd -> bootstrap-wsl.cmd -> bootstrap-init -> bootstrap -> inst

REM variables
set pwd=%~dp0

REM create bootstrap.cmd on the Desktop to run manually if needed
set file=%HOMEPATH%\Desktop\bootstrap.cmd
echo @echo off > %file%
echo %pwd%bootstrap-wsl.cmd >> %file%

REM run bootstrap.cmd after reboot
copy %file% "%PROGRAMDATA%\Microsoft\Windows\Start Menu\Programs\Startup"

REM run bootstrap.cmd
%file%
