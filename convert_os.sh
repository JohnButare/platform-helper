@echo off
SetLocal

# Initialize
DwmService=uxsms
ErrorReportingService=WerSvc
BootIniFile=c:/boot.ini

gosub initialize

# Recent files 
# - WindowsRecent contains recently used Windows files and pinned items

WindowsRecent=$AppData/Microsoft/Windows/Recent
if not IsDir "$WindowsRecent" WindowsRecent=$UserProfile/Recent

OfficeRecent=$AppData/Microsoft/Office/Recent
if not IsDir "$OfficeRecent" OfficeRecent=$UserProfile/Application Data/Microsoft/Office/Recent

# Arguments
if $@IsHelpArg[$@UnQuote[$1]] == 1 goto usage

command=start
if $# gt 0 then
  command=$1
  shift
fi

if not IsLabel $command goto usage

# Run command
gosub $command
exit $_?

:usage
text 
usage: os <command>
  dwm|ErrorReporting start|stop|restart|status: Desktop Window Manager
  activation status|extend: Windows Activation
  beep [enable|disable|status](status): PC speaker beep
  bluetooth [devices|properties](devices)
  environment [edit|editor|set|SetPath|SetStartup](editor): system environment variables
  gadget [cd|show](show): Microsoft Gadgets
  path [show|edit|editor|update|[AllUsers]](show)
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
  index: index options|start|stop|demand
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
exit 1

:FileHistory
start /pgm control.exe /name Microsoft.FileHistory
return

:CheckElevated

if $@IsElevated[] == 0 then
	echo This operation requires elevation.
	exit 1
fi

return 0

:desktop
"$WinDir/system32/rundll32.exe" shell32.dll,Control_RunDLL desk.cpl,,0
return

:template
cde $AppData/Microsoft/Windows/Templates
EndLocal /d
return

:TemplateSetup
SetupFiles=$@path[$_batchname].../setup
call registry import "$SetupFiles/ShellNew.reg"
copy "$SetupFiles/template.*" "$WinDir/ShellNew"
return

:cleanup

# Run CCleaner if elevated - cleans most of what CleanupManager does and is much faster
if $@IsElevated[] == 1 then
	CCleaner.exe /auto
fi

echo Cleaning Windows Error Reporting...
dir=$LocalAppData/Microsoft/Windows/WER

if $@DirSize[m, "$dir"] gt 20 then
	echo Clean Windows Errror Reporting files by checking for solutions...
	echo - Check for new solutions
	echo - See problems to check, Select all, Check for solutions
	call os reports
	pause
fi

# Windows Photo Gallery Orginal Images
echo Cleaning Windows Photo Gallery original images...
dir=$LocalAppData/Microsoft/Windows Photo Gallery/Original Images

if $@DirSize[m, "$dir"] gt 50 then
	echo - Delete or preserve original images (this folder contains the images prior to editing)
	start /pgm explorer "$dir"
	pause
fi

return

:CleanupRecentlyUsed

echos Cleaning recently used document list...
call DelDir contents NoHeader "$WindowsRecent" "$OfficeRecent"
echo done

return

:update

# Microsoft Update disabled on Intel hosts
if $@IsIntelHost[] == 1 return

echo Starting Microsoft Update...

# Windows Update - Vista
if exist $WinDir/system32/wuapp.exe then
  start /pgm $WinDir/system32/wuapp.exe

# Microsoft Update - x64
elif exist "$WinDir/SysWOW64/muweb.dll" then
  start /pgm rundll32 $WinDir/SysWOW64/muweb.dll,LaunchMUSite

# Microsoft Update - x86
elif exist "$WinDir/system32/muweb.dll" then
  start /pgm rundll32 $WinDir/system32/muweb.dll,LaunchMUSite

# Windows Update - installs Microsoft Update
elif exist "$WinDir/system32/wupdmgr.exe" then
  start /pgm "$WinDir/system32/wupdmgr.exe"

