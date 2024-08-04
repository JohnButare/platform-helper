@echo off
REM bootstrap-wsl1.cmd - bootstrap a Windows sytem using WSL 1 (if Hyper-V virtualization is not available)
REM - bootstrap-setup-wsl1.cmd -> bootstrap-wsl1.cmd -> bootstrap-init -> bootstrap -> inst
REM - arguments - bootstrap-wsl1.cmd arguments are passed to bootstrap-init, i.e. --verbose

if not defined wsl (
	echo This script must be called from bootstrap-setup.cmd.
	pause
	exit /b
)

REM if the distribution exists then run the bootstrap
if exist \\wsl.localhost\%dist%\home goto bootstrap

REM install WSL 
wsl.exe --set-default-version 1
wsl.exe --install --distribution %dist%
pause

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
goto done

:done
echo.
echo Bootstrap completed successfully.
pause
