@echo off
REM bootstrap-setup.cmd - run the bootstrap process for WSL 2
REM - autounattend.xml -> ** bootstrap-setup.cmd ** -> bootstrap-setup-wsl.cmd -> bootstrap-wslN.cmd -> bootstrap-run.cmd -> bootstrap-init -> bootstrap -> inst
set wsl=2
%~dp0%bootstrap-setup-wsl.cmd