#!/bin/bash

# Initialization
set SleepTaskIdleTime=30
set SleepTaskWaitForResume=60

set shutdown=shutdown.exe

# Arguments
if %@IsHelpArg[%@UnQuote[%1]] == 1 goto usage

# Arguments

set command=config
iff %# != 0 then
	set command=%1
	shift
endiff

if not IsLabel %command goto usage

gosub %command
quit %_?

:usage
text
usage: power [config|InstallTrigger|log](config)
  hibernate enable|disable
  SleepTask create|delete|enable|disable|sleep
	WakeTask create|delete|enable|disable|sleep
	FixWake|FixSleep [info]
	
  reboot|hibernate|shutdown|sleep [force] [<host>|<os>|all](local)
    forces - force the action, does not check if it is allowed
    on|off - turn hibernate on or off

  OnEvent|ResumeEvent|OffEvent|SuspendEvent [force]
    Run power management events, optionally forcing network updates
endtext
quit 1

# WakeTask  - a task which will run  when the computer wakes up
:WakeTask

if %# != 1 goto usage

set WakeTaskCommand=WakeTask%1
shift

iff not IsLabel %WakeTaskCommand goto usage

gosub %WakeTaskCommand

return %_?

return

:WakeTaskCreate
SCHTASKS /Create /TN test2 /TR ls.exe /SC ONEVENT /EC System /MO "*[System[Provider[@Name='Microsoft-Windows-Power-Troubleshooter'] and EventID=1]]"
return

# SleepTask - a task which will sleep the computer when idle.  
:SleepTask

if %# != 1 goto usage

set SleepTaskCommand=SleepTask%1
shift

iff not IsLabel %SleepTaskCommand goto usage

gosub %SleepTaskCommand

return %_?

return

# Scheduled sleep task
# When the computer is resumed, the scheduled sleep task will run again if a key is not pressed, so the 
# following logic will not sleep the host again if there was a recent resume.
:SleepTaskSleep

set host=%ComputerName

# Sleep to allow the system to resume and for the service to enter the running state
echo Sleep task is waiting %SleepTaskWaitForResume seconds for possible resume...
sleep %SleepTaskWaitForResume%s

# Check if the system was resumed event in the last 5 minutes 

# The event log text that indicates the system has resumed.   Verified on Vista.  The detail "The system has resumed from sleep." is not available from psloglist.
set EventSource=Microsoft-Windows-Power-Troubleshooter
set EventText=Microsoft-Windows-Power-Troubleshooter

# If we have resumed withing SleepTaskIdleTime minutes then do not sleep again.
psloglist -AcceptEula system -s -m %SleepTaskIdleTime -o "%EventSource" |& egrep -i "%EventText" >& nul:
iff %? == 0 then 
  echo Ignoring sleep task since the last power event recently occurred.
  return 1
endiff

gosub PowerOffPrepare
if %_? != 0 return %_?

# Issue the sleep detached so the command finishes in task scheduler
echo Issuing sleep task sleep...
detach (sleep 15s & *reboot /w)

return 0

:SleepTaskDelete
SchTasks /Delete  /TN "sleep" /F >& nul:
return %?

# To monitor idle time, use this scheduled task or the AutoHotKey IdleEvent()
   
:SleepTaskCreate

gosub SleepTaskDelete

# Create sleep task - spaces are not allowed by SchTasks for the path.   Run as wsystem since wsystem account has SysInternals EULA registry key set
# issues - runs using tcc in wrong path, wsystem needs to be registered, use free version?
SchTasks /Create /RU %@SystemAccount[] /RP * /SC OnIdle /I %SleepTaskIdleTime /TN "sleep" /TR "%@sfn[%PublicDocuments\data\bin\]\tcc.exe /c SleepTaskSleep.btm"

return %?

:SleepTaskEnable
SchTasks /Change /Ru system /Tn "Sleep" /Enable
return %?

:SleepTaskDisable
SchTasks /Change /Ru system /Tn "Sleep" /Disable
return %?

:config
start /pgm powercfg.cpl
return

REM
# On / Resume Event
REM

:OnEvent
:ResumeEvent
:resume

# Arguments
set force=
iff "%1" == "force" then
	set force=force
	shift
endiff
 
if %# != 0 goto usage

echo System is preparing to resume as %UserName...

call background.btm UpdateSelected

# Resume the network (system may be on new network now)
call network.btm resume %force

echo System has resumed...

return

# 
# Off / Suspend Event
REM
:OffEvent
:SuspendEvent

echo System is preparing to suspend...

# Virtual Machine
iff %@IsVirtualMachine[] == 1 .and. exist "%programs32\VMware\VMware Tools\VMip.exe" then
  "%programs32\VMware\VMware Tools\VMip.exe" -release