else

	call InternetExplorer http://www.update.microsoft.com/microsoftupdate
fi

# Update other programs
if $@OnNetwork[Intel] == 0 UpdateChecker.exe

return

:ServicePack
# Optional options to Start unattended with no dialogs : /U /N

SpKey=HKLM/SOFTWARE/Microsoft/Windows NT/CurrentVersion/CurrentBuildNumber
SpText=
SpExe=

switch $_WinVer

# Windows 7 and Windows Server 2008 R2
case 6.1 
	SpExe=Microsoft/Windows 7/update/windows6.1-KB976932-X64.exe
	SpText=7601

# Vista and Windows Server 2008
case 6.0
	SpExe=Microsoft/Vista/sp2/setup.exe
	SpText=6002
		
# Windows Server 2003
case 5.2
	SpExe=Microsoft/Server 2003/update/WindowsServer2003-KB914961-SP2-$@OsArchitecture[]-ENU.exe
	SpKey=HKLM/SOFTWARE/Microsoft/Windows NT/CurrentVersion/CSDVersion
	SpText=Service Pack 2

# Windows XP
case 5.1
  SpExe=Microsoft/XP/sp3/WindowsXP-KB936929-SP3-x86-ENU.exe
	SpKey=HKLM/SOFTWARE/Microsoft/Windows NT/CurrentVersion/CSDVersion
	SpText=Service Pack 3

endswitch

# Install the Service Pack  if it is not already installed.  
if "$SpExe" != "" then

	if "$@RegGet64["$SpKey"]" != "$SpText" then

		# Find the executable
		call FindPublicDoc "data/install/$SpExe"
		if $_? != 0 return $_?

		start /pgm "$file"
		pause
	
	fi
fi

# Compress service pack files (Vista?)
if exist "$WinDir/ServicePackFiles" then
	if defined vm then
		call DelDir "$WinDir/ServicePackFiles"
  else
		call ask `Compress service pack files?` n 5
		if $? == 1 then
			call CompactDir "$WinDir/ServicePackFiles"
		fi
	fi
fi

return

:RemoteBin
SetLocal

# Arguments
if $# != 1 goto usage
HostName=$1
shift

call os FindDirs $HostName
if $? != 0 return $?

cde $_PublicBin
EndLocal /d

return 0

:task
call task manager
return

:WindowsComponents
if IsFile "$system/sysocmgr.exe" then
	start /pgm "$system/sysocmgr.exe" /y /i:$system/sysoc.inf
else
	echo - Turn Windows features on or off
	call os programs
fi
return

:optional
start /pgm OptionalFeatures
return

:CleanupPrograms

# Add Remove Programs 
gosub programs
pause

# Windows installer cleanup utilility - http://support.microsoft.com/?kbid=290301
start /pgm msicuu
pause

# Clean Office programs
call office CleanInstall

return

:RemoveHotfixBackup

# Return if there are no hotfixes to remove
if "$@FindFirst[$WinDir/$NtUninstall*]" == "" return

# Check if user wants to remove hotfixes
call ask `Remove hotfixes?` n
if $? == 0 return

# Automated removal
start /pgm xp_remove_hotfix_backup
pause

# Remove remaining hotfixes
echos Cleaning hotfixes...
call DelDir NoHeader "$WinDir/$NtUninstall*"
echo ...done

return

:index

ServiceName=WSearch

if $@ServiceExist[$ServiceName] == 0 return 1

command=options
if $# == 1 then
	command=$1
	shift
fi

if $# != 0 .or. not IsLabel Index$command goto usage

gosub Index$command

return $_?

:IndexOptions
start /pgm "C:/Windows/system32/rundll32.exe" C:/Windows/system32/shell32.dll,Control_RunDLL "C:/Windows/System32/srchadmin.dll",Indexing Options
return

:IndexStart
:IndexStop
:IndexRestart
:IndexDemand
call service.btm $command $ServiceName
return

:computer
start /pgm explorer ::{20D04FE0-3AEA-1069-A2D8-08002B30309D}
return

