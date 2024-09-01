@echo off
REM bootstrap-wsl2.cmd - bootstrap a Windows sytem using WSL 2 (requires Hyper-V)
REM - autounattend.xml -> bootstrap-setup-wsl2.cmd -> bootstrap-setup-wsl.cmd -> ** bootstrap-wsl2.cmd ** -> bootstrap-run.cmd -> bootstrap-init -> bootstrap -> inst

REM variables
set dir=%~dp0

REM check
if not defined distUser (
	echo This script must be called from bootstrap-setup-wsl2.cmd.
	pause
	exit /b
)

REM if the distribution exists then run the bootstrap
if exist "\\wsl.localhost\%dist%\home" goto bootstrap

REM install WSL 2 if needed
wsl --set-default-version 2 > nul 2>&1
if not %ErrorLevel% == 0 (
	wsl --install --no-distribution --web-download
	shutdown /r /t 0 & exit
)

REM run the bootstrap
:bootstrap
%dir%bootstrap-run.cmd %*
