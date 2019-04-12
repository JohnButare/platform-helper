@echo off

REM Bootstrap a Windows system for Cygwin
REM This script uses only what is available on a newly installed system.

set host=nas1
set data=\\%host%\public\documents\data
set install=%data%\install

set r=yes
set /p r="Update windows? (%r%)? "
if "%r%" == "yes" (
	cmd /c start ms-settings:windowsupdate
	pause
)

set packages=dialog,expect,openssh,openssl,util-linux,wget,nano
set src=--local-package-dir "%install%\Cygwin\package-x64" --site http://mirrors.kernel.org/sourceware/cygwin/  
if defined proxy set proxy=-p %proxy% 

path=c:\Program Files\Cygwin\bin;%data%\bin;%data%\platform\win;%PATH%
set HOME=%USERPROFILE%

set r=yes
set /p r="Install Cygwin? (%r%)? "
if "%r%" == "yes" (
	start /D %TEMP% /WAIT %install%\Cygwin\setup\setup-x64.exe --download --local-install -q --no-shortcuts %src% --root "C:\Program Files\Cygwin" %proxy% -P %packages%
	pause
)

REM run the bootstrap process
echo Bootstrapping from %host%...
bash bootstrap %host% %install%
pause
