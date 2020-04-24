@echo off

REM bootstrap a Windows system for Windows Subsystem for Linux (WSL) running a debian distribution
REM \\nas3\public\documents\data\bin\bootstrap-wsl.cmd

set user=jjbutare
set host=nas3
set data=\\%host%\public\documents\data
set dist=%data%\install\LINUX\wsl\setup\Ubuntu\CanonicalGroupLimited.Ubuntu18.04onWindows_1804.2018.817.0_x64__79rhkp1fndgsc.Appx

REM Enable Windows Subsystem for Linux - will restart
if not exist "c:\windows\system32\wsl.exe" ( 
	powershell -Command "Start-Process DISM.exe '/Online /Enable-Feature /FeatureName:Microsoft-Windows-Subsystem-Linux' -Verb RunAs"
	pause
)

REM Install Ubuntu
if not exist "\\wsl$\Ubuntu-18.04\home\%USERNAME%" (
	start %dist%
	pause
)

REM Run bootstrap
copy %data%\bin\bootstrap-wsl \\wsl$\Ubuntu-18.04\tmp
wsl bash /tmp/bootstrap-wsl %user% %host%
pause