endiff

echo System is suspending...

return

:InstallTrigger

iff %@IsVirtualMachine[] == 0 .and. %@IsWindowsClient[] == 1 then
  set file=%PublicDocuments\data\bin\HibernateTrigger.exe & set dest=%@PublicStartMenu[]\Programs\Startup\Hibernate Trigger.lnk & set desc=Trigger actions on computer suspend and resume. & set mode=2 & call MakeShortcut
endiff

return

:reboot
:shutdown
:sleep
:hibernate

# Enable or disable hibernation mode
iff "%command" == "hibernate" then

	switch "%1"

	case "enable"
		PowerCfg.exe -hibernate on	
		echo Hibernation has been enabled.
		return 0

	case "disable"
		PowerCfg.exe -hibernate off
		echo Hibernation has been disabled.
		return 0
		
	endswitch

endiff

# Arguments

set force=
iff "%1" == "force" then
	set force=true
	shift
endiff

set hosts=%ComputerName
iff %# gt 0 then
	set hosts=%$
	shift
endiff

# Send the power command to all hosts
iff "%hosts" == "all" then  
	for %host in (%@FindHost[active all sleep=yes force]) gosub host
	gosub %command

# Multiple hosts
elseiff %@words[%hosts] gt 1 then
	for %host in (%hosts) gosub host
	
# Send the power command to a remote host	
elseiff "%hosts" != "%ComputerName" then 
	set host=%hosts
  gosub host

# Send the power command to the local host
else
	set host=%hosts
	gosub local
	
endiff

return %_?

:local

gosub PowerOffPrepare
if %_? != 0 return %_?

gosub Local%command
return %_?

:LocalReboot
echo Issuing reboot...
%shutdown -r -f -t 0
return %?

:LocalHibernate
echo Issuing hibernate...
*reboot /h 
return %_?

:LocalShutdown
echo Issuing shutdown...
%shutdown -s -f -t 0
return %?

:LocalSleep
echo Issuing sleep...
*reboot /w
return %_?

:host

if "%host" == "ComputerName" return

set platform=%@HostInfo[%host platform]

# Check to make sure the host is available
iff %@IsHostAvailable[%host] == 0 then
	EchoErr %host is not available.
	return 1
endiff

# Virtual machines
iff %@VmExist[%host] == 1 .and. "%command" == "sleep" then
	call VmWare run %host suspend
	return %?
endiff

# Mac OS X - requires ssh certificate on the host
iff "%platform" == "mac" then

	echo Sending %command to %host...
	ssh %host osascript -e 'tell application "System Events" to sleep'
	return %?
	
endiff

# Linux 
iff "%platform" == "linux" then
	EchoErr Cannot sleep %host (Linux sleep not supported yet).
	return %?
endiff

# Prepare windows hosts for power command

echo Preparing %host for %command...
call host prepare %host
if %? != 0 return

gosub PowerOffPrepare
if %_? != 0 return %_?

# Remote execute the command on the remote machine.  
# Some of the remote power commands do not work consistently so execute power.btm remotely.  Alternatives:
# 	start /min /pgm tcc /c RemCom \\%host "tcc /c detach power %command"
# 	start /min /pgm psshutdown -t 0 %option \\%host where option is -d (sleep)  or -h (hibernate)
# Detach batch file so tcc window closes immediately (only confirmation dialog is shown)
# In some cases, the remote execution will hang, start detached (using start) so this batch file can continue.

echo Sending %command to %host...
psexec \\%host -i tcc /c detach power %command

# tcc fails to Agile with -i
if %? != 0 psexec \\%host tcc /c detach power %command

return

:PowerOffPrepare

# Return if the sleep is always allowed
if defined force return 0

# Check if sleep is allowed on hal by checking magic IIS logs as magic is a virtual machine hosted by hal
iff "%host" == "agile" .or. "%host" == "magic" then

	set LastHit=%@ExecStr[call iis LastHit time magic]
	
	iff %@numeric[%LastHit] == 1 .and. %LastHit lt %SleepTaskIdleTime then
		echo Ignoring sleep task since the Magic web server was accessed %LastHit minutes ago (within %SleepTaskIdleTime minutes).
		echo.
		call iis LastHitUsers magic
		return 1
	endiff
	
endiff

# VMwareHostd service in VMware Server 2.0 beta stops agile from sleeping, reference http://communities.vmware.com/docs/DOC-4160#cf
iff "%host" == "agile" .and. "%command" == "sleep" then
	call service stop VMwareHostd agile
	if %? != 0 return 1
endiff

return 0

:log
call TextEdit "%PublicDocuments\data\log\power.txt"
return 0