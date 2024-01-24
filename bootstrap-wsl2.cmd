@echo off
REM bootstrap-wsl2.cmd - bootstrap a Windows sytem using WSL 2 (requires Hyper-V)
REM - bootstrap-setup-wsl2.cmd -> bootstrap-wsl2.cmd -> bootstrap-init -> bootstrap -> inst
REM - arguments - bootstrap-wsl2.cmd arguments are passed to bootstrap-init, i.e. --verbose

if not defined wsl (
	echo This script must be called from bootstrap-setup-wsl2.cmd.
	pause
	exit /b
)

REM create directories
if not exist "%wslDir%" mkdir "%wslDir%"

REM if the distribution exists then run the bootstrap
if exist "\\wsl.localhost\%dist%\home" goto bootstrap

REM default to WSL 2 and install WSL and reboot if needed
wsl --set-default-version 2 > nul 2>&1
if not %ErrorLevel% == 0 (
	wsl --install --no-distribution --web-download
	shutdown /r /t 0 & exit
)

REM install the distribution if an image was not specified
if not defined distImage (
	echo.
	echo Once the user account is created, exit the shell...
	wsl --install --distribution %dist%	--web-download
	goto bootstrap
)

REM connect to the distribution network share if needed
if defined distUnc (
	if not exist z:\ net use z: %distUnc%
	set distImage=z:\%distImage%
)

REM import the distribution image
wsl --import %dist% %wslDir% %distImage%
goto bootstrap

REM bootstrap recovery
:bootstrap-recovery
echo Unable to create bootstrap files, recovering...
wsl.exe --shutdown
start /min wsl
wsl sleep 5
goto bootstrap

REM run the bootstrap
:bootstrap

echo.
echo Preparing bootstrap files...
copy /Y %pwd%bootstrap-init \\wsl.localhost\%dist%\tmp
copy /Y %pwd%bootstrap-config.sh \\wsl.localhost\%dist%\tmp
wsl -- ls /tmp/bootstrap-init > nul & if errorlevel 1 goto bootstrap-recovery
wsl --user root -- sudo chmod ugo+rwx /tmp/bootstrap-init /tmp/bootstrap-config.sh

echo.
echo Running bootstrap-init...
wsl --user %distUser% /tmp/bootstrap-init %args%
if errorlevel 2 ( wsl.exe --shutdown & goto bootstrap )
if errorlevel 1 goto bootstrap
pause

:done