@echo off
REM bootstrap-setup.cmd - run the bootstrap process for WSL 1 (no nested virtualization, Mac virtual machines)
REM - autounattend.xml -> ** bootstrap-setup-wsl1.cmd ** -> bootstrap-setup-wsl.cmd -> bootstrap-wslN.cmd -> bootstrap-run.cmd -> bootstrap-init -> bootstrap -> inst
set wsl=1
%~dp0%bootstrap-setup-wsl.cmd