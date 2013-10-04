@echo off
SetLocal

REM Initialze OS variables before functions are defined
if "%1" == "FindDirsInit" then
  shift
  gosub FindDirsInit
  quit 0
endif

REM Initialize
set DwmService=uxsms
set ErrorReportingService=WerSvc
set BootIniFile=c:\boot.ini

gosub initialize

REM Recent files 
REM - WindowsRecent contains recently used Windows files and pinned items

set WindowsRecent=%AppData\Microsoft\Windows\Recent
if not IsDir "%WindowsRecent" set WindowsRecent=%UserProfile\Recent

set OfficeRecent=%AppData\Microsoft\Office\Recent
if not IsDir "%OfficeRecent" set OfficeRecent=%UserProfile\Application Data\Microsoft\Office\Recent

REM Arguments
if %@IsHelpArg[%@UnQuote[%1]] == 1 goto usage

set command=start
if %# gt 0 then
  set command=%1
  shift
endif

if not IsLabel %command goto usage

REM Run command
gosub %command
quit %_?

:usage
text 
usage: os <command>
  dwm|ErrorReporting start|stop|restart|status: Desktop Window Manager
  activation status|extend: Windows Activation
  beep [enable|disable|status](status): PC speaker beep
  bluetooth [devices|properties](devices)
  environment [edit|editor|set](editor): system environment variables
  gadget [cd|show](show): Microsoft Gadgets
  path [show|edit|editor|update [AllUsers]](show)
  FindDirs [-help] [show|<SystemDrive>](%SystemDrive) [<UserName>](%_WinUser)
  hibernate enable|disable
  RemoteBin <HostName>: Change to the bin folder on the remote host
  template|TemplateSetup: shell templates	
  uac [config|enable|disable|status|StatusSilent|
    SecureDesktop enable|disable: user account control
  	AdminShare enable|disable: enable or enable $ shares
	
  explorer: StartMenuIcons, recycle
	features: DisabeAlternativeUserInput|DisableIndexingService|DisableMsnMessenger|DisableStrictNameChecking
  folder: QuickLaunch|UserStartMenu|PublicStartMenu|SendTo
  hardware: DeviceManager|FindNewHardware|scanner|DeviceLog
  index: index start|stop|demand
  performance counters: PerfCount PerfFix PerfMon
  policies: GroupPolicyEditor|LocalSecurityPolicy
  programs: programs|WindowsComponents|CleanupPrograms
	malware: Defender|SecurityEssentials
  sound: volume|sound
  updates: AutomaticUpdates|update|RemoveHotfixBackup|ServicePack
  other: 
    init|appearance|autoruns|cleanup|CleanupRecentlyUsed|credentials|
    computer|ComputerManagement|config|ControlPanel|
    defrag|desktop|DisableReadyBoost|DisableSuperFetch|DiskManagement|
    EditBootInit|Flip3D|MobilityCenter|name|PerformanceMonitor|
    Remote|Reports|ReportArchive|SystemProperties|SystemProtection|
    task|OfficeRecent|WindowsRecent|ScreenSaver|MyComputer
    optional|reliability|ResourceMonitor|SyncTime|VirtualMemory
    FileHistory		
endtext
quit 1

:FileHistory
start /pgm control.exe /name Microsoft.FileHistory
return

:CheckElevated

if %@IsElevated[] == 0 then
	echo This operation requires elevation.
	quit 1
endif

return 0

:desktop
"%WinDir\system32\rundll32.exe" shell32.dll,Control_RunDLL desk.cpl,,0
return

:template
cde %AppData\Microsoft\Windows\Templates
EndLocal /d
return

:TemplateSetup
set SetupFiles=%@path[%_batchname]...\setup
call registry import "%SetupFiles\ShellNew.reg"
copy "%SetupFiles\template.*" "%WinDir\ShellNew"
return

:cleanup

REM Run CCleaner if elevated - cleans most of what CleanupManager does and is much faster
if %@IsElevated[] == 1 then
	CCleaner.exe /auto
endif

echo Cleaning Windows Error Reporting...
set dir=%LocalAppData\Microsoft\Windows\WER

if %@DirSize[m, "%dir"] gt 20 then
	echo Clean Windows Errror Reporting files by checking for solutions...
	echo - Check for new solutions
	echo - See problems to check, Select all, Check for solutions
	call os reports
	pause
endif

REM Windows Photo Gallery Orginal Images
echo Cleaning Windows Photo Gallery original images...
set dir=%LocalAppData\Microsoft\Windows Photo Gallery\Original Images

if %@DirSize[m, "%dir"] gt 50 then
	echo - Delete or preserve original images (this folder contains the images prior to editing)
	start /pgm explorer "%dir"
	pause
endif

return

:CleanupRecentlyUsed

echos Cleaning recently used document list...
call DelDir contents NoHeader "%WindowsRecent" "%OfficeRecent"
echo done

return

:update

REM Microsoft Update disabled on Intel hosts
if %@IsIntelHost[] == 1 return

echo Starting Microsoft Update...

REM Windows Update - Vista
if exist %WinDir\system32\wuapp.exe then
  start /pgm %WinDir\system32\wuapp.exe

REM Microsoft Update - x64
elseif exist "%WinDir\SysWOW64\muweb.dll" then
  start /pgm rundll32 %WinDir\SysWOW64\muweb.dll,LaunchMUSite

REM Microsoft Update - x86
elseif exist "%WinDir\system32\muweb.dll" then
  start /pgm rundll32 %WinDir\system32\muweb.dll,LaunchMUSite

REM Windows Update - installs Microsoft Update
elseif exist "%WinDir\system32\wupdmgr.exe" then
  start /pgm "%WinDir\system32\wupdmgr.exe"

else

	call InternetExplorer http://www.update.microsoft.com/microsoftupdate
endif

REM Update other programs
if %@OnNetwork[Intel] == 0 UpdateChecker.exe

return

:ServicePack
REM Optional options to Start unattended with no dialogs : /U /N

set SpKey=HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\CurrentBuildNumber
set SpText=
set SpExe=

switch %_WinVer

REM Windows 7 and Windows Server 2008 R2
case 6.1 
	set SpExe=Microsoft\Windows 7\update\windows6.1-KB976932-X64.exe
	set SpText=7601

REM Vista and Windows Server 2008
case 6.0
	set SpExe=Microsoft\Vista\sp2\setup.exe
	set SpText=6002
		
REM Windows Server 2003
case 5.2
	set SpExe=Microsoft\Server 2003\update\WindowsServer2003-KB914961-SP2-%@OsArchitecture[]-ENU.exe
	set SpKey=HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\CSDVersion
	set SpText=Service Pack 2

REM Windows XP
case 5.1
  set SpExe=Microsoft\XP\sp3\WindowsXP-KB936929-SP3-x86-ENU.exe
	set SpKey=HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\CSDVersion
	set SpText=Service Pack 3

endswitch

REM Install the Service Pack  if it is not already installed.  
if "%SpExe" != "" then

	if "%@RegGet64["%SpKey"]" != "%SpText" then

		REM Find the executable
		call FindPublicDoc "data\install\%SpExe"
		if %_? != 0 return %_?

		start /pgm "%file"
		pause
	
	endif
endif

REM Compress service pack files (Vista?)
if exist "%WinDir\ServicePackFiles" then
	if defined vm then
		call DelDir "%WinDir\ServicePackFiles"
  else
		call ask `Compress service pack files?` n 5
		if %? == 1 then
			call CompactDir "%WinDir\ServicePackFiles"
		endif
	endif
endif

return

:RemoteBin
SetLocal

REM Arguments
if %# != 1 goto usage
set HostName=%1
shift

call os FindDirs %HostName
if %? != 0 return %?

cde %_PublicBin
EndLocal /d

return 0

:FindDirsUsage

text
Find OS directories for a local or remote host and user
Input:
- [SystemDrive](%SystemDrive) - drive letter, UNC path, or hostname
- [UserName](%_WinUser) - name of the user

Output:
endtext
echo %vars

quit 1


:FindDirsDefaults

set vars=_layout _sys _data _windows _users _system _system32 _system64 _programs _programs32 _programs64 _PublicHome _PublicDocuments _PublicData _PublicBin _user _UserFound _UserHome _UserSysHome _UserDocuments _UserData _UserBin _UserFolders _CloudDocuments _CloudData _ProgramData _ApplicationData _LocalCode

for var in (%vars) (
	unset %var
)

set _sys=%SystemDrive
set _data=%@if[ IsDir d:\Users ,d:,%SystemDrive]
set _user=%_WinUser

return

REM FindDirsInit - find OS dirs for this Take Command instance.  Only called from TcStart.btm only 
REM to initialize variables used by other batch files.
:FindDirsInit

gosub FindDirsDefaults
gosub FindDirsWorker

REM Set the core operating system variables (without _)
set ExportVars=
for var in (%vars) (
	set ExportVar=%@right[-1,%var]
	set %ExportVar=%[%var]
	set ExportVars=%ExportVars %ExportVar
)

EndLocal %ExportVars

return

REM FindDirs [-help] [SystemDrive](%SystemDrive) [UserName](%_WinUser) - find OS dirs on a diferent host
:FindDirs

REM Initialize
gosub FindDirsDefaults
set show=

REM Arguments

if %@IsHelpArg[%@UnQuote[%1]] == 1 goto FindDirsUsage

REM SystgemDrive argument - drive letter, UNC path, or hostname
if %# != 0 then
	
	REM Drive letter or UNC path
	if IsDir "%1" then
    set _sys=%1
		set _data=%1
		shift
		
	REM Hostname
	elseif %@IsHostAvailable[%1] == 1 then
		set host=%1
		shift
  endif
	
endif

REM UserName argument
if %# != 0 .and. "%1" != "show" then
  set _user=%@UnQuote[%1]
  shift
endif

if "%1" == "show" then
	set show=true
	shift
endif

if %# != 0 goto FindDirsUsage

if "%host" == "butare.net" then
	set _sys=
	set _data=
	set _PublicHome=\\%host@ssl@5006\public
	gosub SetPublicDirs
	
	set _UserFound=%_user
	set _UserHome=\\%host@ssl@5006\home
	set _UserSysHome=%_UserHome
	set _UserDocuments=%_UserHome\documents
	gosub SetUserDirs

elseif IsDir \\%host\c$ then
	set _sys=\\%host\c$
	set _data=\\%host\c$
	if IsDir \\%host\d$\Users set _data=\\%host\d$

	gosub FindDirsWorker
	
elseif IsDir \\%host\public then
	set _sys=
	set _data=
	set _PublicHome=\\%host\public
	gosub SetPublicDirs
	
	if IsDir \\%host\home then
		set _UserFound=%_user
		set _UserHome=\\%host\home
		set _UserSysHome=%_UserHome
		set _UserDocuments=%_UserHome\Documents
		gosub SetUserDirs
	endif
	
else
	EchoErr Unable to find %host directories
	return 1
	
endif

if defined show then
	for var in (%vars) (
		if "%[%var]" != "" then
			echo %var=%[%var]
		endif
	)
endif

EndLocal %vars

return

REM FindDirsWorker - find OS directories for the current or a remote host, input _sys, _data, _user
:FindDirsWorker

REM Windows directory
if "%_sys" == "%SystemDrive" then
	set _windows=%WinDir
elseif IsDir "%_sys\Windows" then
  set _windows=%_sys\Windows
elseif IsDir "%_sys\WinNt" then
  set _windows=%_sys\WinNt
else
  EchoErr Unable to locate the windows folder on %_sys.
  quit 1
endif

REM User functions are not available yet, so use environment variables to determin architecture
set OsArchitecture=%@if[ %_x64 == 1 .or. %_wow64 == 1 ,x64,x86]

REM Programs - programs always refers to c:\Program Files.  Under x64, ProgramFiles refers to c:\Program Files (x86) for x86 applications
set _programs32=%_sys\Program Files%@if[ %OsArchitecture == x64 , (x86)]
set _programs64=%_sys\Program Files
set _programs=%_programs64

set _system32=%@if[ %OsArchitecture == x64 ,%_windows\SysWow64,%_windows\system32]
set _system64=%_windows\system32
set _system=%_system64

REM User directories for new (\Users) or legacy (\Documents and Settings, pre-Vista) clients
if IsDir "%_sys\Users" then
	set _layout=new
	set _users=%_data\Users	
	
	gosub FindUserHome

	set _PublicHome=%_users\Public
	
	if "%_user" == "Public" then
		set _UserFolders=Documents Downloads Music Pictures "Recorded TV" Videos
	else
		set _UserFolders=Contacts Desktop Documents Downloads Favorites Links Music Pictures "Saved Games" Searches Videos 
		set _UserFolders=%_UserFolders Dropbox "Google Drive" 
	endif
	
	set _UserDocuments=%_UserHome\Documents
	set _ProgramData=%_sys\ProgramData
	set _ApplicationData=%_UserSysHome\AppData\Roaming

elseif IsDir "%_sys\Documents and Settings" then
  set _layout=legacy
	set _users=%_data\Documents and Settings
	
	gosub FindUserHome
	
	set _public=%@if[ "%user" == "All Users" ,true,]
	set _PublicHome=%_users\All Users
	
	set _UserFolders="My Documents" Desktop Favorites
	set _UserDocuments=%_UserHome\My Documents
	set _ProgramData=%_PublicHome\Application Data
	set _ApplicationData=%_UserSysHome\Application Data
	
else
  EchoErr Unable to locate user folders on %_sys.
	quit 1
endif

REM Use the user bin folder from the batch directory UserBin folder if one is present (portable media)
if  IsDir "%TcStartDir\UserBin" then
  set _UserBin=%TcStartDir\UserBin
endif

gosub SetPublicDirs
gosub SetUserDirs
set _LocalCode=%_sys\Projects

return

:SetPublicDirs
set _PublicDocuments=%_PublicHome\documents
set _PublicData=%_PublicDocuments\data
set _PublicBin=%_PublicData\bin
return

:SetUserDirs
set _CloudDocuments=%_UserHome\Dropbox
set _CloudData=%_CloudDocuments\data
set _UserData=%_UserDocuments\data
set _UserBin=%_UserData\bin
return

:FindUserHome

set u=%_user

if not IsDir "%_users\%u" then
  EchoErr Unable to locate user %u%'s home folder on %_data.
  quit 1
endif

set _UserFound=%u
set _UserHome=%_data\%@FileName[%_users]\%u
set _UserSysHome=%_sys\%@FileName[%_users]\%u

return

:task
call task manager
return

:WindowsComponents
if IsFile "%system\sysocmgr.exe" then
	start /pgm "%system\sysocmgr.exe" /y /i:%system\sysoc.inf
else
	echo - Turn Windows features on or off
	call os programs
endif
return

:programs
start /pgm "%WinDir\system32\rundll32.exe" %WinDir\system32\shell32.dll,Control_RunDLL "%WinDir\system32\appwiz.cpl",Add or Remove Programs
return

:CleanupPrograms

REM Add Remove Programs 
gosub programs
pause

REM Windows installer cleanup utilility - http://support.microsoft.com/?kbid=290301
start /pgm msicuu
pause

REM Clean Office programs
call office CleanInstall

return

:RemoveHotfixBackup

REM Return if there are no hotfixes to remove
if "%@FindFirst[%WinDir\$NtUninstall*]" == "" return

REM Check if user wants to remove hotfixes
call ask `Remove hotfixes?` n
if %? == 0 return

REM Automated removal
start /pgm xp_remove_hotfix_backup
pause

REM Remove remaining hotfixes
echos Cleaning hotfixes...
call DelDir NoHeader "%WinDir\$NtUninstall*"
echo ...done

return

:index

set ServiceName=WSearch

if %@ServiceExist[%ServiceName] == 0 return 1

set command=options
if %# == 1 then
	set command=%1
	shift
endif

if %# != 0 .or. not IsLabel Index%command goto usage

gosub Index%command

return %_?

:IndexOptions
start /pgm "C:\Windows\system32\rundll32.exe" C:\Windows\system32\shell32.dll,Control_RunDLL "C:\Windows\System32\srchadmin.dll",Indexing Options
return

:IndexStart
:IndexStop
:IndexRestart
:IndexDemand
call service.btm %command %ServiceName
return

:computer
start /pgm explorer ::{20D04FE0-3AEA-1069-A2D8-08002B30309D}
return

:DeviceManager
REM In XP, DevMgmt.msc not found by msc in path, so search for it here.
start /pgm mmc %@quote[%@search[DevMgmt.msc]]
return

:DeviceLog
call TextEdit.btm "%WinDir\inf\setupapi.dev.log"
return

:FindNewHardware 
devcon rescan
return

:LocalSecurityPolicy
if %_WinVer gt 5.1  then
	start /pgm mmc secpol.msc /s
endif
return

:GroupPolicyEditor
if %_WinVer gt 5.1  then
	start /pgm mmc gpedit.msc
endif
return

:SecurityCenter 
if "%@search[wscui.cpl]" != "" then
  start /pgm wscui.cpl
endif
return

:volume

if "%@search[SndVol.exe]" != "" then
	start /pgm SndVol.exe
elseif "%@search[SndVol32.exe]" != "" then
	start /pgm SndVol32.exe
endif

return

:sound
start /pgm rundll32.exe %WinDir\system32\shell32.dll,Control_RunDLL "%WinDir\system32\MMSYS.CPL",@0
return

:VirtualMemory
:PageFile
echo Performance Settings, Advanced, Virtual Memory, Change
call os SystemProperties 3
return %?

:SystemProtection
call os SystemProperties 4
return %?

:Remote
call os SystemProperties 5
return %?

:SystemProperties

REM Ensure the x64 SysDm.cpl is loaded (otherwise Hardware and System Protection tabs are missing)
option //Wow64FsRedirection=No

set tab=%1

if "%tab" == "" then
	start /pgm "%WinDir\system32\rundll32.exe" /d %WinDir\system32\shell32.dll,Control_RunDLL SYSDM.CPL
else
	start /pgm "%WinDir\system32\rundll32.exe" /d %WinDir\system32\shell32.dll,Control_RunDLL SYSDM.CPL,,%tab
endif

REM Under Vista+ the window comes up in the background, so restore it
sleep 1
activate "System Properties" restore >& nul:

return

:AutomaticUpdates

if %@IsNewOs[] == 1 then
	start /pgm %WinDir\system32\wuapp.exe
else
	call os SystemProperties 5
endif

return

:QuickLaunch
cde "%QuickLaunch"
return 0

:UserStartMenu
cde "%usm"
return 0

:SendTo
cde "%@SendTo[]"
return 0

:PublicStartMenu
cde "%psm"
return 0

:dwm
:ErrorReporting

set service=%@EvalVar[%command%Service]

REM DWM is on windows 6 and up
if "%command" == "%dwm" .and. %_WinVer lt 6.0 return

if "%1" == "" then
  set command=start
else
  set command=%1
  shift
endif

if not IsLabel Service%command goto usage

gosub Service%command

return %_?

:ServiceStatus
echo %@ServiceState[%service]
return

:ServiceStart
:ServiceStop
:ServiceRestart
call service.btm %command %service
return %_?

return %_?

:beep
set key=HKCU\Control Panel\Sound\Beep

switch "%1"

case "enable"
	call registry.btm set "%key" REG_SZ Yes
	echo PC speaker beep has been enabled.

case "disable"
	call registry.btm set "%key" REG_SZ No
	echo PC speaker beep has been disabled.

case "status" .or. ""
	echo PC speaker beep is %@if["%@RegGet[%key]" == "Yes",enabled,disabled].

default
	goto usage

endfswitch

return 0

:uac

if %@IsNewOs[] == 0 return 1

set key=HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System

switch "%1"

case "config"
	call registry.btm %key
	
case "enable"
	gosub CheckElevated
	call registry.btm set "%key\EnableLUA" REG_DWORD 1
	if "%@RegGet[%key\EnableLUA]" == "0x1" then
		echo UAC has been enabled.
	else
		echo Unable to enable UAC.
	endif

case "disable"
	gosub CheckElevated
	call registry.btm set "%key\EnableLUA" REG_DWORD 0
	if "%@RegGet[%key\EnableLUA]" == "0x0" then
		echo UAC has been disabled.
	else
		echo Unable to disable UAC.
		return 1
	endif

case "status" .or. ""

	echos `UAC is `
	switch "%@RegGet[%key\EnableLUA]"
	case "0x1"
		echo enabled
	case "0x0"
		echo disabled
	default
		EchoErr status unknown
	endswitch
	
	echos `Secure desktop is `
	switch "%@RegGet[%key\PromptOnSecureDesktop]"
	case "0x1"
		echo enabled
	case "0x0"
		echo disabled
	default
		EchoErr status unknown
	endswitch

	echos `Administrative shares are `
	switch "%@RegGet[%key\LocalAccountTokenFilterPolicy]"
	case "0x1"
		echo enabled
	case "0x0"
		echo disabled
	default
		EchoErr status unknown
	endswitch
	
case "StatusSilent"
	return %@if["%@RegGet[%key\EnableLUA]" == "0x1",1,0]

case "SecureDesktop"

	switch "%2"
	
	case "enable"
		gosub CheckElevated
		call registry.btm set "%key\PromptOnSecureDesktop" REG_DWORD 1
		if "%@RegGet[%key\PromptOnSecureDesktop]" == "0x1" then
			echo The secure desktop has been enabled.
		else
			echo Unable to enable the secure desktop.
			return 1
		endif

	case "disable"
		gosub CheckElevated
		call registry.btm set "%key\PromptOnSecureDesktop" REG_DWORD 0
		if "%@RegGet[%key\PromptOnSecureDesktop]" == "0x1" then
			echo The secure desktop has been disabled.
		else
			echo Unable to disable the secure desktop.
		endif
	
	default
		goto usage
		
	endswitch
	
case "AdminShare"

	switch "%2"

	case "enable"
		gosub CheckElevated
		call registry.btm set "%key\LocalAccountTokenFilterPolicy " REG_DWORD 1
		if "%@RegGet[%key\LocalAccountTokenFilterPolicy]" == "0x1" then
			echo Administrative shares have been enabled
		else
			echo Could not enable administrative shares
		endif

	case "disable"
		gosub CheckElevated
		call registry.btm set "%key\LocalAccountTokenFilterPolicy " REG_DWORD 0
		if "%@RegGet[%key\LocalAccountTokenFilterPolicy]" == "0x0" then
			echo Administrative shares have been disabled
		else
			echo Could not disable administrative shares
		endif
	
	default
		goto usage
			
	endswitch

default
	goto usage

endswitch

return 0

:Reports
if %@IsNewOs[] == 1 then
	echo System and Security\Action Center
	call os ControlPanel
endif
return

:ReportArchive
cde "%UserProfile\AppData\Local\Microsoft\Windows\WER\ReportArchive"
return

:SecurityEssentials
call SecurityEssentials.btm start
return

:Defender
start /pgm "%programs\Windows Defender\MSASCui.exe"
return
 
:EditBootIni
 
if not exist %BootIniFile return
 
attrib -shr %BootIniFile 
 
call TextEdit %BootIniFile 
pause Press any key when done editing boot.ini...
 
attrib +shr %BootIniFile
 
reutrn 0
 
:Flip3D
RunDll32 DwmApi #105
return

:DiskManagement
REM Failed on xp with mmc, on oversoul works with and without mmc
start /pgm diskmgmt.msc
return

:bluetooth

REM Arguments
set command=devices
if %# gt 0 then
	set command=%1
	shift
endif
if not IsLabel Bluetooth%command goto usage

gosub Bluetooth%command
return %_?

return

:BluetoothProperties
start /pgm rundll32.exe shell32.dll,Control_RunDLL bthprops.cpl,,1
return

:BluetoothDevices
start /pgm rundll32.exe shell32.dll,Control_RunDLL bthprops.cpl,Bluetooth Devices
return

:ControlPanel
:control
start /pgm control.exe
return

:OfficeRecent
cde "%OfficeRecent"
return

:WindowsRecent
cde "%WindowsRecent"
return

:ScreenSaver
start /pgm RunDll32.exe shell32.dll,Control_RunDLL desk.cpl,,1
return

:MyComputer
start /pgm explorer /E,::{20D04FE0-3AEA-1069-A2D8-08002B30309D}
return

:appearance
start /pgm rundll32.exe Shell32.dll,Control_RunDLL desk.cpl,Appearance,@Appearance
return

:config
start /pgm msconfig
return

:AutoRun

REM AutoRuns cannot find winmm.dll on x64 unless started from syswow64
if "%@OsArchitecture[]" == "x64" then
	start /d%WinDir\SysWow64 /pgm autoruns
else
	start /pgm autoruns
endif

:environment

set command=editor
if %# == 1 then
	set command=%1
	shift
endif

if %# != 0 .or. not IsLabel Environment%command goto usage

gosub Environment%command

return %_?

:EnvironmentEdit
call os.btm SystemProperties 3
return %?

:EnvironmentEditor
call sudo.btm rapidee.exe
return %?

:activation

set command=ActivationStatus
if %# gt 0 then
	set command=Activation%1
	shift
endif
if not IsLabel %command goto usage

gosub %command
return %_?

:ActivationStatus

REM Grace period end date
call slmgr -xpr

REM License details
call slmgr -dli

return

:ActivationExtend

gosub ActivationStatus

REM Suspend activation count (otherwise limit of 3 extensions)
set key=HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\SL\SkipRearm
call registry.btm 64 delete "%key" REG_DWORD 1 >& nul:

if "%@RegGet64["%key"]" != "0x1" then
	echo Unable to set the SkipRearm registry key.  Activation was not extended.
	quit 1
endif

REM Extend the activation window
call slmgr -rearm

return

:return

REM Show the path with variables unexpanded
:path

REM Initialize
set SystemPathKey=HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Environment\path
set UserPathKey=HKCU\Environment\path

set SystemPathValue=%@RegQuery["%SystemPathKey"]
set UserPathValue=%@RegQuery["%UserPathKey"]

REM Arguments
set command=show
if %# gt 0 then
	set command=%1
	shift
endif
if not IsLabel Path%command goto usage

gosub Path%command
return %_?

:PathEdit
call os.btm SystemProperties 3
return

:PathEditor
call sudo.btm PathEditor.exe
return

:PathShow

REM Turn off variable expansion to show the paths (in case they contain variables)
setdos /x-4

echo System path:
echo %SystemPathValue
echo.
echo User path:
echo %UserPathValue

REM Turn off variable expansion to show the paths (in case they contain variables)
setdos /x+4

return

:PathUpdate
set path=%SystemPathValue;%UserPathValue
return

REM Disable ReadyBoost - uses flash memory to speed disk access
REM - Issues disabling: http://forum.notebookreview.com/showthread.php?t=337548
:DisableReadyBoost

if %@ServiceExist[rdyboost] == 1 then
	echo Disabling ReadyBoost...
  call service disable rdyboost
  call service stop rdyboost
endif

return

REM Disable SuperFetch - caches changed files.  It can cause excessive disk activity when large files  change (such as backup files, virtual machine hard disk and memory files), and 
REM   may cause periodic excessive CPU spikes (seen on dune)
:DisableSuperFetch

REM Elevate
if %@IsElevated[] == 0 then
	call sudo.btm os.btm DisableSuperfetch %$
	quit %?
endif

if %@ServiceExist[SysMain] == 1 then
	echo Disabling SuperFetch...
  call service disable SysMain
  call service stop SysMain
endif

return

:PerfCount 
exctrlst.exe
return

:PerfFix
winmgmt /clearadap & winmgmt /resyncperf -p %$
return

:scanner

if IsFile "%programs\Windows Photo Viewer\ImagingDevices.exe" then
	start /pgm "%programs\Windows Photo Viewer\ImagingDevices.exe"
else
	echo A scanner configuration program is not installed.
endif

return

:PerformanceMonitor
:PerfMon
PerfMon
return

:PerformanceMonitor
perfmon.exe
return

:ResourceMonitor
start /pgm perfmon.exe /res
return

:MobilityCenter
start /pgm mblctr.exe
return

:gadget

REM Arguments
set command=show
if %# gt 0 then
	set command=%1
	shift
endif
if not IsLabel Gadget%command goto usage

gosub Gadget%command
return %_?

:GadgetCd

REM Initialize
call FindPublicDoc data\install\Microsoft\Windows\gadgets\setup
if %? != 0 quit 1

cde "%file"
set result=%?

if %result == 0 EndLocal /d

return %result

:GadgetShow
sidebar.exe /showGadgets
return %?

:SyncTime
call sudo.btm time /s time.nist.gov
return

:reliability

if %@IsNewOs[] == 0 return
echo Control Panel\System and Security\Action Center\Reliability Monitor
call os ControlPanel

return

REM Alternative User Input (CTFMON)
:DisabeAlternativeUserInput

REM Vista does not enable alternative user input
if %@IsNewOs[] == 1 quit 0

REM Kill the eprocess and wait for handles to be cleaned
if %@IsTaskRunning[ctfmon] == 1 then
  pskill ctfmon.exe
  sleep 2
endif

REM Unregister the COM object
if "%@search[msctf.dll]" != "" then
  regsvr32 /u "%@search[msctf.dll]"
endif

REM Remove ctfmon from startup
call registry.btm 32 delete "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Run\ctfmon.exe"

return 0

:DisableIndexingService

REM Disable the Microsoft Indexing service and cleanup associated files
REM Indexing in Vista is architected difernetly and performs well.

if %@ServiceExist[CiSvc] == 0 quit 0

echo Stopping indexing service...
call service stop wait CiSvc
call PauseDelay 5 `Waiting %PauseDelay seconds for index files to be released or press any key when ready`

echo Removing indexes...
call DelDir "c:\inetpub\catalog.wci"
call DelDir "c:\FPSE_"

echo Updating services...
call service manual CiSvc

return 0

:DisableMsnMessenger

REM Reference: GpEdit.msc, Administrative Templates, Windows Components, Windows Messenger, Do not allow Windows Messenger to be run

call ask `Disable MSN Messenger (may cause Outlook to hang)?` n
if %? == 0 quit 1
  
call registry.btm 32 set "HKLM\SOFTWARE\Policies\Microsoft\Messenger\Client\PreventRun" REG_DWORD 1

return 0

:DisableStrictNameChecking

REM Use of host aliases (host names that are not the computer name), in LAN Manager (UNC's), such as mobl, 
REM requires that strict name checking be disabled on the client (call DisableStrictNameChecking on the server with the alias)
REM Alternatively, define the alias in in lmhosts 

REM Fow Windows servers and XP, disable strict name checking to allow alternate names to be used in a UNC (i.e. \\alias\c$)
REM Reference http://support.microsoft.com/?id=281308 - does not mention XP, but this change does work on XP
echo Disabling strict name checking...
call registry.btm set "HKLM\SYSTEM\CurrentControlSet\Services\lanmanserver\parameters\DisableStrictNameChecking" REG_DWORD 1

echo Restarting the server service for the change to take effect
net stop server
net start server

retur

:name

if %@IsWindowsClient[] == 1 then
	switch %_WinVer
	case 6.1
		echo 7
	case 6.0
		echo Vista
	case 5.1
		echo XP
	default
		echo unknown
	endswitch
else
	switch %_WinVer
	case 6.1
		echo Windows Server 2008 R2
	case 6.0
		echo Windows Server 2008
	case 5.1
		echo Windows Server 2003
	default
		echo unknown
	endswitch
endif

return 0

:defrag
start /pgm dfrgui.exe
return %?

:initialize

set psm=%@PublicStartMenu[]
set pp=%psm\Programs
set pd=%@PublicDesktop[]

set usm=%@UserStartMenu[]
set up=%usm\Programs
set ud=%@UserDesktop[]

set client=%@if[ %@IsWindowsClient[] == 1 ,true]
set server=%@if[ %@IsWindowsServer[] == 1 ,true]
set mobile=%@if[ "%@HostInfo[%ComputerName,mobile]" == "yes" ,true]
set vm=%@if[ %@IsVirtualMachine[] == 1 ,true]

set NewOs=%@if[ %@IsNewOs[] == 1 ,true]
set NewClient=%@if[ defined NewOs .and. defined client ,true]

return

:init
EndLocal /d psm pp pd usm up ud client server mobile vm NewOs NewClient
return 0

:recycle
start /pgm explorer.exe ::{645FF040-5081-101B-9F08-00AA002F954E}
return %?

:credentials
rundll32.exe keymgr.dll, KRShowKeyMgr
return