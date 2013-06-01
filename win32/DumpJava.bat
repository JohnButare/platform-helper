@echo off
rem This batch file can collect thread dumps from a java program installed as a service.
rem You'll need to add these command line options to the invocation of Java
rem
rem -Xdebug -Xrunjdwp:transport=dt_socket,server=y,suspend=n,address=5432
rem
rem Caveats: 
rem     Depends upon your version of Java
rem     JAVA_HOME needs to be set
rem     port numbers need to match
rem

set TEMPINPUT=tdinput.txt
echo suspend >%TEMPINPUT%
echo where all >>%TEMPINPUT%
echo resume >>%TEMPINPUT%
echo quit >>%TEMPINPUT%

for %%a in (1,2,3) do call :WORK %%a

del %TEMPINPUT%

goto END

:WORK

FOR /F "tokens=1-4 delims=/ " %%i in ('date/t') do set d=%%l%%j%%k@
FOR /F "tokens=1-9 delims=:. " %%i in ('time/t') do set t=%%i%%j%%k%%l
set FILENAME=threaddump%1-%d%%t%.log
echo Collecting thread dump (%FILENAME%)...

set JAVA_HOME=C:\j2sdk1.4.2_05
"%JAVA_HOME%\bin\jdb" -connect com.sun.jdi.SocketAttach:hostname=localhost,port=5432 <%TEMPINPUT% >%FILENAME%
echo First thread dump complete.

if (%1) == (3) goto END

echo.
echo Wait one minute before continuing...
pause
echo.

:END