# XP requires search
# - management console msc files are run using mmc program and /32 or /64,.  On x64, 32 bit command shells do not have visibily to 
#   the msc file in the 64 bit system32 directory and cannot start.  /64 is specified to stop mmc from prompting the mmc architecture to load 
:ComputerManagement
start /pgm mmc /$@OsBits[] $@search[CompMgmt.msc]
return

:DeviceManager
# In XP, DevMgmt.msc not found by msc in path, so search for it here.
start /pgm mmc $@quote[$@search[DevMgmt.msc]]
return

:DeviceLog
call TextEdit.btm "$WinDir/inf/setupapi.dev.log"
return

:FindNewHardware 
devcon rescan
return

:LocalSecurityPolicy
if $_WinVer gt 5.1  then
	start /pgm mmc secpol.msc /s
fi
return

:GroupPolicyEditor
if $_WinVer gt 5.1  then
	start /pgm mmc gpedit.msc
fi
return

:SecurityCenter 
if "$@search[wscui.cpl]" != "" then
  start /pgm wscui.cpl
fi
return

:volume

if "$@search[SndVol.exe]" != "" then
	start /pgm SndVol.exe
elif "$@search[SndVol32.exe]" != "" then
	start /pgm SndVol32.exe
fi

return

:sound
start /pgm rundll32.exe $WinDir/system32/shell32.dll,Control_RunDLL "$WinDir/system32/MMSYS.CPL",@0
return

:VirtualMemory
:PageFile
echo Performance Settings, Advanced, Virtual Memory, Change
call os SystemProperties 3
return $?

:SystemProtection
call os SystemProperties 4
return $?

:Remote
call os SystemProperties 5
return $?

:SystemProperties

# Ensure the x64 SysDm.cpl is loaded (otherwise Hardware and System Protection tabs are missing)
option //Wow64FsRedirection=No

tab=$1

if "$tab" == "" then
	start /pgm "$WinDir/system32/rundll32.exe" /d $WinDir/system32/shell32.dll,Control_RunDLL SYSDM.CPL
else
	start /pgm "$WinDir/system32/rundll32.exe" /d $WinDir/system32/shell32.dll,Control_RunDLL SYSDM.CPL,,$tab
fi

# Under Vista+ the window comes up in the background, so restore it
sleep 1
activate "System Properties" restore >& nul:

return

:AutomaticUpdates

if $@IsNewOs[] == 1 then
	start /pgm $WinDir/system32/wuapp.exe
else
	call os SystemProperties 5
fi

return

:QuickLaunch
cde "$QuickLaunch"
return 0

:UserStartMenu
cde "$usm"
return 0

:SendTo
cde "$@SendTo[]"
return 0

:PublicStartMenu
cde "$psm"
return 0

:dwm
:ErrorReporting

service=$@EvalVar[$command$Service]

# DWM is on windows 6 and up
if "$command" == "$dwm" .and. $_WinVer lt 6.0 return

if "$1" == "" then
  command=start
else
  command=$1
  shift
fi

if not IsLabel Service$command goto usage

gosub Service$command

return $_?

:ServiceStatus
echo $@ServiceState[$service]
return

:ServiceStart
:ServiceStop
:ServiceRestart
call service.btm $command $service
return $_?

return $_?

:beep
key=HKCU/Control Panel/Sound/Beep

switch "$1"

case "enable"
	call registry.btm "$key" REG_SZ Yes
	echo PC speaker beep has been enabled.

case "disable"
	call registry.btm "$key" REG_SZ No
	echo PC speaker beep has been disabled.

case "status" .or. ""
	echo PC speaker beep is $@if["$@RegGet[$key]" == "Yes",enabled,disabled].

default
	goto usage

endfswitch

return 0

:uac

if $@IsNewOs[] == 0 return 1

key=HKLM/SOFTWARE/Microsoft/Windows/CurrentVersion/Policies/System

switch "$1"

