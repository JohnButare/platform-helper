@echo off
REM bootstrap-run.cmd - run bootstrap-init
REM - autounattend.xml -> bootstrap-setup-wslN.cmd -> bootstrap-setup-wsl.cmd -> bootstrap-wslN.cmd -> ** bootstrap-run.cmd ** -> bootstrap-init -> bootstrap -> inst

REM variables
set dir=%~dp0

REM
REM distribution
REM

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

:done
echo.
echo Bootstrap completed successfully.
pause






