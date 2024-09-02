@echo off
REM bootstrap-setup-wsl.cmd - create and run bootstrap.cmd on the users Desktop
REM - autounattend.xml -> bootstrap-setup-wslN.cmd -> ** bootstrap-setup-wsl.cmd -** > bootstrap-wslN.cmd -> bootstrap-run.cmd -> bootstrap-init -> bootstrap -> inst

REM variables
set dir=%~dp0
if not DEFINED wsl set wsl=2

REM distribution
set dist=Ubuntu
set distUser=jjbutare
rem set distUser=%USERNAME%

REM distribution image - optional
rem set distUnc=\\ender.hagerman.butare.net\public
rem set distImage=documents\data\install\platform\linux\wsl\image\ubuntu\default.tar.gz

REM unc - the current directory is a UNC, but we need to remove the trailing slash or net use will error
set unc=%dir:~0,-1%  

REM create bootstrap.cmd on the Desktop
set f=%HOMEDRIVE%%HOMEPATH%\Desktop\bootstrap.cmd
> "%f%" echo @echo off
>> "%f%" echo echo ************************* bootstrap.cmd *************************
>> "%f%" echo set dist=%dist%
>> "%f%" echo set distUser=%distUser%
>> "%f%" echo set distUnc=%distUnc%
>> "%f%" echo set distImage=%distImage%
>> "%f%" echo if not exist %unc% net use %unc% /user:%distUser%
>> "%f%" echo %dir%bootstrap-wsl%wsl%.cmd

REM run bootstrap.cmd
%f% %*