case "config"
	call registry.btm $key
	
case "enable"
	gosub CheckElevated
	call registry.btm "$key/EnableLUA" REG_DWORD 1
	if "$@RegGet[$key/EnableLUA]" == "0x1" then
		echo UAC has been enabled.
	else
		echo Unable to enable UAC.
	fi

case "disable"
	gosub CheckElevated
	call registry.btm "$key/EnableLUA" REG_DWORD 0
	if "$@RegGet[$key/EnableLUA]" == "0x0" then
		echo UAC has been disabled.
	else
		echo Unable to disable UAC.
		return 1
	fi

case "status" .or. ""

	echos `UAC is `
	switch "$@RegGet[$key/EnableLUA]"
	case "0x1"
		echo enabled
	case "0x0"
		echo disabled
	default
		echoerr status unknown
	endswitch
	
	echos `Secure desktop is `
	switch "$@RegGet[$key/PromptOnSecureDesktop]"
	case "0x1"
		echo enabled
	case "0x0"
		echo disabled
	default
		echoerr status unknown
	endswitch

	echos `Administrative shares are `
	switch "$@RegGet[$key/LocalAccountTokenFilterPolicy]"
	case "0x1"
		echo enabled
	case "0x0"
		echo disabled
	default
		echoerr status unknown
	endswitch
	
case "StatusSilent"
	return $@if["$@RegGet[$key/EnableLUA]" == "0x1",1,0]

case "SecureDesktop"

	switch "$2"
	
	case "enable"
		gosub CheckElevated
		call registry.btm "$key/PromptOnSecureDesktop" REG_DWORD 1
		if "$@RegGet[$key/PromptOnSecureDesktop]" == "0x1" then
			echo The secure desktop has been enabled.
		else
			echo Unable to enable the secure desktop.
			return 1
		fi

	case "disable"
		gosub CheckElevated
		call registry.btm "$key/PromptOnSecureDesktop" REG_DWORD 0
		if "$@RegGet[$key/PromptOnSecureDesktop]" == "0x1" then
			echo The secure desktop has been disabled.
		else
			echo Unable to disable the secure desktop.
		fi
	
	default
		goto usage
		
	endswitch
	
case "AdminShare"

	switch "$2"

	case "enable"
		gosub CheckElevated
		call registry.btm "$key/LocalAccountTokenFilterPolicy " REG_DWORD 1
		if "$@RegGet[$key/LocalAccountTokenFilterPolicy]" == "0x1" then
			echo Administrative shares have been enabled
		else
			echo Could not enable administrative shares
		fi

	case "disable"
		gosub CheckElevated
		call registry.btm "$key/LocalAccountTokenFilterPolicy " REG_DWORD 0
		if "$@RegGet[$key/LocalAccountTokenFilterPolicy]" == "0x0" then
			echo Administrative shares have been disabled
		else
			echo Could not disable administrative shares
		fi
	
	default
		goto usage
			
	endswitch

default
	goto usage

endswitch

return 0

:Reports
if $@IsNewOs[] == 1 then
	echo System and Security/Action Center
	call os ControlPanel
fi
return

:ReportArchive
cde "$UserProfile/AppData/Local/Microsoft/Windows/WER/ReportArchive"
return

:SecurityEssentials
call SecurityEssentials.btm start
return

:Defender
start /pgm "$programs/Windows Defender/MSASCui.exe"
return
 
:EditBootIni
 
if not exist $BootIniFile return
 
attrib -shr $BootIniFile 
 
call TextEdit $BootIniFile 
pause Press any key when done editing boot.ini...
 
attrib +shr $BootIniFile
 
reutrn 0
 
:Flip3D
RunDll32 DwmApi #105
return

:DiskManagement
# Failed on xp with mmc, on oversoul works with and without mmc
start /pgm diskmgmt.msc
return

:bluetooth

# Arguments
command=devices
if $# gt 0 then
	command=$1
	shift
fi
if not IsLabel Bluetooth$command goto usage

