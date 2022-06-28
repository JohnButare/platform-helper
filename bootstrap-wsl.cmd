@echo off
REM bootstrap-wsl.cmd - bootstrap a Windows sytem
REM bootstrap-setup.cmd -> bootstrap-wsl.cmd -> bootstrap-init -> bootstrap -> inst

REM dist - name of the distribution to install
set dist=Ubuntu

REM if set, the distribution image to import, otherwise a fresh image is downloaded
set distUnc=\\ender.hagerman.butare.net\public
set distImage=documents\data\install\platform\linux\wsl\image\ubuntu\default.tar.gz

REM bin - the location of the bin directory, if unset find it
set bin=//ender.hagerman.butare.net/system/usr/local/data/bin
rem set bin=//pi2.hagerman.butare.net/root/usr/local/data/bin
rem set bin=//StudyMonitor.hagerman.butare.net/root/usr/local/data/bin:22

REM install - installation directory, if unset find it
set install=//ender.hagerman.butare.net/public/documents/data/install

REM variables
set pwd=%~dp0%
set wsl=C:\Users\Public\data\appdata\wsl

REM create directories
if not exist "%wsl%" mkdir "%wsl%"

REM if the distribution exists then run the bootstrap
if exist "\\wsl.localhost\%dist%\home" goto bootstrap

REM download WSL and a distribution if a distribution image was not specified
if not defined distImage (
	wsl --install --distribution %dist%	--web-download
	goto check
)

REM connect to the distribution network share
if defined distUnc (
	if not exist z:\ net use z: %distUnc%
	set distImage=z:\%distImage%
)

REM install WSL 
wsl --status > nul
if not %ErrorLevel% == 0 wsl --install --no-distribution

REM import the distribution image, use --no-distribution option to prevent installing a distribution automatically
wsl --import %dist% %wsl% %distImage%

REM check the distribution
:check
if not exist "\\wsl.localhost\%dist%\home" (
	echo Press any key to reboot and finish the installation...
	pause
	shutdown /r /t 0 & exit
)

REM run the bootstrap
:bootstrap
echo Running bootstrap...
copy %pwd%bootstrap-init \\wsl.localhost\%dist%\tmp
copy %pwd%bootstrap-config.sh \\wsl.localhost\%dist%\tmp
wsl --user root -- sudo chmod ugo+rwx /tmp/bootstrap-init /tmp/bootstrap-config.sh
wsl --user %USERNAME% /tmp/bootstrap-init %bin% %install% %*
if errorlevel 1 goto bootstrap

pause