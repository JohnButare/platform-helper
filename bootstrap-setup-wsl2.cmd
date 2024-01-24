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

REM optionally use a WSL image
rem set distUser=%USERNAME%
rem set distUnc=\\ender.hagerman.butare.net\public
rem set distImage=documents\data\install\platform\linux\wsl\image\ubuntu\default.tar.gz

REM set unc - the current directory is a UNC, but we need to remove the trailing slash or net use will error
set unc=%pwd:~0,-1%  

REM create bootstrap.cmd on the Desktop to run manually if needed
set file=%HOMEDRIVE%%HOMEPATH%\Desktop\bootstrap.cmd
if exist %file% del %file%

>> %file% echo @echo off
>> %file% echo echo ************************* bootstrap.cmd *************************
>> %file% echo set pwd=%pwd%
>> %file% echo set args=%args%
>> %file% echo REM set args=%args% -v
>> %file% echo set wsl=%wsl%
>> %file% echo set dist=%dist%
>> %file% echo set distUser=%distUser%
>> %file% echo set distUnc=%distUnc%
>> %file% echo set distImage=%distImage%
>> %file% echo net use * %unc% /user:wiggin open
>> %file% echo %pwd%bootstrap-wsl%wsl%.cmd

REM put bootstrap.cmd on then desktop to run manually
copy %file% "%USERPROFILE%\Desktop"

REM run bootstrap
%file%