gosub Bluetooth$command
return $_?

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

:StartMenuIcons
:smi
:icons

# Default directories
pp=$@PublicStartMenu[]/Programs

call MakeDir "$pp/Applications/Other"
call MakeDir "$pp/Development/Other"
call MakeDir "$pp/Media/Other"
call MakeDir "$pp/Operating System/Other"

if $@IsWindowsClient[] == 1 then
  call MakeDir "$pp/Games/Other"
fi

# Hide files and folders
if exist "c:/config.sys" attrib +h "c:/config.sys"
if exist "c:/autoexec.bat" attrib +h "c:/autoexec.bat"

# Data folders

dir=$UserDocuments/My Data Sources
if IsDir "$dir" then
	attrib /d -s "$dir"
	call MakeLink merge "$UserData/Data Sources" hide "$dir"
fi

if IsDir "$UserDocuments/Scanned Documents" then
	call MakeLink merge "$UserData/Scans" hide "$UserDocuments/Scanned Documents"
fi

if IsDir "$UserDocuments/Fax" then
	call MakeLink merge "$UserData/Fax" hide "$UserDocuments/Fax"
fi

# Start Menu
call MoveFile "$up/Internet Explorer.lnk" "$pp/Applications"
call MoveFile "$up/Internet Explorer (32-bit).lnk" "$pp/Applications"
call MoveFile "$up/Internet Explorer (64-bit).lnk" "$pp/Applications"

call DelFile "$up/Outlook Express.lnk"
call DelFile "$up/Windows Media Player.lnk"
call MoveFile "$up/Remote Assistance.lnk" "$pp/Operating System"

call MergeDir /e "$pp/Accessories" "$pp/Applications"
call MergeDir /e "$up/Accessories" "$pp/Applications"
call MergeDir /e /rename "$pp/Windows Accessories" "$pp/Applications/Accessories"
call MergeDir /e /rename "$up/Windows Accessories" "$pp/Applications/Accessories"

call MergeDir /e /rename "$pp/Applications/Accessories/Windows PowerShell" "$pp/Applications/Accessories/PowerShell"

call MergeDir /q "$pp/Accessibility" "$pp/Applications/Accessories"
call MergeDir /q "$up/Accessibility" "$pp/Applications/Accessories"

call MergeDir /e "$pp/System Tools" "$pp/Operating System"
call MergeDir /e "$up/System Tools" "$pp/Operating System"
call MergeDir /e "$pp/Applications/Accessories/System Tools" "$pp/Operating System"

call MergeDir /e "$pp/Application Verifier" "$pp/Operating System/Other"

call MoveFile "$psm/Windows Catalog.lnk" "$pp/Applications/Accessories"
call CopyFile "$pp/Applications/Accessories/Communications/Remote Desktop Connection.lnk" "$pp/Operating System"
call MoveFile "$pp/Windows Movie Maker.lnk" "$pp/Applications/Accessories/Entertainment"
call MoveFile "$pp/Windows Messenger.lnk" "$pp/Applications/Accessories"
call MoveFile "$psm/Windows Catalog.lnk" "$pp/Applications/Accessories"
call DelFile "$psm/Program Access and Defaults.lnk"
call MoveFile "$pp/Windows Media Connect.lnk" "$pp/Applications/Accessories/Entertainment"
call DelFile "$pp/Desktop.lnk"

call MoveFile "$psm/Microsoft Update.lnk" "$pp/Operating System"
call MoveFile "$psm/Windows Update.lnk" "$pp/Operating System"

call MergeDir /e "$pp/Extras and Upgrades" "$pp/Applications/Accessories"
call MergeDir /e "$pp/Maintenance" "$pp/Operating System"
call MergeDir /e "$up/Maintenance" "$pp/Operating System"
call MoveFile "$pp/Media Center.lnk" "$pp/Applications/Accessories"
call MoveFile "$psm/Default Programs.lnk" "$pp/Operating System"

