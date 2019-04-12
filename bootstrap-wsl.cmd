@echo off

REM bootstrap a Windows system for Windows Subsystem for Linux (WSL) running a debian distribution

set user=jjbutare
set host=nas1
set data=\\%host%\public\documents\data
set dist=%data%\install\LINUX\Ubuntu\windows\CanonicalGroupLimited.Ubuntu18.04onWindows_1804.2018.817.0_x64__79rhkp1fndgsc.Appx

set r=yes
set /p r="Update windows? (%r%)? "
if "%r%" == "yes" (
	cmd /c start ms-settings:windowsupdate
)

set r=yes
set /p r="Install Windows Subsystem for Linux? (%r%)? "
if "%r%" == "yes" (
	DISM.exe /Online /Enable-Feature /FeatureName:Microsoft-Windows-Subsystem-Linux
)

set r=yes
set /p r="Install Ubuntu? (%r%)? "
if "%r%" == "yes" (
	start %dist%
)

set r=yes
set /p r="Bootstrap? (%r%)? "
if "%r%" == "yes" (
	copy %data%\bin\bootstrap-wsl \\wsl$\Ubuntu-18.04\tmp
	wsl bash /tmp/bootstrap-wsl %user% %host%
	pause
)
