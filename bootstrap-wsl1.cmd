@echo off
REM bootstrap-wsl1.cmd - bootstrap a Windows sytem using WSL 1 (no nested virtualization, Mac virtual machines)
REM - autounattend.xml -> bootstrap-setup-wsl1.cmd -> bootstrap-setup-wsl.cmd -> ** bootstrap-wsl1.cmd ** -> bootstrap-run.cmd -> bootstrap-init -> bootstrap -> inst

REM variables
set dir=%~dp0

REM check
if not defined distUser (
	echo This script must be called from bootstrap-setup.cmd.
	pause
	exit /b
)

REM if the distribution exists then run the bootstrap
if exist "\\wsl.localhost\%dist%\home" goto bootstrap

REM make WSL 1 the default version
wsl.exe --set-default-version 1

REM run the bootstrap
:bootstrap
%dir%bootstrap-run.cmd %*
