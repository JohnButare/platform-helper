@echo off

set r=wiggin
set /p r="environment? (%r%)? "
if "%r%" == "wiggin" (
	set host=nas1
	set data=\\%host%\public\documents\data
	set install=%data%\install
	set proxy=
) else if "%r%" == "intel" (
	set computer=CsisBuild.intel.com
	set data=\\%host%\c$\users\public\documents\data
	set install=\\%host%\install
	set proxy=proxy-chain.intel.com:911
) else (
  echo "%r% is not a valid environment (intel|wiggin)"
  pause
  exit /b
)

set r=yes
set /p r="Update windows? (%r%)? "
if "%r%" == "yes" (
	cmd /c start ms-settings:windowsupdate
	pause
)

set r=yes
set /p r="Update DNS configuration? (%r%)? "
if "%r%" == "yes" (
	echo - LAN, Properties, Network status,  disable IPv6, IPv4 DNS to 192.168.1.2, 192.168.1.3
	control netconnections
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
