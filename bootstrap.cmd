@echo off
REM bootstrap.cmd [bootstrap-init options] - run bootstrap-init
REM - flow: autounattend.xml -> ** bootstrap.cmd ** -> bootstrap-init -> bootstrap -> inst
REM - variables:
REM   wsl=1|2 - run the bootstrap process for WSL 1 or 2, defaults to 2 (requires Hyper-V nested virtualization)
REM   dist=DISTRIBUTION - distribution to install, defaults to Ubuntu
REM   distUser=USER - user for the distribution, defaults to the current user (%USERNAME%).   Also used for the UNC connection to the current directory
REM   distUnc=UNC - optional location of the distribution image, i.e. \\ender.butare.net\public
REM   distImage=IMAGE - optional distribution image, i.e. documents\data\install\platform\linux\wsl\image\ubuntu\default.tar.gz

REM variables
set dir=%~dp0
if not DEFINED wsl set wsl=2
if not DEFINED dist set dist=Ubuntu
if not DEFINED distUser set distUser=%USERNAME%
rem if not DEFINED distUnc set distUnc=\\ender.butare.net\public
rem if not DEFINED distImage set distImage=documents\data\install\platform\linux\wsl\image\ubuntu\default.tar.gz

REM unc - the current directory is a UNC, but we need to remove the trailing slash or net use will error
set unc=%dir:~0,-1%  

REM
REM create bootstrap.cmd on the Desktop
REM 

set desktop=%HOMEDRIVE%%HOMEPATH%\OneDrive\Desktop
if not exist "%desktop%" set desktop=%HOMEDRIVE%%HOMEPATH%\Desktop
set f=%desktop%\bootstrap.cmd

if not exist "%f%" (
	> "%f%" echo @echo off
	>> "%f%" echo echo ************************* bootstrap.cmd *************************
	>> "%f%" echo set dist=%dist%
	>> "%f%" echo set distUser=%distUser%
	>> "%f%" echo set distUnc=%distUnc%
	>> "%f%" echo set distImage=%distImage%
	>> "%f%" echo set wsl=%wsl%
	>> "%f%" echo set verbose=%wsl%
	>> "%f%" echo if not exist %unc% net use %unc% /user:%distUser%
	>> "%f%" echo %dir%bootstrap.cmd %verbose% %*
)

REM
REM install WSL
REM 

wsl --status > nul 2>&1
if not %ErrorLevel% == 0 (
	echo Installing WSL...
	wsl --install --no-distribution --web-download
	echo WSL is installed, system will reboot.
	pause
	shutdown /r /t 0
	exit /b 1
)

wsl --set-default-version %wsl% > nul 2>&1
if not %ErrorLevel% == 0 (
	wsl.exe --set-default-version %wsl%
	echo Unable to set the WSL default version to '%wsl%'.
	pause
	exit /b 1
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

if not exist \\wsl.localhost\%dist%\tmp (
	echo Unable to create the distribution
	pause
	exit /b 1
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