if IsFile "$pp/Immersive Control Panel.lnk" then
	# attrib -sh "$pp/Immersive Control Panel.lnk"
	# call MoveFile "$pp/Immersive Control Panel.lnk" "$pp/Applications/Accessories"
fi

if IsFile "$pp/Windows*.lnk" then
	# attrib -sh "$pp/Windows*.lnk"
	# move /q "$pp/Windows*.lnk" "$pp/Applications/Accessories"
fi

if IsFile "$up/Windows*.lnk" move /q "$up/Windows*.lnk" "$pp/Applications/Accessories"

call MoveFile "$pp/XPS Viewer.lnk" "$pp/Applications/Accessories"
call MoveFile "$pp/Sidebar.lnk" "$pp/Applications/Accessories"

call DelFile "$pd/Microsoft Download Manager.lnk"
call MergeDir /q "$pp/Microsoft Download Manager" "$pp/Development/Other/Download Manager"

# Administrative tools 
call MergeDir /q "$pp/Administrative Tools" "$pp/Operating System/Other/Administrative Tools" 

# Games
if IsDir "$pp/Games" then

	dest=$pp/Games/Other/Microsoft
	call MakeDir "$dest"

	call MoveFile "$pp/Games/Chess.lnk "$dest"
	call MoveFile "$pp/Games/FreeCell.lnk" "$dest"
	call MoveFile "$pp/Games/Hearts.lnk" "$dest"
	call MoveFile "$pp/Games/InkBall.lnk" "$dest"
	call MoveFile "$pp/Games/Minesweeper.lnk" "$dest"
	call MoveFile "$pp/Games/PurblePlace.lnk" "$dest"
	call MoveFile "$pp/Games/Spider Solitaire.lnk" "$dest"
	call MoveFile "$pp/Games/Hold 'Em.lnk" "$dest"
	call MoveFile "$pp/Games/Mahjong.lnk" "$dest"
	call MoveFile "$pp/Games/Solitaire.lnk" "$dest"
	
	# XP Games
	call MoveFile "$pp/Games/Internet Backgammon.lnk" "$dest"
	call MoveFile "$pp/Games/Internet Checkers.lnk" "$dest"
	call MoveFile "$pp/Games/Internet Hearts.lnk" "$dest"
	call MoveFile "$pp/Games/Internet Reversi.lnk" "$dest"
	call MoveFile "$pp/Games/Internet Spades.lnk" "$dest"
	call MoveFile "$pp/Games/Pinball.lnk "$dest"

fi

# Windows 8
call MergeDir /q "$pp/IIS" "$pp/Development/Other/IIS"

return

:OfficeRecent
cde "$OfficeRecent"
return

:WindowsRecent
cde "$WindowsRecent"
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

# AutoRuns cannot find winmm.dll on x64 unless started from syswow64
if "$@OsArchitecture[]" == "x64" then
	start /d$WinDir/SysWow64 /pgm autoruns
else
	start /pgm autoruns
fi

:environment

command=editor
if $# == 1 then
	command=$1
	shift
fi

if $# != 0 .or. not IsLabel Environment$command goto usage

gosub Environment$command

return $_?

:EnvironmentEdit
call os.btm SystemProperties 3
return $?

:EnvironmentEditor
call sudo.btm rapidee.exe
return $?

:EnvironmentSet
gosub EnvironmentSetPath
gosub EnvironmentSetStartup
return

:EnvironmentSetPath
call os.btm path set
return

:EnvironmentSetStartup
call MakeShortcut "$PublicBin/run.sh" "$psm$/Programs/Startup/startup.lnk" /arguments "startup" /desc "Start applications"
return

:activation

command=ActivationStatus
if $# gt 0 then
	command=Activation$1
	shift
fi
if not IsLabel $command goto usage

gosub $command
return $_?

:ActivationStatus

# Grace period end date
call slmgr -xpr

# License details
call slmgr -dli

return

:ActivationExtend

gosub ActivationStatus

