@echo off
REM bootstrap.cmd [1|2] - run bootstrap-init
REM - autounattend.xml -> ** bootstrap.cmd ** -> bootstrap-init -> bootstrap -> inst
REM - 1: run the bootstrap process for WSL 1 (no nested virtualization, Mac virtual machines)
REM - 2: run the bootstrap process for WSL 2 (requires Hyper-V nested virtualization)

REM variables
set dir=%~dp0
set wsl=%1
if not DEFINED wsl set wsl=2
set dist=Ubuntu
set distUser=jjbutare
rem set distUser=%USERNAME%

REM distribution image - optional
rem set distUnc=\\ender.hagerman.butare.net\public
rem set distImage=documents\data\install\platform\linux\wsl\image\ubuntu\default.tar.gz

REM create and run bootstrap.cmd on the users Desktop

REM distribution

REM unc - the current directory is a UNC, but we need to remove the trailing slash or net use will error
set unc=%dir:~0,-1%  

REM create bootstrap.cmd on the Desktop
set f=%HOMEDRIVE%%HOMEPATH%\Desktop\bootstrap.cmd
> "%f%" echo @echo off
>> "%f%" echo echo ************************* bootstrap.cmd *************************
>> "%f%" echo set dist=%dist%
>> "%f%" echo set distUser=%distUser%
>> "%f%" echo set distUnc=%distUnc%
>> "%f%" echo set distImage=%distImage%
>> "%f%" echo if not exist %unc% net use %unc% /user:%distUser%
>> "%f%" echo %dir%bootstrap-cmd%wsl%.cmd

REM
REM install WSL
REM 

REM make WSL 1 the default version
if %wsl% == 1 if not exist "\\wsl.localhost\%dist%\home" (
		wsl.exe --set-default-version 1

REM install WSL 2
) else if %wsl% == 2 if not exist "\\wsl.localhost\%dist%\home" (
	wsl --set-default-version 2 > nul 2>&1
	if not %ErrorLevel% == 0 (
		wsl --install --no-distribution --web-download
		shutdown /r /t 0 & exit
	)
)

REM
REM distribution
REM

:distribution

if not exist \\wsl.localhost\%dist%\tmp (

	REM mount UNC
	if defined distUnc (
		if not exist z:\ net use z: %distUnc%
		set distImage=z:\%distImage%
	)

	REM import or download
	if defined distImage (
		wsl --import %dist% %wslDir% %distImage%	
	) else (
		echo.
		echo Once the user account is created, exit the shell...
		wsl --install --distribution %dist%	--web-download
	)

)

REM
REM bootstrap
REM
:bootstrap
echo.
echo Preparing bootstrap files...
copy /Y %dir%bootstrap-init \\wsl.localhost\%dist%\tmp
copy /Y %dir%bootstrap-config.sh \\wsl.localhost\%dist%\tmp
wsl -- ls /tmp/bootstrap-init > nul & if errorlevel 1 goto bootstrap-recovery
wsl --user root -- sudo chmod ugo+rwx /tmp/bootstrap-init

echo.
echo Running bootstrap-init...
wsl --user %distUser% /tmp/bootstrap-init %*
if errorlevel 2 ( wsl.exe --shutdown & goto bootstrap )
if errorlevel 1 goto bootstrap
goto done

:bootstrap-recovery
echo Unable to create bootstrap files, recovering...
wsl.exe --shutdown
start /min wsl
wsl sleep 5
goto bootstrap

:bootstrap-error
echo Unable to bootstrap...
pause
exit /b 1

:done
echo.
echo Bootstrap completed successfully.
pause
exit /b 0
