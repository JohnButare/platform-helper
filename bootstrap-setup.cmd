@echo off
REM bootstrap-setup.cmd - create and run bootstrap.cmd on the users Desktop to run the bootstrap process
REM - bootstrap-setup.cmd -> bootstrap.cmd -> bootstrap-wslN.cmd -> bootstrap-init -> bootstrap -> inst

REM variables
set pwd=%~dp0
set args=%*
rem set args=%* -v
set wsl=2
set wslDir=C:\Users\Public\data\appdata\wsl
set dist=Ubuntu
set distUser=jjbutare
rem set distUser=%USERNAME%
rem set distUnc=\\ender.hagerman.butare.net\public
rem set distImage=documents\data\install\platform\linux\wsl\image\ubuntu\default.tar.gz

REM create bootstrap.cmd on the Desktop to run manually if needed
set file=%HOMEPATH%\Desktop\bootstrap.cmd
> %file% echo @echo off
>> %file% echo echo ************************* bootstrap.cmd *************************
>> %file% echo set pwd=%pwd%
>> %file% echo set args=%args%
>> %file% echo set wsl=%wsl%
>> %file% echo set dist=%dist%
>> %file% echo set distUser=%distUser%
>> %file% echo set distUnc=%distUser%
>> %file% echo set distImage=%distUser%
>> %file% echo %pwd%bootstrap-wsl%wsl%.cmd

REM run bootstrap.cmd after reboot
copy %file% "%APPDATA%\Microsoft\Windows\Start Menu\Programs\Startup"

REM run bootstrap.cmd
echo.
%file%
