@echo off
REM bootstrap.cmd [1|2] - run bootstrap-init
REM - autounattend.xml -> ** bootstrap.cmd ** -> bootstrap-init -> bootstrap -> inst
REM - 1: run the bootstrap process for WSL 1 (no nested virtualization, Mac virtual machines)
REM - 2: run the bootstrap process for WSL 2 (requires Hyper-V nested virtualization)

REM variables
set dir=%~dp0
set dist=Ubuntu
set distUser=%USERNAME%
rem set distUnc=\\ender.hagerman.butare.net\public
rem set distImage=documents\data\install\platform\linux\wsl\image\ubuntu\default.tar.gz

set wsl=%1
if not DEFINED wsl set wsl=2

REM
REM validate
REM

if %wsl% == 1 (
	rem
) else if %wsl% == 2 (
	rem
) else (
	echo WSL version '%wsl%' is not valid (must be 1 or 2^)
	pause
	exit /b 1
)

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
	>> "%f%" echo if not exist %unc% net use %unc% /user:%distUser%
	>> "%f%" echo %dir%bootstrap.cmd
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
