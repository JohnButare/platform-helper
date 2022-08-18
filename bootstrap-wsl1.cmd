@echo off
REM bootstrap-wsl1.cmd - bootstrap a Windows sytem using WSL 1 (if Hyper-V virtualization is not available)
REM bootstrap-setup.cmd -> bootstrap-wsl1.cmd -> bootstrap-init -> bootstrap -> inst

REM dist - name of the distribution to install
set dist=Ubuntu

REM user - the WSL distribution user
rem set user=%USERNAME%
set user=jjbutare

REM args - bootstrap-init arguments
set args=-vvvv %*

REM bin - the location of the bin directory, if unset find it
rem set bin=//StudyLaptop.hagerman.butare.net/system/usr/local/data/bin
set bin=//ender.hagerman.butare.net/system/usr/local/data/bin
rem set bin=//pi2.hagerman.butare.net/root/usr/local/data/bin
rem set bin=//StudyMonitor.hagerman.butare.net/root/usr/local/data/bin:22

REM install - installation directory, if unset find it
set install=//10.10.101.67/public/documents/data/install
set install=//ender.hagerman.butare.net/public/documents/data/install

REM variables
set pwd=%~dp0%

REM if the distribution exists then run the bootstrap
if exist "\\wsl.localhost\%dist%\home" goto bootstrap

REM install WSL 
wsl.exe —set-default-version 1
wsl.exe —install —distribution Ubuntu

REM run the bootstrap
:bootstrap
echo Running bootstrap...
copy %pwd%bootstrap-init \\wsl.localhost\%dist%\tmp
copy %pwd%bootstrap-config.sh \\wsl.localhost\%dist%\tmp
wsl --user root -- sudo chmod ugo+rwx /tmp/bootstrap-init /tmp/bootstrap-config.sh
wsl --user %user% /tmp/bootstrap-init %bin% %install% %args%
if errorlevel 1 goto bootstrap

pause