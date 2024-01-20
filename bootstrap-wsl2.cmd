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

REM default to WSL 2
wsl --set-default-version 2

REM download WSL and a distribution if a distribution image was not specified
if not defined distImage (
	wsl --install --distribution %dist%	--web-download || wsl --install --distribution %dist%
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
wsl --import %dist% %wslDir% %distImage%

REM check the distribution
:check
if not exist "\\wsl.localhost\%dist%\home" (
	echo Press any key to reboot and finish the installation...
	pause
	shutdown /r /t 0 & exit
)

REM run the bootstrap
:bootstrap
echo Running bootstrap-init...
copy /Y %pwd%bootstrap-init \\wsl.localhost\%dist%\tmp
copy /Y %pwd%bootstrap-config.sh \\wsl.localhost\%dist%\tmp
wsl --user root -- sudo chmod ugo+rwx /tmp/bootstrap-init /tmp/bootstrap-config.sh
echo.
wsl --user %distUser% /tmp/bootstrap-init %args%
if errorlevel 2 ( wsl.exe --shutdown & goto bootstrap )
if errorlevel 1 goto bootstrap
pause