# Suspend activation count (otherwise limit of 3 extensions)
key=HKLM/SOFTWARE/Microsoft/Windows NT/CurrentVersion/SL/SkipRearm
call registry.btm 64 delete "$key" REG_DWORD 1 >& nul:

if "$@RegGet64["$key"]" != "0x1" then
	echo Unable to the SkipRearm registry key.  Activation was not extended.
	exit 1
fi

# Extend the activation window
call slmgr -rearm

return

:return

# Show the path with variables unexpanded
:path

# Initialize
SystemPathKey=HKLM/SYSTEM/CurrentControlSet/Control/Session Manager/Environment/path
UserPathKey=HKCU/Environment/path

SystemPathValue=$@RegQuery["$SystemPathKey"]
UserPathValue=$@RegQuery["$UserPathKey"]

# Arguments
command=show
if $# gt 0 then
	command=$1
	shift
fi
if not IsLabel Path$command goto usage

gosub Path$command
return $_?

:PathSet

# Make sure UserDocuments and PublicDocuments are set
if "$UserDocuments" == "" then
	call $@left[-1,$@path[$_batchname]]/os.btm FindDirsInit
fi

# user bin
call SetVar /path path "$UserDocuments/data/bin"

# public bin
call ask `Configure path for all users?` y
system=$@if[ $? == 1 ,/system,]

# bin (common binaries), win64 / win32 / sfu (windows 32 bit / 64 bit / POSIX  binaries), linux64 / mac64 (other platform binaries)
if "$@OsArchitecture[]" == "x64" call SetVar $system /path path "$PublicDocuments/data/bin/win64"
call SetVar $system /path path "$PublicDocuments/data/bin/win32"
call SetVar $system /path path "$PublicDocuments/data/bin"

return

:PathEdit
call os.btm SystemProperties 3
return

:PathEditor
call sudo.btm PathEditor.exe
return

:PathShow

# Turn off variable expansion to show the paths (in case they contain variables)
setdos /x-4

echo System path:
echo $SystemPathValue
echo.
echo User path:
echo $UserPathValue

# Turn off variable expansion to show the paths (in case they contain variables)
setdos /x+4

return

:PathUpdate
path=$SystemPathValue;$UserPathValue
return

# Disable ReadyBoost - uses flash memory to speed disk access
# - Issues disabling: http://forum.notebookreview.com/showthread.php?t=337548
:DisableReadyBoost

if $@ServiceExist[rdyboost] == 1 then
	echo Disabling ReadyBoost...
  call service disable rdyboost
  call service stop rdyboost
fi

return

# Disable SuperFetch - caches changed files.  It can cause excessive disk activity when large files  change (such as backup files, virtual machine hard disk and memory files), and 
#   may cause periodic excessive CPU spikes (seen on dune)
:DisableSuperFetch

# Elevate
if $@IsElevated[] == 0 then
	call sudo.btm os.btm DisableSuperfetch $$
	exit $?
fi

if $@ServiceExist[SysMain] == 1 then
	echo Disabling SuperFetch...
  call service disable SysMain
  call service stop SysMain
fi

return

:PerfCount 
exctrlst.exe
return

:PerfFix
winmgmt /clearadap & winmgmt /resyncperf -p $$
return

:scanner

if IsFile "$programs/Windows Photo Viewer/ImagingDevices.exe" then
	start /pgm "$programs/Windows Photo Viewer/ImagingDevices.exe"
else
	echo A scanner configuration program is not installed.
fi

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

# Arguments
command=show
if $# gt 0 then
	command=$1
	shift
fi
if not IsLabel Gadget$command goto usage

gosub Gadget$command
return $_?

:GadgetCd

# Initialize
call FindPublicDoc data/install/Microsoft/Windows/gadgets/setup
if $? != 0 exit 1

cde "$file"
result=$?

if $result == 0 EndLocal /d

return $result

:GadgetShow
sidebar.exe /showGadgets
return $?

