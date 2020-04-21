@echo off

REM bootstrap a Windows system for Windows Subsystem for Linux (WSL) running a debian distribution

set user=jjbutare
set host=nas3
set data=\\%host%\public\documents\data
set dist=%data%\install\LINUX\wsl\setup\Ubuntu\CanonicalGroupLimited.Ubuntu18.04onWindows_1804.2018.817.0_x64__79rhkp1fndgsc.Appx

set r=n
set /p r="Update windows? (%r%)? "
if "%r%" == "y" (
	cmd /c start ms-settings:windowsupdate
)

set r=n
set /p r="Install Windows Subsystem for Linux? (%r%)? "
if "%r%" == "y" (
	DISM.exe /Online /Enable-Feature /FeatureName:Microsoft-Windows-Subsystem-Linux
)

set r=n
set /p r="Install Ubuntu? (%r%)? "
if "%r%" == "y" (
	start %dist%
	echo NOTE: system must be rebooted or files will not be copied correctly
	pause
	shutdown /t 0 /r
	pause
)

set r=y
set /p r="Bootstrap? (%r%)? "
if "%r%" == "y" (
	copy %data%\bin\bootstrap-wsl \\wsl$\Ubuntu-18.04\tmp
	wsl bash /tmp/bootstrap-wsl %user% %host%
	pause
)