:SyncTime
call sudo.btm time /s time.nist.gov
return

:reliability

if $@IsNewOs[] == 0 return
echo Control Panel/System and Security/Action Center/Reliability Monitor
call os ControlPanel

return

# Alternative User Input (CTFMON)
:DisabeAlternativeUserInput

# Vista does not enable alternative user input
if $@IsNewOs[] == 1 exit 0

# Kill the eprocess and wait for handles to be cleaned
if $@IsTaskRunning[ctfmon] == 1 then
  pskill ctfmon.exe
  sleep 2
fi

# Unregister the COM object
if "$@search[msctf.dll]" != "" then
  regsvr32 /u "$@search[msctf.dll]"
fi

# Remove ctfmon from startup
call registry.btm 32 delete "HKCU/SOFTWARE/Microsoft/Windows/CurrentVersion/Run/ctfmon.exe"

return 0

:DisableIndexingService

# Disable the Microsoft Indexing service and cleanup associated files
# Indexing in Vista is architected difernetly and performs well.

if $@ServiceExist[CiSvc] == 0 exit 0

echo Stopping indexing service...
call service stop wait CiSvc
call PauseDelay 5 `Waiting $PauseDelay seconds for index files to be released or press any key when ready`

echo Removing indexes...
call DelDir "c:/inetpub/catalog.wci"
call DelDir "c:/FPSE_"

echo Updating services...
call service manual CiSvc

return 0

:DisableMsnMessenger

# Reference: GpEdit.msc, Administrative Templates, Windows Components, Windows Messenger, Do not allow Windows Messenger to be run

call ask `Disable MSN Messenger (may cause Outlook to hang)?` n
if $? == 0 exit 1
  
call registry.btm 32 "HKLM/SOFTWARE/Policies/Microsoft/Messenger/Client/PreventRun" REG_DWORD 1

return 0

:DisableStrictNameChecking

# Use of host aliases (host names that are not the computer name), in LAN Manager (UNC's), such as mobl, 
# requires that strict name checking be disabled on the client (call DisableStrictNameChecking on the server with the alias)
# Alternatively, define the alias in in lmhosts 

# Fow Windows servers and XP, disable strict name checking to allow alternate names to be used in a UNC (i.e. //alias/c$)
# Reference http://support.microsoft.com/?id=281308 - does not mention XP, but this change does work on XP
echo Disabling strict name checking...
call registry.btm "HKLM/SYSTEM/CurrentControlSet/Services/lanmanserver/parameters/DisableStrictNameChecking" REG_DWORD 1

echo Restarting the server service for the change to take effect
net stop server
net start server

retur

:name

if $@IsWindowsClient[] == 1 then
	switch $_WinVer
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
	switch $_WinVer
	case 6.1
		echo Windows Server 2008 R2
	case 6.0
		echo Windows Server 2008
	case 5.1
		echo Windows Server 2003
	default
		echo unknown
	endswitch
fi

return 0

:defrag
start /pgm dfrgui.exe
return $?

:initialize

psm=$@PublicStartMenu[]
pp=$psm/Programs
pd=$@PublicDesktop[]

usm=$@UserStartMenu[]
up=$usm/Programs
ud=$@UserDesktop[]

client=$@if[ $@IsWindowsClient[] == 1 ,true]
server=$@if[ $@IsWindowsServer[] == 1 ,true]
mobile=$@if[ "$@HostInfo[$ComputerName,mobile]" == "yes" ,true]
vm=$@if[ $@IsVirtualMachine[] == 1 ,true]

NewOs=$@if[ $@IsNewOs[] == 1 ,true]
NewClient=$@if[ defined NewOs .and. defined client ,true]

return

:init
EndLocal /d psm pp pd usm up ud client server mobile vm NewOs NewClient
return 0

:recycle
start /pgm explorer.exe ::{645FF040-5081-101B-9F08-00AA002F954E}
return $?

:credentials
rundll32.exe keymgr.dll, KRShowKeyMgr
return