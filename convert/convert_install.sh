#!/bin/bash

	init
	quit $_?

	# Full Template
	:AppName
	# Download: 
	# Installs:
	echot "\
	************
	* App Name
	************
	- (Display pre-installation instructions)
	"

	# Run setup
	run ""

	echo Moving data folder...
	$makeLink --merge --hide "$udata/Adobe Digital Editions" hide "$udoc/My Digital Editions"
	$mergeDir --rename "$udoc/Embarcadero" "$udata/Embarcadero"
	DropBox MoveConfig "$_ApplicationData/FileZilla" "$CloudDocuments/data/FileZilla"

	echo Creating directories...
	$makeDir c:/dir1/dir2

	echo Updating registry...

	# Delete <startup program name> - <registry value>
	registry 32 delete "HKLM/SOFTWARE/Microsoft/Windows/CurrentVersion/Run/NNN"

	registry import "$setupFiles/(registration file).reg"

	r=HKCU/Software/Company/Program
	registry "$r/key" REG_SZ value >& nul:
	registry "$r/key" REG_SZ "$@RegQuote[value]" >& nul:

	echo Registering objects...
	regsvr32 /s (libraries to register)

	echo Update web.config...
	XmlEdit Web.Config "/configuration/appSettings/add[@key='TFSNameUrl']/@value" http://$TfsDomain:$TfsHttpPort

	echo Restoring the default profile...
	AppName profile restore default

	echo Updating services...
	service manual (service name)

	echo Updating tasks...
	SchTasks /Change /Tn "(task name)" /Disable
	SchTasks /Create /TN test /TR ls.exe /SC ONEVENT /EC System /MO "*[System[Provider[@Name='Microsoft-Windows-Power-Troubleshooter'] and EventID=1]]"
	SchTasks /Create /RU $@SystemAccount[] /RP * /SC OnIdle /I $SleepTaskIdleTime /TN "sleep" /TR "$@sfn[$pdoc/data/bin/]/tcc.exe /c SleepTaskSleep.btm"

	echo "Updating firewall..."

	# Enable or disable a firewall rule
	firewall rule enable "SQL Server"

	# Add or update a firewall rule
	firewall rule add "SQL Server" `dir=in action=allow protocol=TCP localport=1433 profile=private ^
		program="$P/Microsoft SQL Server/MSSQL.1/MSSQL/Binn/sqlservr.exe"`

	firewall rule add "SQL Server" `dir=in action=allow protocol=TCP localport=3180 profile=private ^
		program="$P/Microsoft SQL Server/MSSQL.1/MSSQL/Binn/sqlservr.exe"`

	firewall rule add DCOM `dir=in action=allow protocol=TCP localport=135 profile=private program=$systemroot$/system32/svchost.exe service=rpcss`

	# Custom firewall rule
	netsh advfirewall firewall rule group="windows management instrumentation (wmi)" new enable=yes profile=private,domain
		
	echo Updating shell extensions...
	echo - Disable NNN, NNN

	RunProg ShExView32
	pause

	echo Updating path...
	SetVar /system /path path "$P32/Cygwin/bin"

	echo "Updating icons..."
		$mv "$pd/(prog).lnk" "$pp/Applications"
		$mv "$pp/Applications/Office/Microsoft Word.lnk" "$ao/Word.lnk"
	$rm "$up/(user link to delete).lnk"
	$rm "$pd/(desktop file to delete).lnk"
	$mergeDir "$pp/(directory name)" "$ao"
	$mergeDir --rename "$pp/(directory name)" "$ao/(new directory name)"
	$makeShortcut "c:/dir1" "$pp/Applications/App.lnk"

	echot "\
	- (Display configuration instructions)
	"
	sudo /standard EverNote startup
	pause

	echot "\
	- (Display post-installation instructions)
	"

	return

	# FindExe - find an executable in the installation directory or on an installation CD.  
	#
	# in: 
	# - exe: the executable to find, relative to the install directory
	# - exe: relative name of the exe to find.  If exe contains semi-colin list of wildcard filenames the user is prompted for the exe to use.
	# out:
	# - exe: an absolute path to the found exe.
	# - ExeDir: directory where the executable is found. and the parent
	:FindExe [ExeArg]

	# Initialize
	exe=$@UnQuote[$ExeArg]
	dir=

	# Return if we do not need to find the exe

	if "$@left[4,$exe]" == "http" .or. (IsFile "$exe" .and. $@IsWild[$exe] == 0 .and. "$@full[$exe]" == "$exe") return 0

	# Find the executable
	FindPublicDoc "data/install/$exe"
	if $_? != 0 then
		pause
		return 1
	fi

	install=$SharedDocuments/data/install
	exe=$install/$exe
	ExeDir=$@parent[$exe]

	# Prompt for the exectuable if it contains wildcards
	if $@IsWild[$exe] then

		select.btm file "$exe"
		if $? != 0 return $?	
		
		exe=$file
		
	fi

	if "$exe" == "" pause

	return $@if[ "$exe" == "" ,1,0]

	:RunProg [program]

	prog=$@quote[$@search[$program]]
	if IsFile $prog then
		start /pgm $prog
	fi

	return

	:run [ExeArg options]

	# Arguments
	exe=$@UnQuote[$ExeArg]
	if "$exe" == "" then 
		EchoErr Executable was not specified.
		return 1
	fi

	# Find the executable
	FindExe "$exe"
	if $_? != 0 return $_?

	RunExe "$exe"
	return $_?

	# exe - executable to run
	# noCleanup - if defined do not cleanup
	# postRun - if specified, secondary executable to run
	:RunExe [ExeArg]

	# Arguments
	exe=$@UnQuote[$ExeArg]

	# Initialize
	ran=
	DefaultResponse=y 
	prefix=$@left[4,$exe]
	   
	if "$prefix" == "http" then
		ExeDesc=$exe		
	else
		ExeDesc=$@word["/",-0,$@path[$exe]]/$@fileName[$exe]
	fi

	ExeExt=$@ext["$exe"]
			
	ask "Do you want to run $ExeDesc?"
	if $? == 0 then
		RunExeCleanup
	  return 0
	fi

	ran=true

	if "$prefix" != "http" pushd "$@parent[$exe]"
	  
	# Folder
	if IsDir "$exe" then

		PrepareinstallDir
		if $_? != 0 return $?

		CopyDir "$exe" "$installDir"
		
	# http
	elif "$prefix" == "http" then
	  ShellRun "$exe"
	   	    
	# iso
	else if "$ExeExt" == "iso" then
	  iso mount 1 "$@filename[$exe$]"    

	# registry file
	else if "$ExeExt" == "iso" then
	  registry 64 import "$@filename[$exe$]"
	    
	fi
	  
	if "$prefix" != "http" popd

	if "$postRun" != "" then
		start /pgm  $@quote[$postRun] "$@"
	fi

	RunExeCleanup

	return 0

	:RunExeCleanup

	if not defined noCleanup then

		if $ExeExt == iso then
			iso unmountall
		fi

	fi

	RunInit

	return

	:test
	FindExe "Sun/Java/jdk/*.exe;*.jar" j2sdk-1_4_2_05-windows-x86-p.exe
	echo $exe
	return

	:environment

	ask "console defaults?" y
	if $? == 1 SetConsoleDefaults

	ask "operating system environment defaults?" y
	if $? == 1 os environment set

	return

	:core

	# Common
	inst 7zip UpdateChecker OsUpdate InternetExplorer FoxitReader jre .NET

	# Computer specific
	switch $ComputerName

	case oversoul
		inst IntelDP67BG PowerMixer PowerPanel ^
			SnagIt LastPass Quicken TrueCrypt ^
			EpsonV100 EyeFi calibre calibre2opds Sonos MediaCore

	case jjbutare-mobl
		inst Hp8560wLaptop PowerMixer OpenVPN IntelDevCore ^
			SnagIt DesktopGadgets EverNote LastPass WindowsAdminTools IntelCore

	case dune
		inst GigabyteGaP35Dq6 nVidia PowerMixer DropBox LogMeIn

	case shadow
		inst GigabyteGaP35Dq6 nVidia LogMeIn

	case ws08
		inst iis ss08 TeamFoundationServer
		
	endswitch

	return
	
	:GameCore

	Steam
	XboxWirelessReceiver
	PinnacleGameProfiler
	GameJackal
	GameTap
	XboxWirelessReceiver

	return

	:ServerCore
	echot "\
	************************
	* Server Core
	************************
	"

	inst iis ss12

	return

	:WindowsMobileCore
	echot "\
	************************
	* Windows Moibile Core
	************************
	"

	instal.btm DeviceCenter

	echo Opening Pocket PC setup instructions...
	ShellRun "$udoc/Technical/Pocket PC.doc"

	return

	:.net
	# reference - http://msdn.microsoft.com/winfx/ 
	echot "\
	************************
	* .NET Framework
	************************
	"
	.Net45
	return

	:.NetInit
	p=Microsoft/.NET/setup
	return

	# 4.5
	:.Net45
	.NetInit
	run "$p/v4.5/dotnetfx45_full_x86_x64.exe"
	return

	# 4.0: targets 4.0, 3.5, 3.0, and 2.0.
	:.Net40 
	.NetInit
	run "$p/v4.0/en_.net_framework_4_full_x86_x64_508940.exe"
	return

	# 3.5: targets 3.5, 3.0, and 2.0.  Installs 2.0 and 3.0.  Comes with Windows 7.
	:.Net35 
	.NetInit
	run "$p/v3.5/dotnetfx35.30729.01.exe"
	return

	# 3.0: targets 3.0 and 2.0.  Comes with Windows Vista (6.0)
	:.Net30
	.netInit
	run "$p/V3.0/dotnetfx3_${architecture}.exe"
	fi

	:.Net20
	.netInit
	run "$p/V2.0/.NET 2.0 ${architecture}.exe"
	return

	:.Net11
	.netInit
	run "$p/v1.1/dotnetfx.exe"
	return

	:.NetSdk
	echot "\
	************************
	* .NET Framework SDK
	************************
	- Uncheck Samples and Register Environment Variables
	"

	.netInit
	run "$p/V1.0/SDK version 1.0a/setup.exe"

	echo "Updating icons..."
	$mergeDir "$up/Microsoft .NET Framework SDK" "$pp/Development/Other"

	return

	:Hearts
	echot "\
	************************
	* Hearts
	************************
	- SN: NS-100-000-554, Key: 43B7-0C21
	- Install to c:/Hearts
	"

	FindExe "MVP Software/Hearts Deluxe V2.3/SETUP.EXE"
	if $_? != 0 return $_?

	SetupDir=c:/setup
	CopyDir "$ExeDir" "$SetupDir"
	RunExe "$SetupDir/Setup.exe"
	$rmd "$SetupDir"

	mv c:/HEARTS "$P32/HEARTS"

	echo "Updating icons..."
	$rm "$pd/Hearts.lnk"
	$rmd "$pp/MVP"
	$makeShortcut "$P32/HEARTS/mvpheart.exe" "$pp/Games/MVP Hearts.lnk"

	echot "\
	- Options, Music, Event Music Only
	- Game, Change Rules
	  - Uncheck Point cards allowed on first trick
	  - Select Score exactly the ending score makes the score 0
	  - Passing Left, right, across, none
	"

	return

	# Cleanup legacy JP software (4NT and TCI) and install Take Command
	:JpClean

	inst TakeCommandUpgrade SrcOlder dif

	# Cleanup legacy 4NT and TCI 
	$rmd "$P32/tci"
	registry delete "HKEY_CLASSES_ROOT/Directory/shell/4NT" >& nul:
	registry delete "HKEY_CLASSES_ROOT/Drive/shell/4NT" > nul:

	inst TakeCommand

	return

	:TakeCommand
	:tc
	# - download ftp://jpsoft.com/, http://jpsoft.com/downloads.html
	# - changes http://jpsoft.com/forums/view/announcements.17/ and http://jpsoft.com/forums/view/support.4/
	echot "\
	********************************
	* Take Command
	********************************
	"

	TcVersion=13.04.64

	TcMajorVersion=$@InStr[0,2,$TcVersion]
	TcMinorVersion=$@replace[.,,$@InStr[3,2,$TcVersion]]
	TcArchitecture=$@if[ ${architecture} == x64,x64,x86]
	TcProgramDir=$P/JPSoft/TCMD$TcMajorVersion$$@if[ $TcArchitecture == x64,x64]
	p=JP Software/Take Command

	run "$p/setup/Take Command v$TcVersion ${architecture}.exe"	

	registry=setup v$TcMajorVersion ${architecture}.reg
	profile=default

	ask "Do you want to update the path?" y
	if $? == 1 then
		echo Updating path...
		echo Paste $TcProgramDir; before bin in the system path
		echo $@ClipW[$TcProgramDir;] >& nul:
		os.btm path edit
		pause
	fi

	# Install default plugins
	ask "Do you want to install the default plugins?" y
	if $? == 1 CopyDir /fast "$install/$p/plugins/default/$TcArchitecture" "$TcProgramDir/plugins"

	echo Copying files...
	CopyFile "$pdoc/Icons/Command Prompt.ico" "$TcProgramDir"
	CopyFile "$install/$p/setup/other/TcStart.btm" "$TcProgramDir"

	# TCSTART and TCEXIT - must not be the system user, option dialog does not work properly
	if "$@option[TCStartPath]" != "$TcStartDir" .and. "$UserName" != "SYSTEM" then
		echo Updating TCSTART / TCEXIT Path...
		echo `- Startup, TCSTART / TCEXIT Path=<paste>`
		echo $@ClipW[$@ScriptDir[]] >& nul:
		option
	fi

	# Common setup
	TakeCommand.btm setup

	# Registry
	ask "Do you want to restore the default registry settings?" n
	if $? == 1 registry import "$install/$p/setup/other/$registry"

	# Profile
	if "$profile" == "default" .or. IsFile $@quote[$profile] then
		TakeCommand.btm profile restore $@quote[$profile]
	fi

	# Icons
	echo "Updating icons..."
	dir=$pp/Operating System/Other/Take Command

	icon=Take Command$@if[ "${architecture}" == "x64" , x64] $TcMajorVersion.$@if[ $TcMajorVersion gt 12,0,$TcMinorVersion].lnk
	$rm "$psm/$icon"
	$rm "$pd/$icon"
	$rm "$dir/$icon"

	$mergeDir --rename "$pp/TCMD$TcMajorVersion" "$dir"
	$mergeDir --rename "$pp/TCMD$TcMajorVersion$x64" "$dir"

	$makeShortcut /quiet "$TcProgramDir/tcc.exe" "$dir/Take Command Console.lnk"
	$makeShortcut /quiet "$TcProgramDir/tcmd.exe" "$dir/Take Command.lnk"

	echot "\
	- View, uncheck Command Input, Folder and List View, and Status Bar
	- Options, Theme, VS 2010
	- Toolbar, Customize..., 
	  - Toolbar, F(older and List Views) C(ommand Input) D(ebug) V(iew)
	  - Keyboard, View, Folder and List Views, Ctrl+F
	  - Options, check Show shortcut keys in ScreenTips
	- Notes
	  - ctrl-n/w=new/close, alt-left/right=cycle, num. 00paste+run
	  - [alt] drag=[block] hilight and copy
	  - middle mouse button: paste
	  - (multiple monitors) tcc, Properties, Font, Size=4x6
	    - Run 4nt to run Take Command with normal font size
	- Option, Command Line, uncheck Complete hidden files and Complete hidden directories
	"

	return

	# Prepare a new Take Command image from the files in the current folder.
	# Requires: Take Command installation files copied to the current directory
	:TakeCommandPrepareImage

	if not exist "tcmd.exe" then
	  echo The current directory does not contain tcmd.exe.
	  return 1
	fi

	$makeDir "other"

	move /q /e batch.bcp French?.dll German?.dll Spanish?.dll license.txt readme.txt updater.* *.btm other
	if exist Guide.pdf move Guide.pdf "Take Command Guide.pdf"

	echo The Take Command image has been prepared.

	return

	:OsUpdate
	# path: c:/Windows/System32/wbem
	echot "\
	************************
	* OS Update
	************************
	"

	if "$data" != "c:" then

		$makeDir "$data/Program Files"
		$makeDir "$data/Program Files (x86)"
		
		echo Moving Windows Installer folder...
		$makeLink --merge "$data/Windows/Installer" "$WinDir/Installer"
		
		echo "- permissions for $data/Windows/Installer, $data/Program Files*: Everyone Read & execute, SYSTEM and Administrators Full control"
		pause
		
	fi

	os ServicePack

	# Install Windows updates
	echo - Get updates for other Microsoft products, click Find out more
	os update
	pause

	# Automatic updates
	echot "\
	- Change Settings
	  - Install updates automatically OR Check for updates but let me choose whether to download and install them
	  - Check Include recommended updates when downloading, installing, or notifying me about updates
		- Check Use Microsoft Update
	"

	os AutomaticUpdates
	pause Press any key after all updates have been installed...

	# Cleanup
	os.btm StartMenuIcons
	CleanupFiles.btm

	return

	:MotherboardMonitor
	# No longer updated, latest version is 2004 and motherboard updates downloaded are dated 2004
	# Download: http://www.majorgeeks.com/download.php?det=311
	# Installs: mbmiodrvrMBMIO Driver, cansoft@livewiredev.com, c:/windows/system32/mbmiodrvr.sys	
	echot "\
	************************
	* Motherboard Monitor
	************************
	- Core: 2V, Port: 0
	- Preferences, Run MBM on startup, No Splash, Log All three items, text only, Email: On alarms do
	"

	run "Shareware/Motherboard Monitor/mbm5370.exe"

	echo "Updating icons..."
	$mergeDir "$up/MBM 5" "$pp/Operating System/Other"
	$mergeDir "$pp/MBM 5" "$pp/Operating System/Other"

	return

	:WindowsAdminTools
	# Windows Server 2003 Service Pack 2 Administration Tools Pack -  http://www.microsoft.com/downloads/details.aspx?familyid=86B71A4F-4122-44AF-BE79-3F101E533D95&displaylang=en
	# #ote Server Administration Tools for Windows 7 -  http://www.microsoft.com/downloads/details.aspx?familyid=7D2F6AD7-656B-4313-A005-4E344E43997D&displaylang=en
	# Installing or #oving - http://technet.microsoft.com/en-us/library/ee449483$28WS.10$29.aspx
	echot "\
	*****************************
	* Windows Admin Tools
	*****************************
	"

	echo Installing #ote Server Administration tools...
	if $@IsNewOs[] == 1 then
		run "Microsoft/Server 2008/tools/Windows$_WinVer$-KB958830-${architecture}-RefreshPkg.msu"
		
		ask "Enable #ote Server Administration features?" y
		if $? == 1 then
		
			echo Enabling default features...
			dism /online /enable-feature /featurename:#oteServerAdministrationTools
			dism /online /enable-feature /featurename:#oteServerAdministrationTools-Roles
			dism /online /enable-feature /featurename:#oteServerAdministrationTools-Roles-RDS
			
			echo Enable other features...
			os programs
			echo - Turn Windows features on or off, #ote Server Administration Tools
			echo   - (optional) Check other features
			pause
			
		fi
		
	else
		# Will reinstall if shortcuts are moved and setup will not function if the name of the msi is changed
		run "Microsoft/Server 2003/tools/WindowsServer2003-KB340178-SP2-${architecture}-ENU.msi"
	fi

	echo "Updating icons..."
	$mergeDir "$pp/Administrative Tools" "$pp/Operating System/Other/Administrative Tools" 

	return

	:TweakUI
	echot "\
	************************
	* TweakUI
	************************
	"

	# This version of TweakUI does not run under new operating systems
	if defined NewOs return

	run "Microsoft/XP/other/Tweak UI/TweakUiPowertoySetup.exe"

	CopyFile "$pp/Powertoys for Windows XP/Tweak UI.lnk" "$pp/Administrative Tools/TweakUI.lnk"
	$rmd "$pp/Powertoys for Windows XP"
	$rmd "$up/Powertoys for Windows XP"

	echo - Templates, uncheck all except Word, Excel, PowerPoint, Visio, Text Document, WinZip
	RunProg "$WinDir/system32/TweakUI.exe"

	return

	:PowerDVD
	# Player, x86 hardware based codec package (mpeg-2, H.264, DivX), nVidia PureHD hardware support, HdCodecPack is codecs only.
	# Installs
	# RichVideo - service, optionally uninstall using "$P32/CyberLink/Shared files/richvideouninstall.exe"
	echot "\
	************************
	* PowerDVD
	************************
	"

	run "CyberLink/PowerDVD/setup/PowerDVD10_UltraUpgrade_fromUltra_1830_DVD100611-07.exe"

	echo Updating registry...

	# Delete BDRegion - "C:/Program Files (x86)/Cyberlink/Shared Files/brs.exe" - #ove the Blu-ray region
	registry 32 delete "HKLM/SOFTWARE/Microsoft/Windows/CurrentVersion/Run/BDRegion"

	# Delete PDVD9LanguageShortcut - "C:/Program Files (x86)/CyberLink/PowerDVD9/Language/Language.exe"
	registry 32 delete "HKLM/SOFTWARE/Microsoft/Windows/CurrentVersion/Run/PDVD9LanguageShortcut"

	# Delete #oteControl10 - "C:/Program Files (x86)/CyberLink/PowerDVD10/PDVD10Serv.exe"
	registry 32 delete "HKLM/SOFTWARE/Microsoft/Windows/CurrentVersion/Run/#oteControl10"

	echo Updating services...
	service manual RichVideo

	echo "Updating icons..."
	$mv "$pd/CyberLink PowerDVD 10.lnk" "$pp/Media/PowerDVD.lnk"
	$mergeDir --rename "$up/CyberLink PowerDVD 10" "$pp/Media/Other/PowerDVD"
	$mergeDir --rename "$pp/CyberLink PowerDVD 10" "$pp/Media/Other/PowerDVD"

	PowerDVD start
	pause

	echot "\
	- To use PowerDVD H.264 decoder in DirectShow applications (WMC and WMP), run haali disable 
	  and lower ffdshow Video Filter priority below Normal.
	"

	return

	:HdCodecPack
	# CyberLink HD AVCHD codec pack - required to player older Hi8 video camera videos
	echot "\
	************************************************
	* CyberLink HD Codec Pack DirectShow Filters
	************************************************
	"

	installDir=$P32/CyberLink/HD Codec Pack

	if IsDir "$installDir" then
		ask "Uninstall the HD Codec Pack?" n
		uninstall=$@if[ $? == 1 ,true]
	fi

	if not defined uninstall run "CyberLink/HD Codec Pack/HD Codec Pack.zip" "$installDir"

	if IsDir "$installDir" then

		echos Updating DirectShow filters...
		pushd "$installDir"
		for /r $file in ("*.ax"); do
			regsvr32 $@if[ defined uninstall ,/u] /s $@quote[$file]
			echos .
		done
		popd
		echo done.

	fi

	if defined uninstall then 
		$rmd ask "$installDir"
		echo Reboot required to #ove the installation directory.
	fi

	return

	:Quicken
	echot "\
	************************
	* Quicken
	************************
	- Check GetUpdate
	"

	run "Intuit/Quicken/Quicken_Home_Business_2013.exe"

	# Icons
	$mergeDir --rename "$pp/Quicken 2013" "$ao/Quicken"
	$mv "$ao/Quicken/Quicken 2013.lnk" "$ao/Quicken/Quicken.lnk"
	$rm "$pd/Free Credit Report and  Score.url"
	$rm "$pd/Quicken Home ? Business 2013.lnk"

	echot "\
	- Run Quicken, select I am already a Quicken user, Next, Next, Documents/Finances/Current/Finances
	- Edit, Preferences
	  - Quicken Preferences,  Setup/Backup, uncheck Manual Backup #inder
	  - Register/Data entry and QuickFill
	    - Check Use enter key to move between fields
	  - Reports and Graphs, select Customizing modifies current report or graph
	- Click One Step Update, Register 
	  - Check Don't show this summary again unless there is an error.
	"

	return
	  
		return

	:Emacs
	# http://www.gnu.org/software/emacs/windows/ntemacs.html
	echot "\
	************************
	* Emacs
	************************
	"
	run "Shareware/emacs/emacs-22.1-bin-i386.zip" "$P32/emacs"
	return

	:WinZip
	echot "\
	************************
	* WinZip
	************************
	"

	run "WinZip Computing, Inc/Winzip11.EXE"
	run "WinZip Computing, Inc/wzcline.exe"

	echo Stopping the WinZip QuickPick application...
	taskend /f wzqkpick >& nul:

	echo "Updating icons..."
	$mergeDir "$pp/WinZip" "$ao"
	$mv "$pd/WinZip.lnk" "$pp/Applications"
	$rm "$pd/WinZip 8.0.lnk"
	$rm "$psm/WinZip.lnk"
	$rm "$pp/Startup/WinZip Quick Pick.lnk"

	WinZip
	echot "\
	- Click View Style
	"

	return
	
	:office13
	echot "\
	************************
	* Office 2013
	************************
	- Customize, Instalaltion Options, Microsoft Office, Run all from My Computer except 
	  - (optional) Microsoft SkyDrive Pro
	  - SharePoint Workspace (Groove)
	  - Office Shared Features
	    - International Support
	    - Proofing Tools/French&Spanish
	- User Information
	"

	# Applications
	p=Microsoft/Office/setup
	run "$p/office/en_office_professional_plus_2013_$architecture$.iso"
	run "$p/visio/en_visio_professional_2013_$architecture$.exe"
	run "$p/project/en_project_professional_2013_$architecture$.exe"

	# Update
	p=Microsoft/Office/update
	# run "$p/msores2013-kb2727009-fullfile-$architecture$-glb.exe"
	# run "$p/msoloc2013-kb2737997-fullfile-$architecture$-glb.exe"
	# run "$p/pj2013-kb2752101-fullfile-$architecture$-glb.exe"

	# Final setup
	OfficeFinal

	return

	:OfficeFinal

	echo "Moving data folder..."
	$makeLink --merge --hide "$udata/mail" hide "$udoc/Outlook Files" || return
	$makeLink --merge --hide "$udata/Custom Office Templates" hide "$udoc/Custom Office Templates" || return

	$makeDir "$udoc/Outlook Files" || return
	$hide +h "$(utw "$udoc/Outlook Files")" || return

	# Search providers - must be done after Outlook, OneNote, and SharePoint Workspace have been run
	ask "Update search provider names?"
	if $? == 1 search.btm setup

	# Link directories
	$makeLink --merge --hide "$udata/Visio/shapes" hide "$udoc/My Shapes"
	$makeLink --merge --hide "$udata/Workspace/archives" hide "$udoc/Workspace Archives"
	$makeLink --merge --hide "$udata/Workspace/templates" hide "$udoc/Workspace Templates"

	return
	
	:TotalRecorder
	echot "\
	************************
	* TotalRecorder
	************************
	"

	# Setup
	run "High Criteria/Total Recorder Standard Edition V4.4/tr44se.exe"

	# Icons
	CopyFile "$pp/Total Recorder/Total Recorder.lnk" "$pp/Applications"
	$rm "$pd/Total Recorder.lnk"
	$mergeDir "$pp/Total Recorder" "$ao"

	echot "\
	- Help, Registration 
	  - Name: John Butare
	  - Key: TR30.GUT8.LNB7.UAKQ.BTL9
	- Options, Settings
	  - System tab: Select Audio Playback and recording devices selected above
	  - MP3 Encoding tab: Fraunhofer IIS MPEG Layer-3 Codec
	- Options, Recording Source
	  - Select Convert using paramaters supplied below
	  - Change button, Format=Fraunhofer IIS MPEG Layer-3 Codec, attributes=32kbs 24khz mono, Save button, Audio Book Quality
	- View, Show Selection to enable markers
	"

	return

	:WebMatrix
	# path: C:/Program Files (x86)/Microsoft ASP.NET/ASP.NET Web Pages/v1.0
	echot "\
	************************
	* WebMatrix
	************************
	"

	run "Microsoft/WebMatrix/setup/webmatrix.exe"

	IISExpress

	echo "Updating icons..."
	$mergeDir --rename "$pp/Microsoft WebMatrix" "$pp/Development/other/WebMatrix"
	$mergeDir "$pp/IIS 7.0 Extensions" "$pp/Development/other"
	$mv "$pp/Microsoft Web Platform Installer.lnk" "$pp/Development/.NET/Web Platform Installer.lnk"
	$mv "$pp/Development/other/WebMatrix/Microsoft WebMatrix.lnk" "$pp/Development/other/WebMatrix/WebMatrix.lnk"
	$mv "$pp/Development/other/WebMatrix/Microsoft Web Platform Installer.lnk" "$pp/Development/other/WebMatrix/Web Platform Installer.lnk"

	echot "\
	- Tools, Options, Site, Default site location Documents/code/web
	"
	pause

	return

	:SharePoint
	echot "\
	************************
	* SharePoint
	************************
	"

	run "Microsoft/SharePoint/setup/en_sharepoint_server_2010_with_service_pack_1_x64_759775.exe"

	echo "Updating icons..."
	$mergeDir --rename "$pp/Microsoft SharePoint 2010 Products" "$pp/Server/other/SharePoint"

	return

	:TeamFoundationServer
	:tfs
	:tfs10
	echot "\
	************************
	* Team Foundation Server
	************************
	- Configure
	  - Configure Team Foundation Application Server, Standard Single Server, Start Wizard
	    - Service Account, Readiness Checks
	  - Configure Team FOundation Build Service, Start Wizard
	- Download
	  - Visual WIP (Kanban board) - http://visualwip.codeplex.com/releases/view/73605
	"
	c=$ComputerName
	echo - URLs: http://$c:8080/tfs http://$c:8080/tfs/web
	echo    http://$c/ReportServer http://$c/Reports 
	echo    http://$c/sites http://$c:17012 

	# Prerequisites
	ask "Install prerequisites (IIS, SS08, .net40)?"
	if $? == 1 iis ss08 .net40

	# Services
	for service in (MsSqlServer ReportServer MsSqlServerOlapService) (
		service auto $service
		service start $service
	)

	# Initialization
	tfs=Microsoft/Visual Studio/Team Foundation Server

	# Setup
	postRun=c:/dev/iso1/TFS-${architecture}/setup.exe
	run "$tfs/setup/en_visual_studio_team_foundation_server_2010_x86_x64_dvd_509406.iso"

	# Other
	run "$tfs/other/Team Foundation Server Build Extensions 2010.msi"

	# Update
	run "$tfs/update/mu_team_foundation_server_2010_sp1_x86_x64_651711.exe"

	echo "Updating icons..."
	$mergeDir "$pp/Microsoft Team Foundation Server 2010" "$serverPrograms/Other"

	echo Configuring Kanban...
	echot "\
	-Goals, Story Queue, UAT Review In Dev, In Test, Accepted
	"
	pause

	return

	:tfs08
	# Microsoft installation guide: http://go.microsoft.com/fwlink/?LinkId=52502
	# Intel installation guide: Microsoft/Visual Studio.NET V2005/doc/System Configuration Guide TFS Omnidroid 1 4.doc
	echot "\
	************************
	* Team Foundation Server
	************************
	- Uninstall or disable virus scanning software (or Sharepoint site extension fails)
	- Test page (use from local machine to invoke): http://<server>:8080/services/v1.0/serverstatus.asmx
	"

	tfs=Microsoft/Visual Studio/Team Foundation Server/2008/setup

	ask "Do you want to configure SQL server?" y
	if $? == 1 then
	  services=MsSqlServer SqlServerAgent ReportServer MsSqlServerOlapService SqlBrowser ReportServer MsFteSql MsDtsServer  
	  
	  for service in ($services) (
	    service auto wait $service
	    service start wait $service
	  )
		
		text
		- Report Server Virtual Directory, Uncheck Require Secure Socket Layer (SSL) connections 
			(otherwise creation of TFS report server datasource fails)
		"
		SqlServer RsConfig
		pause
	    
	fi

	# FrontPage 2002 Uninstall
	ask "Do you want to uninstall FrontPage2002?" y
	if $? == 1 then

	  echo - Application Server, Details, Internet Information Services (IIS), Detail, uncheck FrontPage2002 Server Extensions
	  os WindowsComponents
	  pause
	  
	fi

	# Accounts
	ask "Do you want to create prerequisite user accounts?" y
	if $? == 1 then

	  # Accounts must be in the local administrator group or Sharepoint site extension fails
	  user.btm create "TfsService-Team Foundation System service user-system"
	  user.btm create "TfsReports-Team Foundation System reports user-system"

		echo - TfsService/TfsReports, check Password next expires 
		os ComputerManagement
		pause
		
	fi

	# SharePoint Services 2.0 with SP2
	run "Microsoft/Sharepoint/stsv2.exe" /C:"setupsts.exe /#oteSql=yes /provision=no /qn+"

	# Mount the ISO image.  So that we can run additional installations on the image, do not unmount it
	noCleanup=true
	run "$tfs/Team Foundation Server.iso"

	prefix=c:/dev/iso1

	ask "Do you want to install Team Foundation Server?" y
	if $? == 1 then

	  text
	- Single-Server Installation
	- Service Account, Account name=<paste, TfsService>
	- Report Data Source Account, Account name=TfsReports
	- Team Foundation Alerts
	  - Check Enable Team Foundation Alerts
	  - SMTP server=<smtp address, i.e. smtp.comcast.net, smtp.intel.com>
	  - From e-mail address=<tfs@domain.com>
	  "
		echo $@ClipW[TfsService] >& nul:

	  # Setup fails if not run from the current directory
	  pushd $prefix
	  RunProg autorun.exe
		pause
	  popd
	  
	fi

	echo Validate SharePoint...
	echo - Validate SharePoint Central, Browse, Create a top-level Web site, Version for Default Web Site is 6.0.2.6568.  
	iis manager
	pause 

	echo - Value default SharePoint site
	http://$ComputerName/default.aspx
	pause

	ask "Do you want to install TFS build?" y
	if $? == 1 then
		echo $@ClipW[TfsService] >& nul:
		echo `- Service Account, Account name=<paste, TfsService>`
		RunProg "$prefix/build/setup.exe"
		pause
	fi

	ask "Do you want to install eScrum (TFS project management)?" y
	if $? == 1 then
		run "$tfs/en_eScrum_1.0.msi"
	fi

	echo Cleanup...
	iso unmount 1

	echo Updates...
	run "$tfs/VS80-KB919156-X86.exe"
	run "$tfs/VS80sp1-KB926738-X86-ENU.exe"
	run "$tfs/MSF for Agile Software Development TFS Update.EXE"

	TfsUrl=
	Tfs#oteAccess
	TfsRename
	TfsTest

	# Custom SQL
	echo - Execute TFS custom SQL scripts
	SqlServer ExecuteSql "$ExeDir/tfs.sql"

	# Web Access
	run "$tfs/Team System Web Access V1.0.msi"

	echo "Updating icons..."
	$makeDir "$pp/Development/Other/Visual Studio 2005"
	$mergeDir --rename "$pp/Microsoft .NET Framework SDK v2.0" "$pp/Development/Other/Visual Studio 2005/Framework SDK v2.0"

	return

	:TfsGetUrl

	if defined TfsUrl return

	TfsUrl=http://$ComputerName
	input /c Default Web Site URL? ($TfsUrl)?` ` $$TfsUrl
	TfsDomain=$@word["/",1,$TfsUrl]

	echo Validate $TfsDomain...
	ShellRun $TfsUrl

	ask "Is $TfsUrl correct? "
	if $? == 0 goto TfsGetUrl

	TfsHttpPort=8080
	input /c TFS Team Foundation Server HTTP port? ($TfsHttpPort)?` ` $$TfsHttpPort

	TfsHttpsPort=7070
	input /c TFS Team Foundation Server HTTPS port? ($TfsHttpsPort)?` ` $$TfsHttpsPort

	return

	:TfsRename

	TfsGetUrl

	echo Update internal references to $TfsDomain...
	"$P32/Microsoft Visual Studio 2005 Team Foundation Server/Tools/TfsAdminUtil.exe" ActivateAt $TfsDomain

	echo Update reporting services web parts to the public URL if the Default Web Site...
	registry 32 "HKLM/Software/Microsoft/VisualStudio/8.0/TeamFoundation/ReportServer/key" REG_SZ $TfsUrl

	echo Update web.config...
	XmlEdit Web.Config "/configuration/appSettings/add[@key='TFSNameUrl']/@value" http://$TfsDomain:$TfsHttpPort
	XmlEdit Web.Config "/configuration/appSettings/add[@key='TFS Name']/@value" $TfsDomain

	echo - Uncomment TFSUrlPublic and change it to the friendly name for project alert WI links, update the protocol and port
	echo `<ADD value="`$TfsUrl:$TfsHttpsPort`" key="TFSUrlPublic" /`>`
	echot "\Edit "$P32/Microsoft Visual Studio 2005 Team Foundation Server/Web Services/web.config"
	pause

	echo Update scheduler URL to start the adapters...
	service stop TFSServerScheduler
	XmlEdit TFSServerScheduler.exe.config "/configuration/appSettings/add[@key='BisDomainUrl']/@key" TFSNameUrl
	XmlEdit TFSServerScheduler.exe.config "/configuration/appSettings/add[@key='TFSNameUrl']/@value" http://$TfsDomain:$TfsHttpPort
	service start TFSServerScheduler

	iis service reset

	return

	:TfsTest

	TfsGetUrl

	echo Test installation...
	echot "\
	-	Create a new TFS site named sandbox, click Project Velocity, verify site report URL is correct
	- Registration Status, GetRegistrationEntries, Invoke, verify <Type>vstfs</Type> 
	"
	ShellRun "https://$TfsDomain/sites/sandbox"
	ShellRun "https://$TfsDomain:$TfsHttpsPort/services/v1.0/ServerStatus.asmx"
	ShellRun "https://$TfsDomain:$TfsHttpsPort/services/v1.0/Registration.asmx"

	return

	:Tfs#oteAccess

	echo #ote access configuration...
	echot "\
	- Web Sites, Directory Security, IP address and domain name restrictions, Edit, By default, 
	  all computers will be Granted access
	- Install an SSL certificate, enable an SSL port, and enable Basic Authentication on the 
	  Default Web Site and Team Foundation Server web sites.  
	"
	iis manager
	pause

	ask "Do you want to create the IIS authetnication filter?" y
	if $? == 1 then
	  file=$P32/Microsoft Visual Studio 2005 Team Foundation Server/TF Setup/ AuthenticationFilter.ini
	  echo [config] > "$file"
	  echo RequireSecurePort=true >> "$file"
	  echo SubnetList=192.168.1.0/255.255.255.0 >> "$file"
	  echo - Update the SubnetList to identify local addresses that can use Windows Integrated authentication
	  TextEdit "$file"
	  pause
	fi

	echo Updating event viewer configuration...
	reg.exe add "HKEY_LOCAL_MACHINE/SYSTEM/CurrentControlSet/Services/Eventlog/Application/TFS ISAPI Filter" /v EventMessageFile /t REG_SZ /d $windir$/Microsoft.NET/Framework/v2.0.50727/EventLogMessages.dll /f 
	reg.exe add "HKEY_LOCAL_MACHINE/SYSTEM/CurrentControlSet/Services/Eventlog/Application/TFS ISAPI Filter" /v TypesSupported /t REG_DWORD /d 7 /f 

	echo Configure the authentication ISAPI filter...
	echot "\ 
	- Team Foundation Server, Properties, ISAPI Filters, Add
	  - Filter name= TFAuthenticationFilter
	  - Executable=c:/Program Files/Microsoft Visual Studio 2005 Team Foundation Server/TF Setup/AuthenticationFilter.dll
	"
	iis manager
	pause

	return

	:TfsClientSetup

	# visual studio variables
	VisualStudio.btm init
	if $? != 0 return $?

	# Team Foundation Server Power Tools - http://msdn.microsoft.com/en-us/vstudio/bb980963.aspx
	echo - (optional) Custom, check Windows Shell Extension and PowerShell Cmdlets
	run "$vs/setup/TFS/Team Foundation Server Power Tools $VsName.msi"

	# Team Foundation Server Source Control integration for other products (such as SQL Server Management Studio) - http://msdn.microsoft.com/en-us/vstudio/bb980963.aspx
	run "$vs/setup/TFS/Team Foundation Server MSSCCI Provider $VsName.msi"

	echo Addings default TFS servers...
	# TeamFoundationServer.btm server add Intel http://source.intel.com:8080
	TeamFoundationServer.btm server add Intel http://source2010.intel.com:8090
	if $@OnNetwork[Wiggin] == 1 then
		TeamFoundationServer server add test http://ws08:8080/tfs
	fi
	VisualStudio start
	pause

	echot "\
	- (Team Foundation Server, for Wiggin requires podzone installed in root certificate store) 
	  - Tools, Connect to Team Foundation Server..., 
	    - Connect to a Team Foundation Server=<TFS Server>
	    - Team projects=<select projects>
	  - File, Source Control, Workspaces..., Select computer, Edit..., Working folders
	    - Status=Active
	    - Source Control Folder=<$/ or sub-folder>
	    - Local Folder=<c:/code or sub-directory>
	    - Examples $/HCMS/MyLearning=C:/code/MyLearning
	- Tools, Add-in Manager, SqlParser, uncheck startup (startup as needed due to toolbar placement issues)
	- Notes
	  - When added projects to source control, delete the name=<sol>.root 
	  - Close Team Explorer if not always connected to the TFS server (prevent VS slow start)
	"
	VisualStudio.btm start
	pause

	return
	
	:SsReportServerConfig

	if $@ServiceExist[ReportServer] == 0 return

	ask "Do you want to configure SQL Server Reporting Services?" n
	if $? == 0 return
		
	echot "\

	SQL Server Reporting Services configuration...
	- Report Server Virtual Directory, Uncheck Require Secure Socket Layer (SSL) connections 
	- (if default report server configuration was not selected) Reporting Services Configuration 
	  - Server Status, Start
	  - Report Server Virtual Directory, New, Ok
	  - Report Manager Virtual Directory, New, Ok
	  - Windows Service Identity, Apply
	  - Web Service Identity, Apply
	  - Database Setup
	    - Server Name=<hostname>, Connect
	    - Database Name, New, Ok
	    - Apply, Ok
	"
		
	SqlServer RsConfig
	pause

	return

	:SsMailConfig

	ask "Do you want to configure SQL mail?" n
	if $? == 0 return
			
	echo - Object Explorer, Server, Facets, Facet=Surface Area Configuration, DatabaseMailEnabled=True
	SqlServer studio
	pause

	SqlServer ExecuteSql "$ExeDir/..../other/Database Mail Setup.sql"

	echo Execute the mail setup script ...
	echo $@ClipW[$MailSetupScript] >& nul:
	echot "\Edit "$MailSetupScript"

	echot "\
	- Object Explorer, Server, SQL Server Agent (SQL Server Agent service must be running), 
	- Properties
		- Advanced, check Define idle CPU condition
		- Alert System
			- Check Enable mail profile
			- Mail system=Database mail
			- Mail profile=Public Mail Profile
	- New, Operator..., New Operator..., Name=NNN, E-mail name=NNN
	"
		
	SqlServer studio
	pause

	return
		
	:SsSamples
	echot "\
	************************
	* SQL Server Samples
	************************
	"

	run "Microsoft/SQL Server/samples/SQL2008.AdventureWorks_All_Databases.${architecture}.msi"
	run "Microsoft/SQL Server/samples/SQL2008.All_Product_Samples_Without_DBs.${architecture}.msi"

	echo "Updating icons..."
	$mergeDir /r "$pp/Microsoft SQL Server 2008 Community `&` Samples" "$serverPrograms/Other/SQL Server 2008/samples"
	$rm "$pd/Microsoft SQL Server 2008 Community ? Samples Code.lnk"
	$rm "$pd/Microsoft SQL Server 2008 Community ? Samples License.lnk"
	$rm "$pd/Microsoft SQL Server 2008 Community ? Samples Portal.lnk"

	pause

	return

	:IisWebDAV

	echot "\
	- Default Web Site, WebDAV Authoring Rules, Enable WebDAV
	  - Add Authoring Rule, Specified users=jjbutare, Permissions=Read&Source&Write
	- Create directory c:/inetpub/wwwroot/share
	  - Authentication, Anonymous Authentication=Disabled, Windows Authentication=Enabled
	  - Directory Browsing=Enable
	  - Site, Add Virtual Directory..., Alias=Public, Physical path=c:/Users/Public
	  - Site, Add Virtual Directory..., Alias=<user friendly name, i.e. John>, path=c:/Users/<username>,
	    Connect As=Specific user, Set..., User name=<user with permissions to the users share, i.e. the user, system account, other>
	"
			iis manager
	pause

	return

	:IisFtp

	echo "Updating firewall..."
	firewall rule enable "FTP Server (FTP Traffic-In)"
	firewall rule enable "FTP Server Passive (FTP Passive Traffic-In)"
	firewall rule enable "FTP Server Secure (FTP SSL Traffic-In)"

	echot "\
	- Sites, Add FTP Site..., FTP site name=ftp, Physical path=c:/inetpub/ftproot
	  - SSL=No SSL, Authentication=Basic, Allow access to=Specified users, <username>, check Read and Write
	- FTP Directory Browsing, check Virtual directories
	- Site, Add Virtual Directory..., Alias=Public, Physical path=c:/Users/Public
	- Site, Add Virtual Directory..., Alias=<user friendly name, i.e. John), Physical path=c:/Users/<username>
	"
	iis manager
	pause

	return

	:IisDebugging
	# Reference: http://support.microsoft.com/default.aspx?scid=kb;en-us;290398

	echo - Component Services/Computers/My Computer/DCOM Config/Machine Debug Manager,
	echo   Properties, Security, Access Permissions Edit, Add..., Interactive;IWAM_<ComputerName>
	RunProg dcomcnfg

	return

	:IisCompression

	echo IIS Manage updates...
	echot "\
	- (IIS6) Computer, Properties, check Enable Direct Metabase Edit
	- (enable compression for IIS6 and below)
	  - Web Sites, Properties, Service
	    - Check Compress application files 
	    - Check Compress Static files
	    - Maximum temporary directory size=1000
	  - Web Service Extension, Add a new Web service extension...
	    - Extension name=HTTP Compression
	    - Add..., Path to file=c:/windows/system32/inetsrv/gzip.dll 
	    - Check extension status to Allowed
	"
	iis manager
	pause

	echo Direct metabase updates...
	echot "\
	- (two places, one for deflate and one for gzip) <IIsCompressionScheme 
	  - HcScriptFileExtensions: Add extensions (aspx, asmx, php, etc) using existing format
	- HcDynamicCompressionLevel=9 (0 min compression to 10 max compression)
	"
	iis config
	pause

	return

	:IisSsl

	# Install the SSL Certificate
	echo Install the computer or wildcard certificate to use in IIS
	certificate manager
	pause

	# HTTPS firewall configuration
	if $@IsWindowsClient[] == 1 then
	  echo "Updating firewall..."
	  firewall rule enable "World Wide Web Services HTTPS Traffic In"
	fi

	# Configure wildcard certificate
	echot "\
	- Wildcard certificates (i.e. *.podzone.net) are required if you will be hosting more than 
	  one domain using SSL (i.e. site1.podzone.net, site2.podzone.net).
	- Edit the SecureBindings metabase key, i.e. ":443:site1.podzone.net"
	"
	iis service stop
	iis config
	iis service start
	pause

	# Install the certificate in IIS    
	if $_WinVer lt 6.0 then
	  echo - Default Web Site, Directory Security, Secure communications, Server Certificate...,   
	else
	  echo - Server Certificates, Import
		echo - Default Web Site, Edit Bindings, Add, type=https, SSL certificate=$ComputerName.podzone.net
	fi
	iis manager
	pause	

	# Install the certificate on clients to prevent certificate error in Internet Explorer and enables use of SourceSafe Internet
	echot "\
	- Note: Each client machine that visits trust the SSL certificate used.  If the certificate
	  is not from a trusting authority that has a certificate already installed, import 
	  the certificate on the client using Certificate Manager Import
	"

	return

	:IisRemoteManager
	# download - http://www.iis.net/download/iismanager
	echot "\
	************************
	* IIS #ote Manager
	************************
	"

	run "Microsoft/Internet Information Services/extensions/inetmgr_${architecture}.msi"

	echo "Updating icons..."
	$mv "$pp/Internet Information Services (IIS) 7 Manager.lnk" "$serverPrograms/Internet Information Services (IIS) Manager.lnk"

	return

	:IntelRemoteAccess
	# - AnyConnect (iss 8102) - AnyConnect replaced SoftID and NetStructure
	#  - installs: Cicso AnyConnect client, Intel #ote access certificate, and Intel ProxyManager
	#  - note: install requires domain access for certificate provisioning
	# - faq : http://servicedesk.intel.com/sdcxuser/Intel/userbrowse.asp?sprt_fid=79c22297-9202-48c5-8fe4-e24f1affc720
	# - install: http://servicedesk.intel.com/sdcxuser/Intel/defcontent_view2.asp?ssfromlink=true&sprt_cid=e2311896-1a61-439e-ad93-ee15b9114918
	# - certificate issues: if there is an error installing the certificate, copy the certificate setup program while the AnyConnect.exe setup is running, then run IntelCertificateUtility.exe separately
	#   issues: https://intelpedia.intel.com/Windows_7_at_Intel
	echot "\
	************************
	* Intel #ote Access
	************************
	- Must be connected to the Intel network
	"

	run "Intel/#ote Access/setup/AnyConnect.EXE"

	echo "Updating icons..."
	$mergeDir "$pp/Cisco" "$pp/Operating System/Other"
	$mergeDir "$pp/ProxyManager" "$pp/Operating System/Other"
	$rm "$pd/AnyConnect Pocket Guide.lnk"
	$rm "$pd/Cisco AnyConnect VPN Client.lnk"
	$mv "$psm/Cisco AnyConnect VPN Client.lnk" "$pp/Operating System"

	echo Updating registry...

	# Delete LoadProxyMan - C:/PROGRA~2/PROXYM~1/ProxyMan.exe
	registry 32 delete "HKLM/SOFTWARE/Microsoft/Windows/CurrentVersion/Run/LoadProxyMan"

	echot "\
	- Wireless Configuration
	  - Intel Guest: SSID=Guest
	    - Connection, check  Connect even if the network is not broadcasting its name (SSID)
	    - Security, Security type=No authentication (Open), Encryption type=None
	  - Intel: SSID=TSNOfficeWLAN
	    - Connection, check  Connect even if the network is not broadcasting its name (SSID)
	    - Security, Security type=WPA2-Enterprise, Encryption type=AES
	"

	return

	:SnagIt
	echot "\
	************************
	* SnagIt
	************************
	- Custom, uncheck Windows Explorer Menu Extension
	"

	run "TechSmith/SnagIt/setup/SnagIt V11.2.1.172.exe"
	# run "TechSmith/SnagIt/setup/SnagItUp.exe"

	echo "Updating icons..."
	$mergeDir --rename "$pp/TechSmith" "$ao/TechSmith"
	$mv "$ao/TechSmith/Snagit ?? Editor.lnk" "$ao/TechSmith/Snagit Editor.lnk"
	$mv "$ao/TechSmith/Snagit ??.lnk" "$ao/TechSmith/Snagit.lnk"
	$rm "$pd/SnagIt ??.lnk"
	$rm "$pd/SnagIt ?? Editor.lnk"
	$rm "$pp/Startup/SnagIt ??.lnk"

	# Start SnagIt now so that the registry entries below are created
	SnagIt start
	pause Close SnagIt then press any key to continue...

	echo Updating registry...
	r=HKCU/Software/TechSmith/SnagIt/11
	folder=$udoc/data/SnagIt
	registry 32 "$r/CatalogFolder" REG_SZ $folder/
	registry 32 "$r/ExternalOutputDir" REG_SZ $folder/Program/
	registry 32 "$r/StampCustomFolder" REG_SZ $folder/Stamps/
	registry 32 "$r/IMOutputDir" REG_SZ $folder/Instant Messenger/

	echo Updating directories...
	$mergeDir --rename "$udoc/SnagIt" "$udata/SnagIt"
	$makeDir "$udata/SnagIt/Stamps"
	$rmd.btm "$udoc/SnagIt Stamps"

	echo Installing outputs...
	p=$install/TechSmith/SnagIt/outputs
	# ShellRun "$p/Flickr.snagacc"
	# ShellRun "$p/WordPress.snagacc"

	# Restart AutoHotKey so ctrl-shift-p is released
	sudo /standard AutoHotKey.btm restart

	echot "\
	- Quick Launch, Turn off OneClick
	- Tools, Program Preferences...,
	  - Program Options, check Minimize to tray
	  - Notifications, uncheck Show all tips and Show all balloon tips
	  - Updater Options, uncheck Enable automated update checking
	- Profile Settings
	  - Share=Clipboard, uncheck Preview in Editor, Save as New Profile, Name=Clipboard
	  - Share=Word, uncheck Preview in Editor, Save as New Profile, Name=Word
	- Notification Area
	  - Customize, Snagit, Show icon and notifications 
	"
	SnagIt.btm start

	return

	:WindowsMediaPlayer
	:wmp
	echot "\
	************************
	* Windows Media Player
	************************
	- Don't run Microsoft Music Assistant
	"

	if not defined NewOs then
	  run "Microsoft/Media/Player V11/wmp11-windowsxp-${architecture}-enu.exe"
	fi

	echot "\
	- Click Turn shuffle on and Turn repeat on
	- Tools, Options
	  - Player, uncheck Add local media files to library when played
	  - Rip Music 
	    - (music roo) Rip music to this location=Public/Music
	    - File Name..., Check only Song title	
	    - Format=mp3
	    - Check Eject CD after ripping
	    - Audio Quality=256 Kbps
	  - Devices, Advanced, Store files temporarily to this location=d:/temp
	  - Burn
	    - uncheck Burn CD without gaps
	    - Add a list of burned files to the disc in the this format=M3U
		- Library
	    - Uncheck Retrieve additional information from the internet, Only add missing information
	    - (music roo) Check Rename music files using rip music settings
	    - (music roo) Check Rearrange music in rip music folder, using rip music settings
	    - Check Maintain my star ratings as global ratings in files
	- File, Manage Libraries
	  - Validate personal and public libraries are selected
		- (media roo Music) default save location to Public
	- Customize navigation pane..., 
	  - Music check Year, Rating, Composer
	  - Videos check Rating, Folder
	  - Picture check all
	  - Recorded TV check Series, Genre 
	- Navigation Pane, right click each Sonos device, #ove from list
	- Music, columns Title, Rating, #, Length, Contributing artist, Composer
	- Notes
	  - Tools, Apply media information changes to apply tag changes to media files and rearrange and rename music according to rip settings
	"
	WindowsMediaPlayer start
	pause

	WindowsMediaPlayer service manual

	echo Windows Media Center...
	if $@IsInstalled[WindowsMediaCenter] == 1 then
		text
	- Settings, add features, Add features to Windows
	- Tasks, Settings
	  - Library Setup
		- (prevent wakeup) General, Automatic Download Options, uncheck Automatically download Windows Media Center data between the following times:
		"
		WindowsMediaCenter.btm start
		pause
	fi

	return

	:WmpEncoder
	# - Download http://www.microsoft.com/windows/windowsmedia/forpros/encoder/default.mspx
	echot "\
	******************************
	* Windows Media Player Encoder
	******************************
	"

	run "Microsoft/Media/Encoder V9/WMEncoder ${architecture}.exe"

	if $@ServiceExist[WmdmPmSN] == 1 then
		echo Updating services...
		service manual WmdmPmSN
	fi

	echo "Updating icons..."
	$mergeDir "$pp/Windows Media" "$pp/Media/Other"

	return

	:DirectX
	# Reference http://www.appdeploy.com/packages/detail.asp?id=169
	echot "\
	************************
	* DirectX
	************************
	"

	if "$@RegQuery["HKLM/SOFTWARE/Microsoft/DirectX/Version"]" == "4.09.00.0904" then
	  echo DirectX V9.0c is already installed.
	else
	  echo Installation of DirectX will run silently.

	  run "Microsoft/DirectX V9.0c Redistributable/DXSETUP.exe" /silent
	fi

	return

	:QCheck
	echot "\
	************************
	* QCheck
	************************
	"

	run "netiq/qcheck 2.1.939/qcinst21.exe"

	echo "Updating icons..."
	$mv "$pd/QCheck.lnk" "$pp/Operating System"
	$mergeDir "$pp/NetIQ Qcheck" "$pp/Operating System/Other"

	return

	:AdobeAIR
	:AIR
	echot "\
	************************
	* Adobe AIR
	************************
	"

	run "Adobe/AIR/Adobe AIR v3.0.0.4080.exe"

	return

	:AdobeReader
	:reader
	#  Download: http://www.adobe.com/products/acrobat/readstep2.html
	echot "\
	************************
	* Adobe Reader
	************************
	"

	run "Adobe/reader/AdbeRdr1001_en_US.exe"

	echo Updating registry...

	# Delete  Adobe ARM - "C:/Program Files/Common Files/Adobe/ARM/1.0/AdobeARM.exe"
	registry 32 delete "HKLM/SOFTWARE/Microsoft/Windows/CurrentVersion/Run/Adobe ARM"

	# Delete Adobe Reader Speed Launcher - "C:/Program Files (x86)/Adobe/Reader 9.0/Reader/Reader_sl.exe"
	registry 32 delete "HKLM/SOFTWARE/Microsoft/Windows/CurrentVersion/Run/Adobe Reader Speed Launcher"

	echo "Updating icons..."
	$mv "$pp/Adobe Reader 9.lnk" "$pp/Applications/Adobe Reader.lnk"
	$mv "$pp/Adobe Reader X.lnk" "$pp/Applications/Adobe Reader.lnk"
	$mv "$pp/Acrobat.com.lnk" "$pp/Applications"
	$rm "$pd/Adobe Reader 9.lnk"
	$rm "$pd/Adobe Reader X.lnk"
	$mv "$pd/Acrobat.com.lnk" "$pp/Applications"
	$rm "$pp/Startup/Adobe Reader Speed Launch.lnk"
	$rm "$pp/Startup/Adobe Reader Synchronizer.lnk"

	echot "\
	- Tools, Customize Toolbars...
	  - File Toolbar: Check only: Save, Search, Email
	  - Page Display Toolbar: Single Page Continuous
	  - Page Navigation Toolbar: Previous and Next View
	  - Select & Zoom Toolbar: Select Tool, Hand Tool, Dynamic Zoom, Fit Width, Fit Page
	"
	AdobeReader.btm start

	return

	:FlashPlayer
	:flash
	# Download: http://www.filehippo.com/download_flashplayer_ie_64 (full version) 
	#   http://get.adobe.com/flashplayer/ http://get.adobe.com/flashplayer/otherversions/ (partial download)
	# Version: http://kb.adobe.com/selfservice/viewContent.do?externalId=tn_15507
	# Install: http://get.adobe.com/flashplayer/
	# Beta: http://labs.adobe.com/downloads/ (x64 flash faq http://labs.adobe.com/technologies/flashplayer10/faq.html)
	# Versions: http://www.adobe.com/software/flash/about/
	# Test; http://www.adobe.com/software/flash/about/, http://www.chemgapedia.de/vsengine/info/en/help/requi#ents/flash.html
	# Full screen patch (click on other monitor does not close): http://my.opera.com/d.i.z./blog/2009/04/22/watch-fullscreen-flash-while-working-on-another-screen and http://deve.loping.net/projects/ignoflash/
	# Install log: C:/Windows/SysWOW64/Macromed/Flash/FlashInstall.log
	echot "\
	************************
	* Flash Player
	************************
	- Never check for updates
	"

	test=http://www.adobe.com/software/flash/about/

	version=11.6.602.180
	p=Adobe/Flash Player/setup
	run "$p/Flash v$version.exe"
	if $_WinVer le 6.2 run "$p/Flash for IE v$version.exe"

	echo Updating registry...

	# Delete FlashPlayerUpdate - C:/WINDOWS/system32/Macromed/Flash/NPSWF32_FlashUtil.exe -p
	registry 32 delete "HKCU/SOFTWARE/Microsoft/Windows/CurrentVersion/RunOnce/FlashPlayerUpdate"

	ask "Do you want to test Flash?"
	if $? == 1 then
		chrome $test$
		chrome beta $test$
		firefox $test$
		InternetExplorer 32 $test$
		InternetExplorer 64 $test$
	fi

	return

	:GoogleCommandLine
	# http://code.google.com/p/googlecl/ http://code.google.com/p/gdata-python-client/
	echot "\
	************************
	* Google Command Line
	************************
	"

	ask "Do you want to install Python?"
	if $? == 1 python

	echo.
	echo Installing Google Data API...
	installDir=$P/Google/Data API
	run "Google/Data API/gdata-2.0.10.zip" "$installDir"
	pushd "$installDir" & setup.py install & popd

	echo.
	echo Installing Google Command Line...
	installDir=$P/Google/Command Line
	run "Google/Command Line/googlecl-0.9.5.7z" "$installDir"
	pushd "$installDir" & setup.py install & popd

	echo.
	echo Configuring Google Command Line...
	echo - Hit enter, then add the following to the GENERAL section:
	echo auth_browser = $LocalAppData/Google/Chrome/Application/chrome.exe 
	google.btm docs list
	echot "\Edit.btm
	pause

	echo.
	echo Testing Google Command Line...
	google.btm docs list

	return

	:GoogleToolbar
	# Update - "C:/Users/jjbutare/AppData/Local/Google/Update/GoogleUpdate.exe" /c
	echot "\
	************************
	* Google Toolbar
	************************
	"

	ShellRun http://toolbar.google.com/install
	pause

	echot "\
	Toolbar:
	- Install Without advanced features
	- Move the QuickLinks to the right of the IE icons. 
	- Google, Toolbar Options
	  - Options, Check
	    - Drop-down search history
	    - Highligh button
	    - Word-find buttons
	    - Popup Blocker
	    - AutoFill button
	    - BlogThis!
	  - More  
	    - Search Options - check all
	    - Web buttons - check Up, Next & Previoys
	    - Extra search buttons - check Search Groups
	    - Extras - check Automatically hilight fields that AutoFill can fill
	"

	return

	:VideoStudio
	# Updates: http://www.ulead.com/download/download.htm, http://www.corel.com/servlet/Satellite/us/en/Content/1197911963266
	# Installs:
	# - Path: C:/Program Files/Common Files/Ulead Systems/MPEG
	# - Run: UVS12 Preload - "C:/Program Files/Corel/Corel VideoStudio 12/uvPL.exe"
	# - Service: UleadBurningHelper
	echot "\
	************************
	* VideoStudio
	************************
	"

	# VideoStudio, patches, and plug-ins
	pre=Corel/Video Studio 12

	run "$pre/setup/setup.exe"
	run "$pre/update/VSX2PROPATCH.exe"

	echo Installing Bonus Pack (WinDVD and media)... 
	run "$pre/Bonus Pack/AutoRun.exe"

	echo Installing Content Pack (SmartSound Quicktracks)...
	run "$pre/Content Pack/setup.exe"

	# Registry
	echo Updating registry...

	# Delete UVS12 Preload - C:/Program Files/Corel/Corel VideoStudio 12/uvPL.exe
	registry 32 delete "HKLM/SOFTWARE/Microsoft/Windows/CurrentVersion/Run/UVS12 Preload"

	# SmartSound
	echo Configuring SmartSound...
	MergeDir /r "c:/SmartSound Software" "$udata/SmartSound"
	echot "\
	- Audio, Audio, Auto Music, SmartSound QuickTracks, Folders
	  - Add Folder, Documents/data/SmartSound/Quicktracks/Library, Copy Destination
	"
	VideoStudio start
	pause
	$rmd "c:/SmartSound Software"

	# Icons
	echo "Updating icons..."
	$mergeDir /r "$pp/Corel VideoStudio 12" "$pp/Media/Other/VideoStudio"
	$mergeDir "$up/InterVideo WinDVD" "$pp/Media/Other"
	$mv "$pd/Corel VideoStudio 12.lnk" "$pp/Media/VideoStudio.lnk"

	$makeDir "$udoc/media/work/proxy"

	# Instructions
	echot "\
	- File, Preferences
	  - General
	      - Working folder=/Documents/media/work
	      - Check Display DV timecode on Preview Window (interferes with MaxiVista)
	  - Edit, check Cache image clips in memory
		- Capture
	    - Captured still image save format = JPEG
	  - (if data drive exists) Preview, uncheck 1, check 2=d:/temp
	  - Smart Proxy, Proxy folder=/Documents/media/work/proxy
	- Library
	  - Library manager, create Sample and Capture custom folders
	- Notes
	  - Additional content in install/Ulead/content
	"

	return

	:Bonjour
	# Installs Bonjour Service
	echot "\
	****************************
	* Bonjour Service Discovery
	****************************
	"

	run "Apple/Bonjour/BonjourSetup.exe"

	echo "Updating icons..."
	$mv "$pd/Bonjour Printer Wizard.lnk" "$pp/Operating System"
	$mergeDir "$pp/Bonjour" "$pp/Operating System/Other"

	return

	:AirPrint
	# Install AirPrint to enable printing from iOS devices
	# http://www.brucetdoesit.com/2011/08/airprint-for-windows-no-jailbreak-reqd.html
	echot "\
	************************
	* AirPrint
	************************
	"

	echo Installing the AirPrint service...
	echo - Install AirPrint Service, AirPrint Auth=Use Guest Account
	run "Shareware/AirPrint/setup/AirPrint_Installer.exe"
	pause

	registry import "$ExeDir/AirPrint iOS 5 FIX - $@OsBits[]Bit.reg"

	echot "\
	- Shared printers will be displayed as AirPrint printers
	"

	return

	:QuickTime
	# Reference http://www.QuickTime.com
	echot "\
	************************
	* QuickTime
	************************
	- Load software from Apple's site.  
	- Custom installation, select all options.
	"

	run "Apple/QuickTime/QuickTimeInstaller.exe"

	QuickTimePost

	echot "\
	- Edit, Preferences, QuickTime Preferences..., Advanced
	  - Uncheck Install QuickTime icon in system tray
	"

	return
	
	:JavaDevCore
	echot "\
	************************
	* Java Development
	************************
	"

	$makeDir "$pp/Development/Java/Other"

	echo Adding Java development registry entries...
	registry import "$setupFiles/JavaDev.reg"
	registry "HKLM/SOFTWARE/Classes/classfile/shell/open/command/" REG_SZ ^
		"$@search[tcc.exe]" /c JavaUtil.btm decompile "^$1" ^$*
	registry "HKLM/SOFTWARE/Classes/classfile/DefaultIcon/" REG_SZ ^
		"$pdoc/icons/Java-coffe.ico"

	# Add lib folder to CLASSPATH
	$makeDir "$PublicData/Lib"
	SetVar /path ClassPath "$PublicData/Lib"

	inst jdk JavaDoc JavaSource Ant Eclipse

	return

	:jdk
	# http://java.sun.com/javase/downloads/index.jsp
	# http://java.sun.com/products/archive/
	echot "\
	************************
	* Java Development Kit
	************************
	- (optional) Browser Registration, Uncheck Microsoft Internet Explorer
	"

	# Under x64 show both x86 and x64 JDKs
	pattern=$@if[ ${architecture} == x86 ,*-x86.exe,*.exe]

	do forever
		run "Sun/Java/jdk/$pattern"
		ask "Do you want to install another jdk?`
		if $? == 0 leave
	enddo

	echo Updating JAVA_HOME...
	ask "Do you want to update the JDK Home?" y
	if $? == 1 JavaUtil SetHome

	echo "Updating icons..."
	$rm "$pd/Java Web Start.lnk"
	$mergeDir "$pp/Java Web Start" "$pp/Operating System/Other"

	if $@IsInstalled[eclipse] == 1 then

		ask "Do you want to the default JRE for Eclipse?" y
		if $? == 1 eclipse select SetJre

		ask "Do you want to add the new JDK to Eclipse?" y
		if $? == 1 then
			eclipse select start
			echo - Window, Preference, Java, Installed JREs, Search..., $P/Java
			pause
		fi

	fi

	JavaFinal

	return

	:JavaDoc
	# http://java.sun.com/javase/downloads/index.jsp (current)
	# http://java.sun.com/javase/downloads/previous.jsp (previous)
	echot "\
	************************
	* Java Documentation
	************************
	"

	echo.
	echo Installing common documentation...
	installDir="$P/Java/doc"
	rcOpts=( "${rcOptsRegular[@]}" /xf *.zip )
	run "Sun/Java/doc" "$installDir"

	echo.
	echo Compacting documentation...
	CompactDir "$installDir"

	echo.
	echo Installing JDK documentation...
	run "Sun/Java/doc/jdk-*-docs.zip" "$P/Java/doc/$@name[$exe]""

	echo.
	echo Installing JDK language specification...
	run "Sun/Java/doc/langspec-*.zip" "$P/Java/doc/$@name[$exe]""

	echo.
	echo "Updating icons..."
	$makeShortcut "$P/Java/doc/default.html" "$pp/Development/Java/Java Doc.lnk"

	return

	:JavaSource
	# For DEBUG jar files, run jar setup and copy src.zip.
	# http://java.sun.com/javase/downloads/index.jsp (current)
	# http://java.sun.com/javase/downloads/previous.jsp (previous)
	echot "\
	************************
	* Java Source Code
	************************
	"

	FindExe Sun/Java/src/*-src*.zip
	if $_? != 0 return $_?

	installDir=$P/Java/src
	$makeDir "$installDir"

	# Copy source unextracted to source directory
	echo Copying Java source...
	CopyFile "$exe" "$installDir"

	if $@IsInstalled[eclipse] == 1 then

		echo Updating Eclipse with the new JDK source...
		ask "Do you want to update Eclipse with the new JDK source?" y
		if $? == 1 then
			eclipse select start
			echo $@ClipW[$installDir/$@FileName[$exe]] >& nul:
			echo - Window, Preference, Java, Installed JREs, select the JDK, Edit..., rt.jar, Source Attachment..., paste
			echo - Note: Some source is availble in the jdk directory in src.zip
		fi

	fi

	return

	:ant
	# http://ant.apache.org/bindownload.cgi
	echot "\
	************************
	* Ant - Java build tool
	************************
	"

	version=apache-ant-1.7.1

	installDir=$P/ant
	run "Java/Ant/$version-bin.zip"

	# ensure zip file does not conain extra level when unziupped
	if IsDir "$installDir/$version" then
		MoveAll "$installDir/$version" "$installDir"
	fi

	# Deploy custom ant.bat
	CopyFile "$ExeDir/ant.bat" "$P/ant/bin"

	# Update the path
	SetVar /system /path path "$installDir/bin"

	echo "Updating icons..."
	$makeDir "$pp/Development/Java/Other/Ant"
	$makeShortcut "$installDir/docs/index.html" "$pp/Development/Java/Ant Doc.lnk"
	$makeShortcut "$installDir/docs/index.html" "$pp/Development/Java/Other/Ant/Ant Doc.lnk"

	return

	:JProbe
	echot "\
	************************
	* JProbe
	************************
	"

	run "Quest Software/JProbe/setup/JProbeforWindowsEXEFormat_700.exe"

	echo "Updating icons..."
	$mergeDir "$up/JProbe 7.0" "$pp/Development/Other"
	CopyFile "$pp/Development/Other/JProbe 7.0/JProbe Console.lnk" "$pp/Development"

	return

	:DjJava
	# DjJava  uses the free JAD utility which is preferred if a GUI is not required.
	# V3.9.9.91, $20
	# http://members.fortunecity.com/neshkov/dj.html
	# Purchase - http://www.sharewareplaza.com/DJ-Java-Decompiler-download_38114.html
	# Purchase - http://www.softpedia.com/get/Programming/Debuggers-Decompilers-Dissasemblers/DJ-Java-Decompiler.shtml
	echot "\
	************************
	* DJ Java Decompiler
	************************
	"

	run "Java/DJ Java/SetupDJ.exe"

	echo "Updating icons..."
	$mv "$pd/DJ Java Decompiler 3.9.lnk" "$pp/Development"
	$rm "$pp/DJ Java Decompiler 3.9.lnk"

	echo Copying license files...
	CopyFile "$install/Shareware/DJ Java/dj.exe" "$P32/decomp"
	CopyFile "$install/Shareware/DJ Java/Archiver.exe" "$P32/decomp"

	ask "Do you want to update the configuration files?" n
	if $? == 1 then
	  echo Copying configuration files...
	  CopyDir "$install/Shareware/DJ Java/DJ Java Configuration" "$P32/decomp"
	fi

	RunProg "$P32/decomp/DJ.exe"

	echot "\
	- Check I have a serial number and want to activate DJ Java Decompiler now.
	- Settings, Decompiler Settings...
	  - Check Output original line numbers as comments
	- Settings, Configuration
	  - Check Disable Save Dialog (on Close)
	  - Select the Output Directory for .JAD files=$temp
	  - Select Initial Directory for Open dialog: (on Open)=c:/code
	"

	return

	:VirusScan
	# (McAfee products though comcast.net)  http://us.mcafee.com/root/dashboard.asp?affid=108
	# (Intel home use) McAfee 8.0i and updates available for home use at 
	#   http://secure.intel.com/InfoSec/Response_Services/PC+and+Network+Protection/Anti-Virus/Home+Computer+Anti-Virus+Software.htm
	#   file://fmea1pub006/Anti_Virus_Software/VirusScan_Home_User_CD/McAfee80i/MVSE80iHomePC.EXE
	#   unc: //fmea1pub006/Anti_Virus_Software
	# Vista
	# - Beta program - https://secure.nai.com/apps/downloads/beta/login.asp?region=us&segment=enterprise
	# - http://www.mcafee.com/us/enterprise/downloads/beta/beta_mcafee/vse_vista.html
	# - http://secure.nai.com/us/enterprise/downloads/beta/beta_mcafee/vse.html
	# Memory usage ~82MB, minimal performance impact.
	# When uninstsalling:
	# - Stop Network Associate and McAfee services
	# - Autoruns, delete Network Associates and McAfee services (McAfee Framework Service, McAfeeUpdaterUI)
	# - Delete c:/Program Files/Network Associates McAfee Framework
	echot "\
	************************
	* VirusScan
	************************
	"

	if "$UserDomain" == "AMR" .or. defined server then
	  exe=McAfee/VirusScan V8.0i/VSE84564.EXE
	elif defined NewOs then
	  echo VirusScan for new operating systems not available.
		return 1
	else
	  run "McAfee/VirusScan V8.0i/MVSE80iHomePC.EXE"
	fi

	$makeDir "$AllUsersProfile/documents/data/quarantine"

	echo "Updating icons..."
	$mergeDir "$pp/Network Associates" "$pp/Operating System/Other"
	$mergeDir "$pp/McAfee" "$pp/Operating System/Other"

	# Delete ShStatEXE - C://Program Files//Network Associates//VirusScan//SHSTAT.EXE/" /STANDALONE
	registry 32 delete "HKLM/SOFTWARE/Microsoft/Windows/CurrentVersion/Run/ShStatEXE"

	# Delete McAfeeUpdaterUI - "C:/Program Files/Network Associates/Common Framework/UpdaterUI.exe" /StartedFromRunKey
	registry 32 delete "HKLM/SOFTWARE/Microsoft/Windows/CurrentVersion/Run/McAfeeUpdaterUI"

	# Delete Network Associates Error Reporting Service - C://Program Files//Common Files//Network Associates//TalkBack//tbmon.exe/"
	registry 32 delete "HKLM/SOFTWARE/Microsoft/Windows/CurrentVersion/Run/Network Associates Error Reporting Service"

	# Delete McAfeeUpdaterUI - /"C://Program Files//Network Associates//Common Framework//UpdaterUI.exe/" /StartedFromRunKey
	registry 32 delete "HKLM/SOFTWARE/Microsoft/Windows/CurrentVersion/Run/McAfeeUpdaterUI"

	VirusScan setup

	echot "\
	- VirusScan Console...,
	  - Scan All Fixed Disks, Schedule, uncheck Enable
	  - On-Access Scanner
	    - General Settings, General
	      - Check Enable on-access scanning at system startup
	      - Quarantine Folder=$udoc/data/quarantine
	    - All Processes, Detection, Exclusions..., Add jphelp.chm
	  - Buffer Overflow Protection, Disable
	  - On-Delivery E-mail Scanner, Disable
	  - (Virtual Machine) Tools, Edit AutoUpdate Repository List..., Add..., 
	    - Repository Description=Intel HTTP
	    - URL=virusscan.intel.com/mcafee/80i
	    - port=9876
	"

	return

	:AutoEnhance

	run "MediaChance/DCE Auto Enhance Pro V2.0/dcefull.exe"

	echo "Updating icons..."
	$mv "$ud/DCE AutoEnhance.lnk" "$pp/Applications"
	$mergeDir "$pp/DCE AutoEnhance" "$ao"

	return

	:ComponentOne
	echot "\
	************************
	* Component One
	************************
	- SN: SE40309-YC-100001, SE40309-LN-100000
	"

	run "Component One/Studio Enterprise Q32003/C1StudioNet_Q303.msi"   
	run "Component One/Studio Enterprise Q32003/C1StudioAsp_Q303.msi"

	echo "Updating icons..."
	$mergeDir "$pp/ComponentOne Studio.NET" "$pp/Development/Other"
	$mergeDir "$up/ComponentOne Studio.NET" "$pp/Development/Other"
	$mergeDir "$pp/ComponentOne Studio ASP.NET" "$pp/Development/Other"
	$mergeDir "$up/ComponentOne Studio ASP.NET" "$pp/Development/Other"

	return

	:DundasChart
	echot "\
	************************
	* Dundas Chart
	************************
	- ASP.NET: Username: john.butare@intel.com, Password: 043-170-134-181
	- Windows Forms: Username:john.butare@intel.com, Password:046-160-137-023
	"

	run "Dundas/Dundas Chart.NET Pro Edition V3.0/DCWCP30.exe"
	run "Dundas/Dundas Chart for Windows Forms V3.0/DCWFP30.exe"

	echo "Updating icons..."
	$mergeDir "$pp/Dundas Software" "$pp/Development/Other"
	$mergeDir "$up/Dundas Software" "$pp/Development/Other"

	return

	:WebTrends
	echot "\
	************************
	* WebTrends
	************************
	- Don't enter license information during setup
	- services to Manual if this machine is a backup WebTrends server
	"

	run "NetIQ/WebTrends Reporting Center eBusiness V4.0c/setup.exe"

	echo "Updating icons..."
	$mergeDir "src=$pp/(directory name)" "$ao"

	echot "\
	- Local Security Policy, grant IUIS System "Act as part of the operating system"
	- Services, "WebTrends Reporting Center" and "WebTrends Reporting UI", run as IUIS System
	- In c:/Program Files/WebTrends Reporting Center/wtm_wtx/datfiles/profiles
	  #ove unwanted profiles and copy new profiles from $SharedDocuments/Projects/WebTrends/Profiles
	- (Re)start services
	- Start WebTrends Reporting Center
	  - Enter Product Serial Numbers: 40000BE-EGE-4H3g32rE-2ee000L
	  - Login, don't put domain in for User Name  
	  - Help, Product Links, Subscription/Add-ons, 40010z5-EGE-4H3g32X1-2dj000C
	  - Configuration, User Access, add users as needed
	  - Configuration, Options, General Options
	    - Report Serving
	      - Select Specigy a diferent web server for serving the reports
	      - Report Directory - d:/Projects/WebTrends/$PROFILE$.wlp
	      - Report URL Path - http://IuApp.Intel.Com/WebTrends/$PROFILE$.wlp/index.html.
	        - Note: http://IuApp.Intel.Com/WebTrends should be setup as a virtual directory
	          that is a share located on another computer, which points to the WebTrends
	          computer, such as //rrs3app002/d$/Projects/WebTrends.  It should be to 
	          Connect As IUIS System.
	    - Reporting Method, select Pre-generated Reports      
	    - Reports, check all Report Types, all Report to Store to 1 Year or equivalent
	    - Scheduler, Frequency - 2 hours
	- Stop services if needed
	"

	return

	:ProVision
	echot "\
	************************
	* ProVision
	************************
	"

	run "Proforma/ProVision/InstallProvision.exe"

	copy $install/Proforma/License/pvwlicense.lic c:/PVLicServer/Licenses

	echot "\
	- Note: If want to, EDM can host license server and possibly pool licenses (Russel Lambert)
	- Run ProVision Floating License Server Utility.  On the Config Server tab,
	  Path to the lmgrd.exe file to C:/PVLicServer/lmgrd.exe.  Path to
	  the license file to C:/PVLicServer/Licenses/pvwlicense.lic.  Click Save Service.
	  On the Start/Stop/Reread tab click Start Server.
	- Share C:/PVLicServer read only as "ProVision License".  Users can view licenses log
	  at //rrs3app002/ProVision License/pvlicServer.log
	"
	pause

	return

	:NortonAntiVirusCorporate
	# When uninstsalling:
	# - #ove "$P32/Symantec AntiVirus"
	# - #ove "$AllUsersProfile/Application Data/Symantec"
	# - Autoruns, delete Startup/VPtray
	echot "\
	- Mem usage ~32.5MB
	- Client, Unmanaged
	"

	# Intel
	# exe=Symantec/Norton AntiVirus V8.1 Corporate Edition/savce81825-32.EXE

	run "Symantec/Norton AntiVirus V10.0 Corporate Edition/SAV/Setup.exe"

	echo "Updating icons..."
	CopyFile "$pp/Symantec Client Security/Symantec AntiVirus Client.lnk" "$pp/Operating System/AntiVirus.lnk"
	$mergeDir "$pp/Symantec Client Security" "$pp/Operating System/Other"

	RunProg autoruns


	echot "\
	- Symantec AntiVirus, Configure, File System Auto-Protect, Advanced, 
	  - Auto-Protect will scan files that are Modified
	- autoruns
	  - Uncheck vptray (tray icon)
	  - (Intel build) Uncheck RasC service and rascagnt - Intel Terminus Agent, since it does not recognize Norton AntiVirus as valid virus software, must run terminus manually.
	- Notes
	  - V8.X of NAV cannot report status to Windows Security Center
	  - Can be installed on client or server, less disk overhead than McAfee
	  - Uninstall password: symantec
	  - Manual update at virusscan.(rr/sc).intel.com or http://securityresponse.symantec.com/avcenter/download.html.
	endtrxt
	pause

	$rmd "c:/CAPLOG"
	$rmd "c:/CAPTMP"

	return

	:Mirada
	echot "\
	************************
	* Mirada
	************************
	- Install to C:/Program Files/mirada
	emdtext

	run "UNM/Mirada V5.0/Setup.exe"

	echo "Updating icons..."
	$rm "$pd/Mulberry CBT.lnk"
	$rm "$pd/Using Mulberry at UNM.lnk"
	$rm "$pd/Mirada Shortcut.lnk"
	$mergeDir "$pp/Mirada" "$ao"
	$makeDir "$users/lluna/Desktop/Mirada"
	CopyDir "$ao/Mirada" "$dir"

	return

	:PerformanceTest
	echot "\
	************************
	* PerformanceTest
	************************
	- User: John Butare
	- Key : 000H7V-5CUEEB-T4K4E4-1QHDW4-HV420Z-E29ARN-4JZZKX
	"

	run "PassMark Software/Performance Test V6.0/petst.exe"

	echo "Updating icons..."
	$mergeDir "$pp/PerformanceTest" "$pp/Operating System/Other"

	return

	:MicrosoftDb2Drivers
	# This references an older version of the HIS which no longer works under VB6 with TESS
	echot "\
	************************
	* Microsoft DB2 Drivers
	************************
	- *** Install cannot be run from terminal server ***
	- Seelct Features,  Data Integration
	  - ODBC Driver for DB2
	  - OLE DB Provider for DB2
	"

	run "Microsoft/Host Integration Server/client V2002 SP1/HIClient.msi"
	run "Microsoft/Host Integration Server/client V2002 SP1/HIS2000-KB815012-All-ENU.EXE"

	# Encountered errors using linked server with SP2
	# run "Microsoft/Host Integration Server/client V2002 SP2/HIClient.msi"

	echo "Updating icons..."
	$mergeDir "$pp/Host Integration Server End-User Client" "$pp/Operating System/Other"

	return

	:RUndelete
	#  http://www.r-undelete.com/Download.shtml 
	echot "\
	************************
	* r-undelete
	************************
	- Key V2.0: RAAALr/t9UOTiCdB4k5oCd/QvRUsq4aqfSkcf1NLnWDE8Zt0753JcQLlTCd8vdcRCPYwJZt04o6hnv01BpnGkXhDz9Vb
	- Key V1.0: RAAAOoPpnSk7VWRRj6DSNWJRHu9fgNRJ7weuGLDNRmeQJF98TCcCwQnRNj9nzbWwPK7TrQkRFnTzpVyGQtwxKzCsX1MI
	- Order ID: SCQVWPQMZCZP and CC first 4246/last 4362
	- 2.0 does not appear work with ZIP disks, 1.0 does
	"

	run "r-tools/r-undelete V1.0/ruu_en_10.exe"

	echo "Updating icons..."
	$mergeDir "$pp/R-UNDELETE" "$pp/Operating System/Other"

	return

	:BitPim
	# http://www.bitpim.org/#download
	echot "\
	************************
	* BitPim
	************************
	"

	run "Shareware/BitPim/bitpim-1.0.6-setup.exe"

	# Copy the standard C runtime library if it is not installed
	if "$@search[msvcp71.dll]" == "" then
		CopyFile "$install/Shareware/BitPim/msvcp71.dll" "$P32/BitPim"
	fi

	echo "Updating icons..."
	$mergeDir "$pp/BitPim" "$ao"

	ask "Configure default phone?" y
	if $? == 1 then

		echo Configure default phone...
		start /pgm "$P32/BitPim/bitpimw.exe"
		pause

		echo Moving default phone directory...
		$makeDir "$udata/BitPim"
		MoveAll "$udoc/bitpim" "$udata/BitPim/$@FullName[]"
		
		$makeShortcut "$udata/BitPim/$@FullName[]/.bitpim" "$pp/Applications/BitPim $@FullName[].lnk"
		
	fi


	echot "\
	- Notes
	  - Shift-Add to bypass conversion dialogs (which sometimes crash)
	"

	return

	:FxCop
	echot "\
	************************
	* FxCop
	************************
	"

	run "Microsoft/.NET/FxCop/FxCopInstall1.35.MSI"

	CopyFile "$ExeDir/FxCop.chm" "$P32/Microsoft FxCop 1.35"

	echo "Updating icons..."
	$mergeDir "$pp/Microsoft FxCop 1.35" "$pp/Development/Other"
	CopyFile "$pp/Development/Other/Microsoft FxCop 1.35/FxCop.lnk" "$pp/Development"

	# Update Geckos FxCop files
	GeckosUpdateFxCop

	echot "\ 
	- Visual Studio 2003
	  - Tools, External Tools
	    - Add
	      - Title=FxCop
	"
	echo `      - Command=$P32/Microsoft FxCop 1.30/FxCopCmd.exe`
	echot "\
	      - Arguments=/f:$(TargetPath) /c /p:"c:/Projects.NET/Common/FxCop/Geckos Rules.FxCop" /i:"c:/Projects.NET/Common/FxCop/Geckos.FxCop"
	      - Check Use Output window
	    - Add
	      - Title=FxCop Geckos
	"
	echo `      - Command=$P32/Microsoft FxCop 1.30/FxCop.exe`
	echot "\
	      - Arguments="c:/Projects.NET/Common/FxCop/Geckos.FxCop"
	    - Move command near the top of the External Commands list to position n 
	  - (optional to put command on toolbar) Right click on toolbar, Customize, Commands, Tools
	    - Drag External Command n to toolbar
	    - Right click on External Command n, check Begin a Group.
	- Ensure that the two FxCop files in $/Projects.NET/Common are up to date
	- (optional) After running FxCop, double click on the Output window to expand it
	"

	return

	:NDoc
	echot "\
	************************
	* NDoc
	************************
	- Un-check 1.0 framework
	"

	run "Shareware/NDoc/NDoc-1.3-beta1a.msi"
	run "Microsoft/Visual Studio .NET Help Integration Kit/VSHIK2003.exe"
	run "The Helpware Group/H2Reg/h2reg_setup136.exe"

	NDocGui=$P32/NDoc 1.3/bin/net/1.1/NDocGui.exe

	echo "Updating icons..."

	$mergeDir "$up/NDoc 1.3" "$pp/Development/Other"
	$mergeDir "$pp/Helpware" "$pp/Development/Other"

	CopyFile "$pp/Development/Other/NDoc 1.3/Microsoft .NET 1.1/NDoc.lnk" "$pp/Development"

	echot "\ 

	- Visual Studio 2003, Tools, External Tools
	  - Add
	    - Title=NDoc
	"
	echo `    - Command=`$NDocGui
	echot "\
	    - Move commands near the top of the External Commands list to position n 
	  - (optional to put command on toolbar) Right click on toolbar, Customize, Commands, Tools
	    - Drag External Command n to toolbar
	    - Right click on External Command n, check Begin a Group.
	- Ensure that the two FxCop files in $/Projects.NET/Common are up to date
	"

	return

	:NAnt
	echot "\
	************************
	* NAnt - .NET build tool
	************************
	"

	installDir=$P32/NAnt
	run "Shareware/.NET/NAnt/nant-0.85-20040812.zip"

	# Update the  path
	SetVar /s /p path "$installDir/bin"

	echo "Updating icons..."
	$makeDir "$pp/Development/.NET/Other/NAnt"
	$makeShortcut "$installDir/doc/index.html" "$pp/Development/.NET/Other/NAnt Documentation.lnk"
	$makeShortcut "$installDir/doc/index.html" "$pp/Development/.NET/NAnt Documentation.lnk"

	echo $@ClipW[$installDir/NAnt.exe] >& nul:
	echot "\
	- Tools, External Tools
	  - Add
	    - Title=NAnt
	    - Command=<paste>
	      - Arguments=1.1 debug undeploy
	      - Initial directory=$(SolutionDir)
	      - Check Use Output window
	      - Check Prompt for arguments 
	    - Move command near the top of the External Commands list to position n 
	  - (optional to put command on toolbar) Right click on toolbar, Customize, Commands, Tools
	    - Drag External Command n to toolbar
	    - Right click on External Command n, check Begin a Group.
	- *** Additional required components ****
	- Install Framework 1.0a to enable cross compilation to the .NET Framework 1.0
	"
	VisualStudio

	return

	:SnippetCompiler
	echot "\
	************************
	* Snippet Compiler
	************************
	"

	run "Microsoft/.NET/SnippetCompiler"

	echo "Updating icons..."
	$makeShortcut "$ProgramDir/SnippetCompiler.exe" "$pp/Development/Snippet Compiler.lnk"

	return

	:Regulator
	echot "\
	************************
	* Regulator
	************************
	"

	run "Microsoft/.NET/Regulator/RegulatorSetup.msi"

	echo "Updating icons..."
	$rm "$ud/The Regulator.lnk"
	$mv "$up/The Regulator.lnk" "$pp/Development/Regulator.lnk"

	return

	:Reflector
	echot "\
	************************
	* Reflector
	************************
	"

	echo "Updating icons..."
	$makeShortcut "c:/Data/Bin/Reflector.exe" "$pp/Development/Reflector.lnk"

	return

	:DeviceCenter
	# Installs
	# - Services: RapiMgr, WcesComm
	# - Run: HKEY_LOCAL_MACHINE/SOFTWARE/Microsoft/Windows/CurrentVersion/Run/Windows Mobile Device Center=$windir$/WindowsMobile/wmdc.exe
	echot "\
	*************************************
	* Windows Mobile Sync (Device Center)
	*************************************
	"

	if defined NewOs then
		run "Microsoft/Mobile/Device Center/Mobile Device Center V6.1 ${architecture}.exe"
	else
		run "Microsoft/Mobile/Device Center/ActiveSync V4.2.exe"
	fi

	echo "Updating icons..."
	$mv "$ud/Windows Mobile Device Center.lnk" "$pp/Applications"
	$mv "$pp/Windows Mobile Device Center.lnk" "$pp/Applications"
	$mv "$pp/Microsoft ActiveSync.lnk" "$pp/Applications/ActiveSync.lnk"

	# Delete H/PC Connection Agent - "C:/Program Files/Microsoft ActiveSync/WCESCOMM.EXE"
	registry 32 delete "HKLM/SOFTWARE/Microsoft/Windows/CurrentVersion/Run/H/PC Connection Agent"
	registry 32 delete "HKCU/SOFTWARE/Microsoft/Windows/CurrentVersion/Run/H/PC Connection Agent"


	echot "\
	- Reference: "//oversoul/John/Documents/Products/Microsoft/Pocket PC.doc"
	- Place the PPC in the cradle
	- Synchronize with this desktop computer, Next
	- (primary PC)
	  - Check only Contacts, Calendar, E-mail, Tasks, Notes
	  - Double click Tasks, select Synchronize all tasks (otherwise, completed tasks in Outlook do not complete on PPC)
	- (secondary PC) 
	  - No, I want to synchronize with two computers (does not delete existing partnership), Next
	  - Uncheck Calendar, Contacts, Inbox, Tasks, and Favorites (IMPORTANT: Favorites and Files must be unchecked, see notes above), Next, Finish.
	- ActiveSync, Tools
	  - Add/#ote Programs, uncheck Install program into the default installation folder
	  - Options, Rules, uncheck Open ActiveSync when my mobile device connects
	"

	return

	:eWallet
	# http://www.iliumsoft.com/site/support/kb/article.php?id=123
	# Issues: when running causes video to stutter
	echot "\
	************************
	* eWallet
	************************
	"

	run "Ilium Software/eWallet/eWallet v7.1.1.29661.exe"
	run "Ilium Software/eWallet/ewalletautopass.xpi"
	run "Ilium Software/eWallet/FlexWalletIconPack-WinMobile-PE-Setup.exe"

	echo "Updating icons..."
	$rm "$ud/eWallet.lnk"
	$mergeDir "$pp/Ilium Software" "$ao"
	$mergeDir "$up/Ilium Software" "$ao"

	echo Moving data folder...
	$makeLink --merge --hide "$udata/eWallet" "$udoc/eWallet"

	echot "\
	- File/Open..., Documents/data/eWallet/wallet.wlt
	- Help, About eWallet, Register
	- (optional) Synchronize, Setup
	  - Copy #ote wallet to local data/eWallet
	  - Add... 
	    - (PC) Another Computer
	      - Location Name=Oversoul
	      - Location Path=//oversoul/John/Documents/data/eWallet
	    - (iPod) eWallet, Synchronize (PC) Synchronize Add..., iPhone or iPod touch
	  - Home, Setup, Options
	    - Syncronize Wallet Files=Manually Only
	    - Confirm each synchronization=Never
	- (Android) 
	  - Download and run eWallet from the Android store
	  - phone USB, notifications, USB connection, USB connection=USB Mass Storage
	  - eWallet, Setup, Add..., Android
	- (iPod) Download from store
	- (BlackBerry) BlackBerry Desktop Manager
	  - Application Loader, Start, check eWallet
	  - Synchronization, Add-ins, check eWallet Synchronizer, Configure
	    - Add, Documents/data/eWallet/Wallet.wlt
	    - Settings..., select Desktop overwrites BlackBerry, sync, select Full Sync
	"
	eWallet.btm start

	return

	:DockWare
	echot "\
	************************
	* DockWare
	************************
	"

	run "Ilium Software/DockWare Pro V2.0/DockWareProPKTSetup.exe"

	echo "Updating icons..."
	PpcMoveLink "DockWare" "Applications"

	echot "\
	- DockWare - may need to rePPC
	  - Display Options..., Clock=Digital Clock, Calendar=Long Date
	  - Picture Options..., check Use Transitions, change picture after 5 seconds, Picture Order=Random,
	    check Scale JPEG pictures to fit screen,  
	  - Picture Folders..., check Include All Pictures from Memory Card=Storage Card
	  - Date/Time Color..., 79, 255, 159
	  - Setup..., check Automatically Start DockWare after Pocket PC is idle for 2 minutes
	"

	return

	:PocketQuicken
	echot "\
	************************
	* PocketQuicken
	************************
	"

	run "LandWare/PocketQuicken V2.03/PocketQuickenPPC203_Install.exe"

	echo "Updating icons..."
	$mergeDir "$up/Pocket Quicken 2.0 for Pocket PC" "$ao"
	$mergeDir "$up/Quicken" "$ao"
	PpcMoveLink "Pocket Quicken" "Applications/Quicken.lnk"


	echot "\
	- PPC
	  - Start, Settings, Personal, Owner Information, Name=jbutare.  Note: Must keep owner name=jbutare.
	  - Start Pocket Quicken, Activate, should display Owner Name=jbutare, User ID: 81184572, enter 
	    registration code 199360 (was 11264334)
	- ActiveSync, right click on Pocket Quicken, Settings..., select Upon each connection, synchornize once per day, 
	  check Hide Pocket Quicken Connect when synchornizing
	"

	return

	:AdobeReaderPpc
	echot "\
	************************
	* PPC Acrobat Reader
	************************
	- PPC installation dialog, Name=(Install Here)
	"

	run "Install/Adobe/Acrobat Reader for Pocket PC V2.0/AdbeRdr20_ppc_enu.exe"

	echo "Updating icons..."
	PpcMoveLink "Acrobat Reader 1.0" "Applications/Acrobat.lnk"

	return

	:WindowsMobileDev
	printf "**************************************************\n* Windows Mobile Development\n**************************************************\n"
	SDK - Microsoft/Mobile/Development/en_windows_moblile_50_Dev_resource_kit.msi
	PowerToys - Microsoft/Pocket PC/Development/WindowsMobilePowerToys V1.0.msi
	PowerToyes EMU Configuration - Microsoft/Pocket PC/Development/EmuASConfig.msi
	"

	return

	:Firefox
	# Released - https://www.mozilla.com/en-US/firefox/fx/?from=getfirefox
	# Minefield (trunk build) - http://www.mozilla.org/projects/minefield/
	echot "\
	************************
	* Firefox
	************************
	- Uncheck Use Firefox as my default web browser
	- Don't import anything
	- Close FireFox
	"

	# ask "Install beta? ` n
	version=$@if[ 0 == 1 ,NA,18.0.1]
	run "Mozilla/Firefox/setup/Firefox Setup v$version$.exe"	

	echo "Updating icons..."
	$rm "$pd/Mozilla Firefox*.lnk"
	$rm "$pp/Mozilla Firefox*.lnk"
	$mergeDir --rename "$pp/Mozilla Firefox" "$ao/Firefox"

	# Pre-release icons
	$mergeDir "$pp/Minefield" "$ao"
	$rm "$pd/Minefield.lnk"

	echo Restoring the default profile...
	firefox profile restore default

	echot "\
	- Options
	  - General, When Firefox starts Show my home page
	  - Tabs
	    - uncheck Warn me when closing multiple tabs
	    - check Show tab previews in the Windows taskbar
	  - Advanced
	    - General
	      - Check Search for text when I start typing
	      - Check Use smooth scrolling
	- about:config
	  - network.automatic-ntlm-auth.trusted-uris=localhost,intel.com,goto
	  - network.negotiate-auth.trusted-uris=intel.com
	  - browser.sessionstore.resume_from_crash=true
	- Tools, Options, Advanced, Encryption, View Certificates, Authorities, Import..., 
	  data/certificate/public: Intel*, check Trust this CA to identify web sites
	"
	firefox.btm start
	pause

	ask "Do you want to install extensions?"
	if $? == 1 then
		firefox.btm extension
		pause
	fi

	echo Saving profile changes...
	firefox.btm profile backup

	return

	:RoboHelp
	echot "\
	************************
	* RoboHelp
	************************
	- SN RH011-QTZLSVRL (may be O)
	"

	return

	:VMwarePlayer
	echot "\
	************************
	* VMware Player
	************************
	"

	run "VMware/player/VMware-player-2.0.4-93057.exe"

	echo "Updating icons..."
	$rm "$pd/(desktop file to delete).lnk"
	$mergeDir "$pp/(directory name)" "$ao"


	echot "\
	- (Display post-installation instructions)
	"

	return

	:VMwareServer
	# Download - http://www.vmware.com/download/server/
	# For management, 1.x uses a GUI console, 2.x uses web console
	echot "\
	************************
	* VMware Server
	************************
	- If install fails, disabled installer verification and installer cache to 0
	"

	run "VMware/server/setup/VMware-server-2.0.0-122956.exe"

	echo "Updating icons..."
	$mv "$pd/VMware Server Home Page.lnk" "$pp/Operating System"
	$mv "$pd/VMware Server Console.lnk" "$pp/Operating System"
	$mv "$pd/VMware Virtual Machine Importer 2.lnk" "$pp/Operating System"

	$mergeDir "$pp/VMware" "$pp/Operating System/Other"
	$mergeDir "$up/VMware" "$pp/Operating System/Other"

	if $@IsWindowsClient[] == 1 then
	  echo "Updating firewall..."
	  firewall rule add "VMware Server Console" `dir=in action=allow protocol=TCP localport=902 profile=private,domain program="$P32$/VMware/VMware Server/vmware-authd.exe"`
	  service restart VMAuthdService
	fi


	echot "\
	- VMware Server Console, Summary
	  - Datastores, standard, #ove Datastore
	  - Datastores, Add Datastore, C:/Documents and Settings/All Users/Documents/data/VMware
	- VMWare Server Home Page, Continue to this website, Certificate Error, View certificates, Install Certificate...,
	  Place all certificates in the following store, Trusted Root Certificate Authorities
	"

	return

	:VMwareConsole
	echot "\
	************************
	* VMware Console
	************************
	"

	run "VMware/server/setup/VMware-console-1.0.2-39867.exe"
	run "VMware/server/setup/VMware-VmCOMAPI-1.0.2-39867.exe"

	$mv "$pd/VMware Server Console.lnk" "$pp/Operating System/Other"
	$mergeDir "$up/VMware" "$pp/Operating System/Other"
	$mergeDir "$pp/VMware" "$pp/Operating System/Other"

	return

	:SymbolServer
	# Reference
	# - Setup: http://msdn.microsoft.com/msdnmag/issues/02/06/Bugslayer/
	# - Symbol Download: http://www.microsoft.com/whdc/devtools/debugging/debugstart.mspx
	echot "\
	************************************
	* Symbol Server
	************************************
	- Add a symbols DNS entry for $ComputerName and disable strict LAN Manager name checking
	"

	if "$@search[SymStore]" == "" then
		echo Debugging tools for windows is not installed.
		return 1
	fi

	# Initialize
	SymbolDir=$AllUsersProfile/Documents/data/symbols
	echo $@ClipW[$SymbolDir] >& nul:

	# Create and compress symbol directory
	$makeDir "$SymbolDir"
	if $@wattrib["$SymbolDir",c] == 0 then
	  echo Compressing symbols...
	  CompactDir "$SymbolDir"
	fi

	echo Sharing symbol folder as symbols...
	net share "symbols"="$SymbolDir" $netShareOptions /#ark:"Symbol Server" >& nul:

	FindExe "Microsoft/debugging/symbols"
	if $_? != 0 return $_?

	symbols=$exe

	# Windows 7 and Windows Server 2008 R2
	args=`/c:"symbols.exe /u $dest"`
	InstallSymbolPackage "Windows 7" "Build 7600 x86 free" en_windows_7_debugging_symbols_x86_398756.msi
	InstallSymbolPackage "Windows 7" "Build 7600 x64 free" en_windows_7_and_windows_server_2008_r2_debugging_symbols_x64_398754.msi

	# Windows Vista with SP1 and Windows Server 2008
	args=`/c:"symbols.exe /u $dest"`
	InstallSymbolPackage "Windows Longhorn" "Build 6001 x86 free" Windows_Longhorn.6001.080118-1840.x86fre.Symbols.exe
	InstallSymbolPackage "Windows Longhorn" "Build 6001 x64 free" Windows_Longhorn.6001.080118-1840.amd64fre.Symbols.exe

	# Windows Server 2003 with SP2
	args=`/u "$dest"`
	InstallSymbolPackage "Windows Server 2003" "Build 5.2.3790 x86 free" WindowsServer2003-KB933548-v1-x86-symbols-NRL-ENU.exe
	InstallSymbolPackage "Windows Server 2003" "Build 5.2.3790 x64 free" WindowsServer2003-KB933548-v1-x64-symbols-NRL-ENU.exe

	# Windows XP with SP3
	args=`/u "$dest"`
	InstallSymbolPackage "Windows XP" "Build 5.2.2600 x86 free" WindowsXP-KB936929-SP3-x86-symbols-update-ENU.exe

	return

	:InstallSymbolPackage [product version installer]

	prog=$symbols/$@UnQuote[$installer]
	if not IsFile "$prog" return

	description=$@unquote[$product] $@unquote[$version]
	ask "Do you want to install symbols for $description?" y
	if $? ==  0 return 1	

	# Ensure empty dest dir exists
	dest=$temp/symbols
	$rmd "$dest"
	$makeDir "$dest"

	echo.
	echo Installing symbols for $description...

	"$prog" $args
	SymStore add /r /f "$dest" /s "$SymbolDir" /t $@quote[$product] /v $@quote[$version]

	$rmd "$dest"

	return

	:SourceServer
	# Reference: http://msdn.microsoft.com/msdnmag/issues/06/08/usethesource/default.aspx
	echot "\
	************************************
	* Source Server
	************************************
	"

	FindExe "Microsoft/Source Server"
	if $_? != 0 return $_?

	# Initialize
	SourceServerinstallDir=$exe
	SourceServerDir=$P32/Source Server
	DebuggingToolsDir=$P32/Debugging Tools for Windows
	VsDir=$P32/Microsoft Visual Studio 8/Common7/IDE

	# If debugging tools for windows is installed update SourceServer files
	if exist "$P32/Debugging Tools for Windows/sdk/srcsrv" then
	  CopyDir "$DebuggingToolsDir/sdk/srcsrv" "$SourceServerinstallDir"
	  CopyFile "$DebuggingToolsDir/srcsrv.dll" "$SourceServerinstallDir"
	fi

	# Do not up the source server if VS is not installed
	if not exist "$P32/Microsoft Visual Studio 8/Common7/IDE" return 0

	# Update the VSS integration component
	CopyFile "$SourceServerinstallDir/srcsrv.dll" "$vsDir"
	CopyFile "$SourceServerinstallDir/SrcSrvTemplate.ini" "$vsDir/SrcSrv.ini"

	CopyDir "$SourceServerinstallDir" "$SourceServerDir"
	CopyFile "$SourceServerinstallDir/SrcSrvTemplate.ini" "$SourceServerDir/SrcSrv.ini"

	SetVar /s /p path "$SourceServerDir"

	return

	:DebuggingTools
	# Reference http://www.microsoft.com/whdc/devtools/debugging/debugstart.mspx
	echot "\
	************************************
	* Debugging Tools for Winodws
	************************************
	- Custom
	  - (optional) Debug Transport Drivers (installs 1394DBG2.SYS)
	"

	run "Microsoft/debugging/setup/dbg_${architecture}_6.9.3.113.msi"

	echo Updating the path...
	SetVar /s /p path "$P/Debugging Tools for Windows (${architecture})"

	echo "Updating icons..."
	$mergeDir "$pp/Debugging Tools for Windows (${architecture})" "$pp/Operating System/Other"

	echo Initializing debuging symbol information...
	debugging symbols init

	return

	:MicrosoftMouse
	:IntelliPoint
	echot "\
	*******************
	* Microsoft Mouse
	*******************
	- IntelliPoint is useful for battery level.
	"

	run "Microsoft/IntelliPoint/IPx64_1033_7.10.344.0.exe"

	echo "Updating icons..."

	$rm "$pd/Microsoft Keyboard.lnk"
	$mergeDir "$pp/Microsoft Keyboard" "$ao"

	$rm "$pd/Microsoft Mouse.lnk"
	$mergeDir "$pp/Microsoft Mouse" "$pp/Operating System/Other"

	return

	:RealVNC
	# editions - free, personal (P), and enterprise (E)
	# download - http://www.realvnc.com/products/download.html
	# Intel - //Vmspfsfsch09/dev_rndaz/LicensedSoftware/VNC Enterprise Edition (vnc-E4_5_4-x86_x64_win.exe)
	echot "\
	****************************
	* RealVNC
	****************************
	- Uncheck Start the VNC Server in Service-Mode
	"

	ask 'Install Intel version?' n
	if $? == 1 then
		run "RealVNC/setup/vnc-E4_5_4-x86_x64_win.exe"
	else
		run "RealVNC/setup/VNC-5.0.3-Windows.exe"
	fi

	echo "Updating icons..."
	CopyFile "$pp/RealVNC/VNC Viewer/Run VNC Viewer.lnk" "$pp/Operating System/VNC.lnk"
	$mergeDir "$pp/RealVNC" "$pp/Operating System/Other"

	echot "\
	- Server, Options
	  - Security
	    - Select NT Logon Authentication
	    - Check Allow Single Sign-On authentication
	  - Inputs
	    - Check Disable local inputs while server is in use
	  - Desktop
	    - Uncheck #ove wallpaper, #ote background pattern, and Disable user interface effects
	    - Check When last client disconnects Lock workstation
	- Viewer, Options
	  - Colour, Colour level=Full
	  - Scaling, Scale to Window Size
	  - Misc
	    - Check Allow dynamic desktop resizing
	  - Load / Save, Defaults, Save
	- Notes
	  - Capabilities: Multi-platform support, allows viewing and control by multiple clients, free version has slower screen updates, other:
	    - Works with high-color programs like VideoStudio (not possible with NetMeeting), 
	    - The controlled machine can share applications using NetMeeting (not possible with #ote Desktop Connection)
	  - Multiple displays are supported by scrolling in direction of other display.  If host has multiple displays 
	    then scroll in direction of hosts other monitor does not scroll client.  Only scrolls in full screen
	  - F8 context menu - Control-Alt-Delete, Full Screen, Minimize, Etc
	  - Viewer does not  need to be installed, run VncViewer in bin
	  - If Windows Firewall is installed, Allow exception for c:/Program Files/RealVNC/VNC4/winvnc4.exe
	"

	return

	:vonage
	echot "\
	************************
	* Vonage Applicaitons
	************************
	"

	run "Vonage/setup/vonage-outlook-plugin-7.0.7.exe"
	run "Shareware/VDialer/vdialer_103.exe"

	echo "Updating icons..."
	$mergeDir "$pp/Vonage Contact Center" "$ao"

	echot "\
	- File, Options, Add-Ins, VDialer, Add-in Options...
	  - Username=XXX, Password=XXX, Lookup
	  - Uncheck Show dialer form when making a call
	"

	return

	:WindowsMobileReader
	echot "\
	- You MUST install Micrsoft reader to the default directory.  Installs to /Windows
	"

	run "Microsoft/Pocket PC/Reader V2.3/MSReaderPPCUSASetup.exe"

	echo "Updating icons..."
	PpcMoveLink "Microsoft Reader" "Applications/Reader.lnk"

	echot "\
	- Redevice
	"

	return

	:AmberPoint
	# WebService monitoring
	echot "\
	************************
	* AmberPoint
	************************
	"

	run "AmberPoint/AmberPointExpress(VS2005).exe"

	return

	:Infragistics
	# Intel has an unlimited license with this vendor.  Keys and installers at //fmssqlrnd001.amr.corp.intel.com/software/infragistics 
	echot "\
	************************************************
	* Infragistics
	************************************************
	"

	p=Infragistics/NetAdvantage/setup/

	run "$p/NetAdvantage_ASPNET_20082_CLR35_Product.exe"
	run "$p/NetAdvantage_WinForms_20082_CLR20_Product.exe"
	run "$p/NetAdvantage_NET_20082_CLR35_Help.exe"

	ask "Do you want to install Infragistics toolbox items?" y
	if $? == 1 then
	  echo Installing VisualStudio Toolbox...
	  start /wait /pgm "$P32/Infragistics/NetAdvantage 2006 Volume 2 CLR 2.0/Toolbox Utility/Infragistics.ToolboxUtility.exe" 6.2
	fi

	echo "Updating icons..."
	$mergeDir "$pp/Infragistics NetAdvantage 2006 Volume 2 CLR 2.0" "$pp/Development/Other"

	return

	:LogonStudio

	# LogonStudio requires fast user switching, which is not available in a domain.  
	if "$UserDnsDomain" == "" return 1

	if defined NewOs then
		run "StarDock/Setup/LogonStudioVista.exe"
	else
		run "StarDock/Setup/LogonStudio_public.exe"
	else

	# Delete LogonStudio - "C:/Program Files/WinCustomize/LogonStudio/logonstudio.exe" /RANDOM
	registry 32 delete "HKLM/SOFTWARE/Microsoft/Windows/CurrentVersion/Run/LogonStudio"

	SkinDir=$udata/Stardock/Boot Skins
	if IsDir "$SkinDir" then
		explorer "$SkinDir"
		pause
	fi

	return

	:StrokeIt
	# http://www.tcbmi.com/strokeit/
	echot "\
	************************
	* StrokeIt
	************************
	"

	run "Shareware/StrokeIt/setup/StrokeIt_0.9.7-Home-English.exe"

	echo "Updating icons..."
	$rm "$ud/StrokeIt.lnk"
	$mergeDir "$up/StrokeIt" "$pp/Operating System/Other"

	echo Updating registry...

	# Delete StrokeIt - C:/Users/jjbutare/AppData/Local/TCB Networks/StrokeIt/Bin/StrokeIt.exe
	registry 32 delete "HKCU/Software/Microsoft/Windows/CurrentVersion/Run/StrokeIt"

	echo Restoring the default profile...
	StrokeIt profile restore default

	return

	:Nero
	echot "\
	************************
	* Nero
	************************
	- Install Nero without the Ask Toolbar
	- Enter registered serial number
	- Setup Type=Custom
	- Uncheck Nero Home, InCD, Nero Mobile, Nero ShowTime
	- Photos, Video, Music, Preview: #ove All
	- Uncheck Configure Nero Scout on first usage (Nero Scout is a media indexer used by Nero Home)
	"

	# run "Ahead/Nero V7/Setup/Nero-7.5.1.1_eng.exe"
	run "Ahead/Nero V7/Setup/Nero-7.10.1.0_eng_update.exe"
	run "Ahead/Nero V7/Setup/Nero7_chm_eng.exe"

	# Documentation
	echo Copying documentation...
	s=$ExeDir/doc
	d=$P32/Nero/Nero 7
	CopyFile "$s/NeroBurningRom_Eng.chm" "$d/Core"
	CopyFile "$s/NeroRecode_Eng.chm" "$d/Nero Recode"

	echo "Updating icons..."
	$mv "$pd/Nero StartSmart.lnk" "$pp/Applications"
	$mv "$pd/Nero Home.lnk" "$pp/Applications"
	$mergeDir --rename "$pp/Nero 7 Ultra Edition" "$ao/Nero"

	echo Updating registry...
	registry import "$Install/Ahead/Nero V7/Setup/Nero.reg"

	# Delete NeroFilterCheck - C://Program Files//Common Files//Ahead//Lib//NeroCheck.exe
	registry 32 delete "HKLM/SOFTWARE/Microsoft/Windows/CurrentVersion/Run/NeroFilterCheck"

	# Nero BackItUp Scheduler Application - "C:/Program Files/Ahead/Nero BackItUp/NBJ.exe"
	registry 32 delete "HKCU/SOFTWARE/Microsoft/Windows/CurrentVersion/Run/NBJ"

	# BgMonitor_{79662E04-7C6C-4d9f-84C7-88D8A56B10AA} - "C:/Program Files/Common Files/Ahead/lib/NMBgMonitor.exe"
	registry 32 delete "HKCU/Software/Microsoft/Windows/CurrentVersion/Run/BgMonitor_{79662E04-7C6C-4d9f-84C7-88D8A56B10AA}"

	echo Updating services...
	service manual NmIndexingService


	echot "\
	- My Computer, Nero Scout, Options uncheck Enable Nero Scout
	- (InCd) MyComputer, DVD Burner, Properties, InCd, Options, More, Preferences
	  - General
	    - Check Hide tray icon
	    - Check Do not show 'Format complete' message
	    - Check Enable the advanced options
	  - Auto-Format
	    - On blank disc insertion Open format dialog
	- Recode, More, Options, General
	  - Check If minimize, minimize to tray
	  - Uncheck Offer to save detailed report after successful burn process  
	- ShowTime, Preferences
	  - General, Toolbar setting, Show All
	  - Disc playback
	    - Select Resume playback fromt the last scene
	    - Uncheck Prompt user before playback resume
	  - (unless causes playback error) Video, check Hardware Acceleration Enable
	- Nero Burning ROM
		- File, Options
			- Compilation
				- Uncheck Start with new compilation
				- Uncheck #ember last used volume label
			- Expert Features
				- Check Do not eject the disc after burn is complete
		- Click the folder icon to switch the File Browser window off
	- Notes
	  - InCD: When formatting use UDF 2.01
		- Burning ROM
			- Use format DVD-ROM (UDF)
			- When burning
				- If DVD+-RW discs contain data you will be prompted to erase
				- Check Use multiple recorders, multi-select records to use
			- Alcohol 52$: View, Options, Emulation, Uncheck Ignore Media Type 
				- Required for for DVD+-RW to write/erase properly
			- Recorder, Disc Info, media type and Book Type (reported media type) is displayed
				- If Alcohol 52$ is installed and Ignore Media Type is checked, media and book type for DVD+RW media
					will be reported as DVD-ROM instead of DVD+RW, and write/erase operations will fail
			- Benchmark: 9m21s to format and record 1761MB at 2.4x (3,324 KB/s)
	"

	return

	:ConnectedNetworkBackup
	echot "\
	**************************
	* Connected Network Backup
	**************************
	- Account number and encryption key in wallet
	- Use cnb to initiate backup or restore
	- Reference: http://Clientbackup.intel.com
	"

	RunExe "//RRSCNB100/tlm_install/ReInstall.exe"
	run "Intel/Connected Network Backup/File Exclusion Tool/Setup.Exe"

	echo Updating services...
	service manual ConnectedLauncher
	service manual CBRegCap

	echo "Updating icons..."
	$rm "$up/Startup/Connected TaskBar Icon.LNK"
	$rm "$up/Connected TLM.LNK"
	$makeShortcut cnb.btm "$pp/Operating System/Intel Backup.lnk"

	echot "\
	- Manually, Operating System/Intel Backup.lnk icon to C:/Program Files/Connected/COBackup.exe
	- Note: After running a backup, manually close the CNB system tray icon
	"

	return

	:DaemonTools
	# Note: Installs the dtscsi driver, which must be manuall #oved (service delete dtsci, del $WinDir/system32/drivers/dtscsi.sys)
	echot "\
	************************
	* Daemon Tools
	************************
	- Begin installation, reboot, uncheck DAEMON Tools Search Bar
	"

	run "Shareware/Daemon Tools/setup/daemon403-${architecture}.exe"

	echo "Updating icons..."
	$rm "$pd/DAEMON Tools.lnk"
	$mergeDir "$pp/DAEMON Tools" "$pp/Operating System/Other"

	echot "\
	- Virtual CD/DVD-ROM, number of devices..., 2 drives
	- Options, uncheck Secure Mode
	"
	pause

	MountVolToDev


	echot "\
	- Rename new drives iso1 and iso2
	- Note: Use iso to mount and unmount images
	"

	return

	:MaxiVista
	# Uninstall requires manually deletion of video drivers: service delate maxivista&maxivistb&maxivistc, del $WinDir/system32/drivers/maxi*.sys
	echot "\
	************************
	* MaxiVista
	************************
	- For an upgrade, uninstall your existing installation and reboot (very important!!!)
	- Two extended Displays
	- When setup finishes click OK to run MaxiVista (to create viewers)
	"

	# run "MaxiVista/MaxiVista V3.0.29.exe"
	run "MaxiVista/MaxiVista v4 Beta/Maxivista_Setup_PrimaryPC_${architecture}.exe"

	echo "Updating icons..."
	$rm "$up/Startup/MaxiVista MirrorPro Server All.lnk"
	$rm "$ud/MaxiVista MirrorPro Server.lnk"
	$mergeDir "$pp/MaxiVista MirrorPro Server" "$pp/Operating System/Other"
	$mergeDir "$up/MaxiVista MirrorPro Server" "$pp/Operating System/Other"

	$mergeDir "$up/MaxiVista Demo Server" "$pp/Operating System/Other"
	$rm "$ud/MaxiVista Demo Server All.lnk"

	$rm "$ud/MaxiVista MirrorPro Server All.lnk"
	dest=$pdoc/Data/Bin
	$mv "$ud/MaxiVistaViewerA.exe" "$dest"
	$mv "$ud/MaxiVistaViewerB.exe" "$dest"
	$mv "$ud/MaxiVistaViewerC.exe" "$dest"

	echo Updating registry...
	p=HKCU/Software/MaxiVista
	if $@RegExist[$p/A3] == 1 registry 32 "$p/A3/$UserName/lock_method" REG_DWORD 1
	if $@RegExist[$p/B3] == 1 registry 32 "$p/B3/$UserName/lock_method" REG_DWORD 1
	if $@RegExist[$p/C3] == 1 registry 32 "$p/C3/$UserName/lock_method" REG_DWORD 1

	echot "\
	- (for each viewer) Select appropriate display for viewer
	- Options..., Hotkeys, Toggle #ote control mode=F6 (A), F7 (B), F8 (C)
	"

	return

	:BaselineSecurityAnalyzer
	echot "\
	****************************
	* Baseline Security Analyzer
	****************************
	- Install on primary computer and check others over network
	"

	run "Microsoft/Baseline Security Analyzer/MBSASetup-EN.msi"

	echo "Updating icons..."
	$mv "$pp/Microsoft Baseline Security Analyzer.lnk" "pp/Operating System"

	return

	:UltraMon
	# http://www.realtimesoft.com/ultramon/download.asp
	echot "\
	************************
	* UltraMon
	************************
	- Check only Profiles and Shortcuts
	"

	# New version requires updating reg file
	version=3.1.0

	run "UltraMon/setup/UltraMon_$version$_en_${architecture}.msi"

	echo Stopping UltraMon...
	UltraMon.btm stop

	echo "Updating icons..."
	$mv "$pp/UltraMon.lnk" "$pp/Operating System"
	$rm "$pp/Startup/UltraMon.lnk"

	echo Registry settings...

	# Delete UltraMon - "C:/Program Files/UltraMon/UltraMon.exe" /auto
	registry delete "HKLM/SOFTWARE/Microsoft/Windows/CurrentVersion/Run/UltraMon"

	registry import "$install/UltraMon/setup/UltraMon.reg"

	r=HKCU/Software/Realtime Soft/UltraMon/$version
	registry 32 "$r/Wallpaper/Image Directory" REG_SZ $@PublicPictures[]

	# UltraMon.scr conflicts with UltraMon name, so rename the screen saver
	if exist "$WinDir/UltraMon.scr" then
		move /q "$WinDir/UltraMon.scr" "$WinDir/UltraMonSs.scr"
	fi

	# Create the destination profile directory
	$makeDir "$udata/UltraMon/profiles"

	# #ove the  existing profile directory  if it is not a link
	if $@IsLink["$_ApplicationData/Realtime Soft/UltraMon/$version/Profiles"] == 0 then
		$rmd.btm "$_ApplicationData/Realtime Soft/UltraMon/$version/Profiles"
		if $? != 0 then
			EchoErr Unable to delete the existing profile directory.
			return 1
		fi
	fi

	# Link the UltraMon Profile directory
	linkd "$_ApplicationData/Realtime Soft/UltraMon/$version/Profiles" "$udata/UltraMon/profiles" 

	return

	:AnyDVD
	# Installs drivers AnyDVD and ElbyCDIO
	echot "\
	************************
	* AnyDVD
	************************
	"

	run "SlySoft/AnyDVD/SetupAnyDVD7210.exe"

	echo Updating registry...
	TaskEnd /f AnyDvd >& nul:

	# License must be added to the x86 registry key
	registry 32 import "$install/SlySoft/AnyDVD/Key.AnyDVDHD.reg"

	# Delete AnyDVD - C:/Program Files/SlySoft/AnyDVD/AnyDVD.exe
	registry 32 delete "HKLM/SOFTWARE/Microsoft/Windows/CurrentVersion/Run/AnyDVD"

	echo "Updating icons..."
	$mergeDir "$pp/SlySoft" "$ao"
	$rm "$pd/AnyDVD.lnk"
	$rmd "$ud/AnyDVDHD"
	$rm "$ao/SlySoft/AnyDVD/AnyDVD History.lnk"
	$rm "$ao/SlySoft/AnyDVD/Register AnyDVD.lnk"
	$rm "$ao/SlySoft/AnyDVD/Uninstall.lnk"

	echot "\
	- Drives, Selection, uncheck virtual drives
	- Program Settings, Uncheck AutoStart
	"

	return


	:CloneDVD
	echot "\
	************************
	* CloneDVD
	************************
	"

	run "SlySoft/CloneDVD/SetupCloneDVD2930Slysoft.exe"
	run "SlySoft/CloneDVD Mobile/SetupCloneDVDmobile1901.exe"

	echo Updating registry...

	# License must be added to the x86 registry key
	registry 32 import "$install/SlySoft/CloneDVD/Key.CloneDVD.reg"
	registry 32 import "$install/SlySoft/CloneDVD Mobile/Key.CloneDVDmobile.reg"

	echo "Updating icons..."
	$mergeDir --rename "$pp/Elaborate Bytes" "$ao/SlySoft"
	$mergeDir "$pp/SlySoft" "$ao"
	$rm "$ao/SlySoft/CloneDVD2/CloneDVD2 Revision History.lnk"
	$rm "$ao/SlySoft/CloneDVD2/Register CloneDVD2.lnk"
	$rm "$ao/SlySoft/CloneDVD2/Uninstall.lnk"
	$rm "$pp/CloneDVDmobile.lnk"
	$rm "$pd/CloneDVD2.lnk"
	$rm "$pd/CloneDVDmobile.lnk"


	return

	:GoogleEarth
	echot "\
	************************
	* Google Earth
	************************
	"

	run "Google/Earth/GoogleEarthWin.exe"

	echo "Updating icons..."
	$mergeDir "$pp/Google Earth" "$ao"
	$mv "$pd/Google Earth.lnk" "$pp/Applications"

	echo - Note: Save files are in $CloudData/Google Earth

	return

	:GoogleDesktop
	# Update - "C:/Users/jjbutare/AppData/Local/Google/Update/GoogleUpdate.exe" /c
	echot "\
	************************
	* Google Desktop
	************************
	- Choose Desktop Features, uncheck all
	"

	run "Google/Desktop/GoogleDesktopSetup.exe"
	run "Google/Desktop/TweakGDS_Setup.exe"

	# Google Desktop Search - "C:/Program Files/Google/Google Desktop Search/GoogleDesktop.exe" /startup
	registry 32 delete "HKLM/SOFTWARE/Microsoft/Windows/CurrentVersion/Run/Google Desktop Search"

	echo "Updating icons..."
	$mv "$pd/Google Desktop.lnk" "$pp/Applications"
	$mergeDir "$pp/Google Desktop" "$ao"

	echot "\
	Adding additional index locations
	- (explorer) Computer, Add a Network Location
	- (TweakGDS) Indexing, quit GDS, Add..., restart GDS
	"
	os computer
	start /pgm "$P32/PodSync.com/TweakGDS/TweakGDS.exe"
	pause


	echot "\
	- Preferences
	  - Desktop Search, Number of Results Display 100 results per page in the browser
	  - Display
	    - Quick Find, Display 10 Quick Find results
			- Display Mode, None
	- Notes
	  - Auto-hide, close, or move dock to another monitor as needed
	  - Ctrl-Ctrl to open a search dialog on the active window
	"
	pause

	echo "Updating icons..."
	$mv "$ud/TweakGDS.lnk" "$pp/Operating System"

	return

	:FeedDemon
	echot "\
	************************
	* FeedDemon
	************************
	- Import an OPML file or URL, Documents/data/FeedDemon/*.opml
	"

	run "Intel/FeedDemon/FeedDemonIntel.exe"

	echo "Updating icons..."
	$mergeDir "$pp/FeedDemon" "$ao"

	echot "\
	- Options, System Tray
	  - Show FeedDemon in system tray=When minimized
	  - Check Minimize to system tray instead of closing
	  - When new items are received, show desktop alert=Never
	"

	return

	:ZoneTick
	# Reference: http://sdtoday.intel.com/Show.aspx?FromTab=home&AID=304 (iss 7710)
	echot "\
	************************
	* ZoneTick
	************************
	"

	run "WR Consulting/ZoneTick/anuko_world_clock_full_setup.exe"

	echo Restoring the default profile...
	ZoneTick.btm profile restore default

	echo "Updating icons..."
	$mergeDir "$pp/ZoneTick" "$ao"

	return

	:Audacity
	# http://audacity.sourceforge.net/
	echot "\
	************************
	* Audacity
	************************
	"

	run "Shareware/Audacity/audacity-win-unicode-1.3.12.exe"
	run "Shareware/Audacity/LADSPA_plugins-win-0.4.15.exe"

	echo "Updating icons..."
	$makeDir "$pp/Media/Other"
	$rm "$ud/Audacity 1.3 Beta (Unicode).lnk"
	$mv "$pp/Audacity 1.3 Beta (Unicode).lnk" "$pp/Media"


	echot "\
	- Edit, Preferences...
	  - Devices, Recording Device=nnn
	  - Libraries, MP3 Library Version, Locate..., Public/Documents/data/bin/lame_enc.dll
	"

	return

	:FileTransferManager
	# Reference: http://transfers.ds.microsoft.com/FTM/ or http://transfers.ds.microsoft.com/ftm/default.aspx?target=install
	echot "\
	************************
	* File Transer Manager
	************************
	"

	run "Microsoft/File Transfer Manager/FTMSetup.msi"

	echo "Updating icons..."
	$rm "$pp/File Transfer Manager.lnk"
	$rm "$ud/File Transfer Manager.lnk" 

	$makeShortcut "$P32/Microsoft File Transfer Manager/TransferMgr.exe" ^
		"$pp/Operating System/File Transfer Manager.lnk"


	echot "\
	- Options..., 
		- General, Files received will be placed in this folder=/Documents/data/download
		- Performance, Maximum Concurrent Transfer=4
	"

	return

	:InternetExplorer
	:ie
	# http://www.microsoft.com/windows/ie/default.mspx
	# http://www.microsoft.com/downloads/en/details.aspx?FamilyID=62E67358-DA9A-499D-AA19-EB93996CA8E0
	echot "\
	************************
	* InternetExplorer
	************************
	"

	run "Microsoft/Internet Explorer/setup/IE10-Windows$_WinVer$-${architecture}-en-us.exe"

	echo Update registry...

	# Number of simultaneous requests allowed to a single HTTP server for HTTP 1.0 and 1.1 protocols.  Defaults are 2 and 4.
	# Reference: http://support.microsoft.com/kb/282402
	registry 32 "HKCU/Software/Microsoft/Windows/CurrentVersion/Internet Settings/MaxConnectionsPer1_0Server" REG_DWORD 10
	registry 32 "HKCU/Software/Microsoft/Windows/CurrentVersion/Internet Settings/MaxConnectionsPerServer" REG_DWORD 10

	echo Updating favorites...
	$rm "$UserProfile/Favorites/Links/Customize Links.url"
	$rm "$UserProfile/Favorites/Links/Free Hotmail.url"
	$rm "$UserProfile/Favorites/Links/Windows Media.url"
	$rm "$UserProfile/Favorites/Links/Windows.url"

	echo Installing extensions...
	# XMarks
	# CoolIris

	echo "Updating icons..."
	if not defined server $rm "$up/Internet Explorer.lnk"
	$mv "$up/Internet Explorer.lnk" "$ao"
	$mv "$up/Internet Explorer (64-bit).lnk" "$ao"
	$mergeDir "$up/Accessories" "$pp/Applications"

	echot "\
	- Search (Hourglass), Search Providers, Google, Wikipedia Visual Search
	- Tools, Internet Options...
	  - (workgroup) Security, Local intranet, Sites,
	    uncheck Automatically detect intranet network, check rest
	  - Advanced
	    - (development)
	       - Uncheck Disable script debugging (both)
	       - Check Display a notification about every script error
	    - Security, check Allow active content to run in files on My Computer
	- Notes
	  - Press the CTRL key while clicking links, or use the middle mouse button. 
	  - Click any tab with the middle mouse button to close it. 
	  - Press ALT+ENTER from the address bar or search box to open the result in a new tab. 
	"
	InternetExplorer start
	pause

	return

	:Cooliris

	run "Microsoft/Internet Explorer/extension/cooliris-win-iefull-release-1.11.6.31225.en-US.msi"

	echo "Updating icons..."
	$mergeDir "$up/Cooliris" "$ao"
	$rm "$ud/Launch Cooliris.lnk"

	return
	
	:OracleDrivers
	# Reference - http://istg.intel.com/EPS/KTBR/KTBR_HR/dba/GENItools.htm
	echot "\
	************************
	* Oracle Database Drivers
	************************
	- TODO: test install to c:/Program Files/OraHome, write down config: OraHome, etc, check and doc OraHome location in subsequent installs, ensure only c:/Oracle, ensure ping test successful
	- Disable McAfee OnAccess scan
	- Install Runtime components (160MB)
	- Net Service configuration
	- Installer, install from
	  - Oracle/ODBC Drivers ora92054/Disk1/stage/products.jar
	- Usage (move to document)
	  - PL/SQL Developer
	    - Tools, Find Database Objects, Owner=SYSADM, Name=$<text>$ ($ is wildcard)  
	"

	run "Intel/dbConnector for Oracle V9.2.0.6/9201/install/win/setup.exe"
	run "Intel/dbConnector for Oracle V9.2.0.6/9206/install/setup.exe"
	run "Allround Automations/PL SQL Developer V6.0.5.931/Setup.exe"

	# Copy configuration files
	dir=c:/oracle/ora92/network/admin
	CopyFile "$setupFiles/tnsnames.ora" "$dir"
	CopyFile "$setupFiles/sqlnet.ora" "$dir"

	# Test
	echo Testing connection to production GENI server...
	C:/oracle/ora92/bin/TNSPING.EXE geni8
	echo If the tnsping fails with an error "No message file for product=NETWORK", re-run the initial setup.
	pause

	echo "Updating icons..."

	$makeDir "$pp/Development/Other/Oracle"
	$mergeDir "$pp/Oracle - OraHome92" "$pp/Development/Other/Oracle"
	$mergeDir "$pp/Oracle Installation Products" "$pp/Development/Other/Oracle"

	$mergeDir "$up/PLSQL Developer" "$pp/Development/Other"
	$mv "$ud/PLSQL Developer.lnk" "$pp/Development"

	RunProg odbcad32.exe


	echot "\
	- System DSN, Add..., 
	  - Oracle in OraHome92, Finish, Data Source Name=Geni, TNS Service Name=Geni8, User ID=sysuser, Test Connection
	"

	:Expression
	# http://www.microsoft.com/expression/products/StudioUltimate_Overview.aspx
	echot "\
	************************
	* Expression
	************************
	"

	p=Microsoft/Expression

	ask "Install Expression 4 (requires activation)?" n
	if $? == 1 then
		run "$p/setup/en_expression_studio_4_ultimate_x86_dvd_537032.iso"
		run "$p/update/Web 4 SP1.exe"
		run "$p/update/Blend 4 SP1.exe"
		run "$p/update/Encoder 4 SP1.exe"
	else
		run "$p/setup/en_expression_studio_3_x86_dvd_401336.iso"
		run "$p/update/en_expression_web_3_sp2.exe"
	fi

	echo Moving Web Sites directory...
	MergeDir /rename "$udoc/Web Sites" "$udoc/code/web/sites"
	$makeDir "$udoc/code/web/sites"
	$hide -s -h "$udoc/code/web/sites"

	echo "Updating icons..."
	ExpressionIcons
	SilverlightIcons

	echo Cleanup...
	$rmd ask "$udoc/Expression"

	echo Configure Expression Encoder...
	echot "\
	<PrimitiveObject Name="LastDirectory_Import">$udoc/media/convert</PrimitiveObject>
	<PrimitiveObject Name="LastDirectory_Job">$udoc/media/convert/jobs</PrimitiveObject>
	"
	expression encoder config
	pause

	return

	:Delphi
	# Updates - http://info.borland.com/devsupport/delphi/downloads/
	echot "\
	************************
	* Delphi
	************************
	"

	ask "Do you want to run install.exe?"
	if $? == 1 then

	  FindExe "Borland/Delphi V5.0/INSTALL.EXE"
	  if $_? != 0 return $_?

	  # Run exe from a share (error running from UNC)
	  UncConnect s: "$ExeDir"
	  s:/install.exe
	  pause

	fi

	run "Borland/Delphi V5.0 Enterprise Update Pack 1 Build 6.18/D5EntUpdate.exe"

	echo "Updating icons..."
	$mergeDir "$pp/(directory name)" "$ao"

	return

	:PowerShell
	# Reference http://www.microsoft.com/windowsserver2003/technologies/management/powershell/default.mspx
	echot "\
	************************
	* PowerShell
	************************
	"

	if $_WinVer == 5.1 then
		run "Microsoft/scripting/Power Shell/setup/PowerShell 1.0 for Windows $_WinVer ${architecture}.exe"
	else
		run "Microsoft/scripting/Power Shell/setup/PowerShell 1.0 for Windows $_WinVer ${architecture}.msu"
	fi
	run "Microsoft/Scripting/Power Shell/setup/PowerGUI.1.9.0.902.msi"

	echo "Updating icons..."
	$mergeDir --rename "$pp/Windows PowerShell 1.0" "$pp/Operating System/Other/PowerShell"
	$mergeDir --rename "$pp/PowerGUI" "$pp/Operating System/Other"

	return

	:DynamicDnsCheck

	# Dynamic DNS  - if the host has a configuration file
	if exist "$install/Shareware/DNSer/config/$HostName.ini" then
	  DynamicDns
	fi

	return $_?

	:DynamicDns
	# Reference - http://members.dyndns.org
	echot "\
	************************
	* Dynamic DNS - DNSer
	************************
	"

	FindExe "Shareware/DNSer/Setup V2.0/DNSerSvc.exe"
	if $_? != 0 return $_?

	# Copy / update the config file
	ConfigDir=$install/Shareware/DNSer/config

	# Use the template specific for this host
	if exist "$ConfigDir/$ComputerName.ini" then
	  copy "$ConfigDir/$ComputerName.ini" "$WinDir/DNSerSvc.ini"

	# Use a default tempalte which registers the IP of the LAN adapter with the Dynamic DNS service
	else
	  copy "$ConfigDir/template.ini" "$WinDir/DNSerSvc.ini"
	  echo $@IniWrite[$WinDir/DNSerSvc.ini,Source,Adapter,$@IpAdapterDescription[LAN]]
	  echo $@IniWrite[$WinDir/DNSerSvc.ini,Srv1,URL,http://members.dyndns.org/nic/update?hostname=$ComputerName.podzone.net&myip=$s&system=dyndns&wildcard=NOCHG]
	fi

	# Copy the service
	copy "$install/Shareware/DNSer/setup/DNSerSvc.exe" "$WinDir"

	# Install and start the service
	"$WinDir/DNSerSvc" /install
	service start DNSerSvc 

	return

	:SilverRun
	# //vmsddedm800/Distribution SR RDM 2.8.4.4/SR-RDM2844-IntelCorporation.exe
	# //FMEA1PUB006/SilverRun/documentarchive/installation/SilverRun2.8.2/SR-RDM282.exe
	echot "\
	*************************
	* SilverRun Data Modeling
	*************************
	- License Manager, check TCP/IP
	"

	run "SilverRun/SR-RDM2844-IntelCorporation.exe"

	echo "Updating icons..."
	$mergeDir "$pp/(directory name)" "$ao"

	echot "\Edit "C:/Program Files/SILVERRUN-RDM 2.8.2/LSHOST"

	echot "\
	- Validate that LSHOST contains one entry: FMSEDM801
	"

	return

	:Harmony#ote
	# http://www.logitech.com/en-us/440/6441?section=downloads&bit=&osid=14
	echot "\
	************************
	* Harmony #ote
	************************
	- Uncheck Install Logitech Desktop Messenger
	- Plug in the harmony #ote
	"

	run "Logitech/Harmony #ote/LogitechHarmony#ote7.7.0-WIN-x86.exe"

	echo "Updating icons..."
	$rm "$pp/Startup/Logitech Harmony #ote V7.lnk"
	$rm "$pd/Logitech Harmony #ote Software 7.lnk"
	$mergeDir "$pp/Logitech" "$ao"

	return

	:Python
	# http://www.python.org/download/, http://portablepython.com/
	echot "\
	************************
	* Python
	************************
	echo - Destination Directory=<paste>
	"
	# why need window program or just run from CygWin?
	# ez_setup.py # Python install easy_install
	# Pygmentize: easy_install setup/Pygments-1.6-py2.7.egg

	echo $@ClipW[$P32/Python27] >& nul:
	run "Shareware/Python/python-2.7-x86.msi"

	echo $@ClipW[$programs64/Python27] >& nul:
	run "Shareware/Python/python-2.7-x64.msi"

	echo "Updating icons..."
	$mergeDir "$pp/Python 2.7" "$pp/Development/Other"

	return

	:Perl
	# http://www.cpan.org/src/5.0/
	echot "\
	************************
	* Perl
	************************
	"

	run "Shareware/perl/ActivePerl-5.8.8.817-MSwin-${architecture}-257965.msi"

	echo "Updating icons..."
	$mergeDir "$pp/ActivePerl 5.8.8 Build 817" "$pp/Development/Other"

	return

	:MicrosoftReader
	echot "\
	************************
	* Microsoft Reader
	************************
	"

	run "Microsoft/Reader/MSReaderSetupUSA.exe"

	echo "Updating icons..."
	$rm "$pd/Microsoft Reader.lnk"
	$mv "$pp/Microsoft Reader.lnk" "$pp/Applications"

	return

	:MagicIso
	# http://www.magiciso.com/download.htm
	echot "\
	************************
	* MagicIso
	************************
	- MagicISO creates ISO images
	"

	run "MagicDisc/Setup_MagicISO v5.5.281.exe"

	registry import "$install/MagicDisc/MagicISO Intel License.reg"

	echo "Updating icons..."
	$rm "$ud/MagicISO.lnk"
	$mergeDir "$up/MagicISO" "$pp/Operating System/Other"
	$mergeDir "$pp/MagicISO" "$pp/Operating System/Other"
	CopyFile "$pp/Operating System/Other/MagicISO/MagicISO.lnk" "$pp/Operating System"

	return

	:MagicDisc
	echot "\
	************************
	* MagicDisc
	************************
	- MagicDisc mounts ISO images
	"

	run "Shareware/MagicDisc/setup_magicdisc74.exe"

	echo "Updating icons..."
	$rm "$ud/MagicDisc.lnk"
	$rm "$up/Startup/MagicDisc.lnk"
	$mergeDir "$up/MagicDisc" "$pp/Operating System/Other"
	CopyFile "$pp/Operating System/Other/MagicDisc/MagicDisc.lnk" "$pp/Operating System"

	return

	:SpeedFan
	# download http://www.almico.com/sfdownload.php
	# - giveio driver, c:/windows/system32/giveio.sys	
	# - speedfanSpeedFan Device Driver, Windows (R) 2000 DDK provider, c:/windows/system32/speedfan.sys	
	echot "\
	************************
	* SpeedFan
	************************
	"

	run "Shareware/SpeedFan/installspeedfan447.exe"

	echo "Updating icons..."
	$mv "$ud/SpeedFan.lnk" "$pp/Operating System"
	$mergeDir "$up/SpeedFan" "$pp/Operating System/Other"
	$mergeDir "$pp/SpeedFan" "$pp/Operating System/Other"

	echot "\
	- Readings, Configure, Options, check start minimized
	"
	app SpeedFan
	pause

	return

	:IsapiRewrite
	echot "\
	************************
	* ISAPI Rewrite
	************************
	- (Display pre-installation instructions)
	"

	run "Shareware/ISAPI Rewrite/isapi_rwl_${architecture}_0065.msi"

	echo "Updating icons..."
	$mergeDir "$up/Helicon" "$pp/Development/Other"

	return

	:Trillian
	# http://www.trillianastra.com/
	# Download: http://www.ceruleanstudios.com/sneakpreview/trillian-v4.0a-current.exe, beta, beta
	# Build 75: http://blog.ceruleanstudios.com/?p=315
	echot "\
	************************
	* Trillian
	************************
	"

	run "Trillian/trillian-v4.0a-current.exe"

	echo "Updating icons..."
	dest=$pp/Applications
	$mv "$up/startup/Trillian.lnk" "$dest"
	$mv "$ud/Trillian.lnk" "$dest"
	$mv "$up/Trillian.lnk" "$dest"

	if not defined NewOs os DisableMsnMessenger

	trillian profile restore default


	echot "\
	- Preferences
	  - Message Windows
	    - Conveying Activity, uncheck Flash the window
	    - When a new message window is created..., Select Hide the window and notify me
	   - Notifications, Notification Windows, Notify me when, Check New messages arrive in a private session
	  - Plugins, check AIM, ICQ, MSN
	   - Advanced Preferences, Automation
	      - Uncheck Hotkey: Ctrl-Shift-A (conflict with VisualStudio)
	- Notes
	  - Many settings are stored on the server
	  - Secure IM: Trillian can secure (encrypt) IM traffice using ICQ or AIM.  To initiate
	    a secure connection the contact must be online and in the contact list. 
	"

	return

	:WindowsDesktopSearch
	echot "\
	************************
	* Windows Desktop Search
	************************
	"

	if $@IsXp[] == 0 return

	run "Microsoft/Windows Desktop Search/WindowsDesktopSearch-KB917013-XP-${architecture}-enu.exe"

	echo "Updating icons..."
	$mv "$pp/Windows Desktop Search.lnk" "$pp/Applications"

	return

	:RegCleaner
	echot "\
	************************
	* Registry Cleaner
	************************
	"

	run "Shareware/RegCleaner/RegCleaner.exe"

	echo "Updating icons..."
	$rm "$pd/TweakNow RegCleaner Std.lnk"
	$mergeDir "$pp/TweakNow RegCleaner Std" "$pp/Operating System/Other"

	return

	:ManageEngine
	# Reference: http://manageengine.adventnet.com/products/applications_manager/
	echot "\
	************************
	* ManageEngine
	************************
	"

	run "AdventNet/ManageEngine_ApplicationsManager.exe"

	return

	:Eclipse
	# Download Eclipse for Java EE Developers: http://www.eclipse.org/downloads
	echot "\
	************************************
	* Eclipse - Java Develop Environment
	************************************
	"

	# Select version of Eclipse to install, or if no installation files found, select and Eclipse to configure
	FindExe Java/Eclipse/setup/*.zip
	if $_? == 0 then

		EclipseVersion=$@word["-",2,$@FileName[$exe]]
		EclipseDir=$programs$/Eclipse/$EclipseVersion$
		
		installDir=$EclipseDir
		RunExe "$exe$"
		
	else
		pause Press any key to select the installed version of Eclipse to configure...
		eclipse.btm select init
		if $? != 0 return $?
	fi

	ask "Do you want to the default JRE for Eclipse $EclipseVersion ?" y
	if $? == 1 eclipse.btm $EclipseVersion$ SetJre

	CodeDir=$code/test/eclipse$EclipseVersion$

	echo Creating directories...
	$makeDir "$codeDir$"

	echo Moving data folder...
	$makeLink --merge --hide "$udata/.eclipse" "$UserHome/.eclipse"

	echot "\
	- Workspace=<paste>
	- (Workspace setup) see Eclipse Notes/Workspace/Setup
	- (Project setup) see Eclipse Notes/Project/Setup
	"
	echo $@ClipW[$codeDir] >& nul:
	eclipse.btm $EclipseVersion$
	pause

	ask "Do you want to install default plugins?" y
	if $? == 1 EclipsePlugIns

	echo - Configure workspace or restore existing workspace configuration from data/profile/Eclipse to 
	echo   $codeDir
	echot "\
	- Window, Preferences, Java, Installed JREs, Search..., c:/Program Files/Java and c:/Program Files (x86)/Java.
	- Check the default JRE.
	"
	eclipse.btm $EclipseVersion$ start
	pause

	return

	:EclipseInit

	if "$EclipseDir" == "" .or. "$EclipseVersion" == "" then
		eclipse.btm select init
		if $? != 0 return $?
	fi

	return 0

	:EclipsePlugIns

	for plugin in (OpenHomePage JBossTools TfsEclipsePlugIn) (
		ask "Install the $plugin plugin?"
		if $? == 1 then
			$plugin
			if $_? != 0 return $_?
		fi
	)

	return

	:EclipsePlugIn [PlugInArg]

	EclipseInit
	if $_? != 0 return $_?

	# Arguments
	PlugIn=$@UnQuote[$PlugInArg]
	if "$PlugIn" == "" .and. $# != 0 then
		PlugIn=$@UnQuote[$1]
		shift
	fi

	if "$PlugIn" == "" then
		echo An Eclipse plugin was not specified.
		return 1
	fi

	# Use the default plugin folder if we can't find the plugin (when not specied from the command line), and a path was not already specified for it 
	if not IsFile "$PlugIn" .and. "$@path[$PlugIn]" == "" then
		PlugIn=Java/Eclipse/plugins/$PlugIn
	fi

	if not IsFile "$PlugIn" then
		FindExe "$PlugIn"	
		if $_? != 0 return 1
	fi

	echos Installing the $@FileName[$PlugIn] plugin...
	copy /q $@quote[$exe] "$EclipseDir$/plugins"
	echo done.

	return

	:OpenHomePage
	echot "\
	************************
	* OpenHomePage Plugin
	************************
	"

	EclipsePlugin OpenHomePage_1.0.0.jar
	if $_? != 0 return $_?

	if not IsFile $code/home.htm .and. IsFile "$udata/replicate/default.htm" then
		ln --symbolic "$udata/replicate/default.htm" $code/home.htm
		ln --symbolic "$udata/replicate/base.css" $code/base.css 
		$hide +h $code/home.htm $code/base.css
	fi

	return

	# JadClipse plugin - http://jadclipse.sourceforge.net/wiki/index.php/Main_Page
	:JadClipsePlugin
	echot "\
	************************
	* JadClipse Plugin
	************************
	"

	EclipsePlugIn `"jadclipse_3.$@if[ $EclipseVersion gt 3.1 ,3,1].0.jar"`
	if $_? != 0 return $_?

	echot "\
	- Windows, Preferences
	  - Java, JadClipse
	    - Directory for temporary files=c:/temp
	    - Debug
	      - Check Output original line numbers as comments
	      - Check Align code for debugging
	    - Formatting
	      - Check Output fields before methods
	      - Check Don't insert a newline before opening brace
	  - (optional) File Associations, *.class, JadClipse Class File Viewer, Default
	"
	eclipse $EclipseVersion$ clean

	return

	# Microsoft Visual Studio Team Foundation Server Plugin for Eclipse
	# - Download: http://www.microsoft.com/downloads/details.aspx?displaylang=en&FamilyID=af1f5168-c0f7-47c6-be7a-2a83a6c02e57
	:TfsEclipsePlugin
	echot "\
	************************
	* TFS Eclipse Plugin
	************************
	"

	FindExe "Microsoft/Visual Studio/setup/PluginForEclipse/TFSEclipsePlugin-UpdateSiteArchive-VL-10.0.0.zip"
	if $_? != 0 return $_?

	echo $@clipw[$exe] >& nul:
	echot "\
	- Help, Install New Software...
	  - Add..., Archive..., <paste>
		- Work with: --Only Local Sites--, check Visual Studio Team Explorer Everywhere 2010
		- Uncheck Contact all update sites during install to find required software
	- Open Team Fondation Server Exploring perspective, Add Existing Team Project
	  - Server=http://source.intel.com:8080,http://ws08:8080/tfs
	  - Team Projects=HCMS
	- Project, Team, Share Project..., 
	"
	eclipse $EclipseVersion$ start

	return

	# JBoss Tools plugin - http://www.jboss.org/tools/download/ 
	:JbossTools
	echot "\
	************************
	* JBoss Tools Plugin
	************************
	"

	EclipseInit
	if $_? != 0 return $_?

	ToolsDir=Java/JBoss/tools
	ToolsVersion=
	ToolsSetup=`$ToolsDir/$ToolsVersion/image`

	switch $@left[3,$EclipseVersion]
	case 3.6
		ToolsVersion=3.2.0
	case 3.5
		ToolsVersion=3.1.0.M4
	case 3.4
		ToolsVersion=3.0.1
	case 3.3
		ToolsVersion=2.1.2.GA
	endswitch

	if "$ToolsVersion" == "" then
		EchoErr JBoss Tools setup for Eclipse $EclipseVersion is not present.
		return 1
	fi

	installDir=$P/JBoss Tools/$ToolsVersion
	run "$ToolsSetup"

	eclipse.btm $EclipseVersion$ LinkPlugin JBossTools "$installDir"

	echot "\
	- Refer to JBoss notes for configuration, or copy existing configuration from below or Saba/Intel/eclipse
	  - <workspace>/.metadata/.plugins/org.eclipse.wst.server.core/servers.xml
	  - <workspace>/.metadata/.plugins/org.eclipse.core.runtime/.settings/org.eclipse.wst.server.core.prefs
	  - <workspace>/<project>/.packages
	"
	eclipse $EclipseVersion$ clean
	pause

	return

	:EvilLyrics
	echot "\
	************************
	* Evil Lyrics
	************************
	"

	run "Shareware/EvilLyrics/evillyrics.exe"

	echo "Updating icons..."
	$rm "$ud/EvilLyrics.lnk"
	$mergeDir "$up/EvilLyrics" "$ao"
	$mergeDir "$pp/EvilLyrics" "$ao"

	return

	:.AndroidDevCore
	echot "\
	************************
	* Android Development
	************************
	"

	$makeDir "$pp/Development/Android/Other"

	inst android

	return

	:android

	# Install the Android SDK to LocalAppData (install diectory cannot contain spaces or the Android virtual devices do not work)
	installDir=$LocalAppData/Google/android-sdk-windows
	run "Google/Android/sdk/android-sdk_r12-windows.zip"

	echo Moving data folder...
	$makeLink --merge --hide "$udata/.android" hide "$UserHome/.android"
	$makeLink --merge --hide "$udata/.android" hide "$UserSysHome/.android"

	# Update the Android SDK
	echot "\
	- Virtual devices, New..., Name=test, Target=Android 2.3.3 - API Level 10, Size=20
	- Available packages, Android Repository, check an appropriate tools, documentation, platform, and samples, such as:
	  - Android SDK Platform-tools, revision 6
	  - Documentation for Android SDK API13, revision 1
	  - SDK Platform Android 2.3.3, API 10, revision 1
	  - Samples for SDK API 10, revision 1
	"
	android sdk manager
	pause

	# Install Eclipse plugins
	echo $@ClipW[https://dl-ssl.google.com/android/eclipse] >& nul:
	echot "\
	- Help, Install New Software
	  - Add..., Name=Android Plugin, Location=<paste>
	  - check Developer Tools, close Eclipses
	"
	sudo /standard eclipse start
	pause

	# Install Eclipse plugins
	android init
	echo $@ClipW[$SdkDir] >& nul:
	echot "\
	- Window, Preferences, Android
	  - SDK Location=<paste>, Apply
	"
	sudo /standard eclipse start
	pause

	# Restart AHK for the Android plugin to be visible when AHK starts Eclipse
	sudo /standard AutoHotKey.btm restart

	return

	:WebPlatformInstaller
	# download - http://www.microsoft.com/web/downloads/platform.aspx
	echot "\
	************************
	* Web Platform Installer
	************************
	"

	run "Microsoft/development/other/wpilauncher.exe"

	echo "Updating icons..."
	$mv "$pp/Microsoft Web Platform Installer.lnk" "$pp/Development/.NET/Web Platform Installer.lnk"
	$mergeDir "$pp/IIS 7.0 Extensions" "$serverPrograms/Other"

	return

	:ScreenSavers
	echot "\
	************************
	* Screen Savers
	************************
	"

	if $@IsWindowsClient[] == 0 return

	FindExe "Shareware/Really Slick Screensavers V1.0"
	if $_? == 0 copy /q "$exe/*.scr" "$WinDir/System32"

	return

	:EasyBCD
	# - Beta: http://neosmart.net/forums/forumdisplay.php?f=7
	echot "\
	************************************************
	* EasyBCD - Boot Loader Configuration
	************************************************
	"

	run "NeoSmart Technologies/EasyBCD 2.0.1.exe"

	echo "Updating icons..."
	$rm "$pd/EasyBCD*"
	$mergeDir "$pp/NeoSmart Technologies" "$pp/Operating System/Other"

	return

	:N2O
	echot "\
	************************
	* N2O
	************************
	"

	# N2O Group
	net LocalGroup n2o /add /comment:"n2o Users"
	net LocalGroup n2o jjbutare cstegman lkitterman /add

	net share "n2o"="$pdoc/group/n2o" $netShareOptions /#ark:"n2o group files."
	explorer.btm "$pdoc/group"
	echo - n2o group full control
	pause

	echo - Refer to IisMagic instructions to setup WebDAV n2o share on magic

	return

	:Synergy
	# Keyboard Mouse #ote control
	# http://synergy2.sourceforge.net/
	echot "\
	************************
	* Synergy
	************************
	"

	run "Shareware/Synergy/SynergyInstaller-1.3.1.exe"

	echo "Updating icons..."
	$rm "$ud/Synergy.lnk"
	$mergeDir "$pp/Synergy" "$pp/Operating System/Other"
	$mergeDir "$up/Synergy" "$pp/Operating System/Other"


	echot "\
	- Server (shring keyboard and mouse)
	"

	return

	:ObjectDock
	echot "\
	************************
	* Object Dock
	************************
	"

	run "StarDock/ObjectDock/setup/objectdockplus_190.exe"

	ObjectDock RestoreLicense

	# Start ObjectDock to create the folders and registry keys needed below
	ObjectDock start
	pause

	# Move the ObjectDock folder in the user documents directory
	echos Moving ObjectDock user directory...

	dest=$udata/StarDock/ObjectDock/library

	r=HKCU/Software/Stardock/ObjectDock
	registry 32 $r/ImageLibraryLocation REG_SZ $dest

	$mergeDir --rename "$udoc/Stardock/ObjectDock Library" "$dest"
	$rmd "$udoc/Stardock"

	echo done.

	echo Restoring the default profile...
	ObjectDock profile restore default

	echo "Updating icons..."
	$rm "$ud/ObjectDock.lnk"
	$rm "$up/Startup/Stardock ObjectDock.lnk"
	$mergeDir "$up/StarDock" "$pp/Operating System/Other"
	$mergeDir "$pp/StarDock" "$pp/Operating System/Other"


	echot "\
	- If video performance (slow window painting) restart ObjectDock 
	"

	return

	:EpsonV100
	# drivers http://www.epson.com/cgi-bin/Store/support/supDetail.jsp?BV_UseBVCookie=yes&oid=72343&infoType=Overview
	echot "\
	************************
	* Epson V100 Scanner
	************************
	"

	run "Epson/Perfection V100 Scanner/driver/v3.24A/Setup.exe"
	run "Epson/Perfection V100 Scanner/Guide/setup.exe"

	echo "Updating icons..."

	base=$ao/Perfection V100
	$makeDir "$base"

	$mv "$pd/EPSON Scan.lnk" "$base"
	$mv "$pd/Epson PhotoCenter.url" "$base"
	$mv "$pd/Perfection V100P User's Guide.lnk" "$base"

	$mergeDir --rename "$pp/EPSON Creativity Suite" "$base/Creativity Suite"
	$mergeDir --rename "$pp/EPSON Scan" "$base/Scan"
	$mergeDir --rename "$pp/Epson/Perfection V100P User's Guide" "$base/doc"

	$rmd "$pp/Epson"
	 
	# Scanner properties
	echot "\
	- EPSON Perfection V10/100, Properties, Events
	  - Start Button, Start this program = EPSON Scan
	"
	os.btm scanner

	return

	:ViaEnvy24
	echot "\
	************************
	* Via Envy Audio Driver
	************************
	"

	run "Via/Envy24/Setup V5.20A/Setup.exe"

	echo "Updating icons..."
	$rm "$pp/Envy24HF ADeck Control Panel.lnk"


	echot "\
	- S/PDIF and speaker configuration
	"

	return

	:SysInternals

	echo Restoring the default profile...
	SysInternals profile restore default

	echo Registering ShellRunAs...
	start ShellRunAs /reg

	# add if not intel
	echo "Updating firewall..."
	firewall rule add "PsExec" `dir=in action=allow protocol=TCP localport=RPC #oteIP=LocalSubnet profile=domain,private program="$WinDir/system32/services.exe" service=any`

	return

	:AlbumCoverArtDownloader
	# http://www.unrealvoodoo.org/hiteck/projects/albumart/
	echot "\
	*****************************
	* Album Cover Art Downloader
	*****************************
	"

	run "Shareware/Album Cover Art Downloader/albumart-1.6.6-setup.exe"

	echo "Updating icons..."
	$makeDir "$pp/Media/Other"
	$mergeDir "$up/Album Cover Art Downloader" "$pp/Media/Other"


	echot "\
	- Settings, Configure Album Cover Art Downloader...
	  - Sources, for each source check Enable 
	  - Targets
	    - Freedesktop.org and Generic, Uncheck Enable
	    - MP3 files and Windows Media Player, check Enable
	- View, uncheck Hide albums with cover images
	- View, View mode, Click View the music collection sorted into folders.
	"

	return

	:LogMeIn
	# download - 
	echot "\
	************************
	* LogMeIn
	************************
	- On the LogMeIn web site delete previous computer account if it exists
	- Custom, Description=<computer name>
	"

	run "LogMeIn/LogMeIn.msi"

	echo "Updating icons..."
	$mv "$pp/LogMeIn.lnk" "$pp/Operating System"

	echo - (Computer Management) Create a local account for each secondary user
	os ComputerManagement
	pause

	echot "\
	- (for each secondar user) Users, Secondary Users, Add New Secondary User
	  - Secondary User's email address=NNN
	  - Computer Access Permision, Groups/Computers, check the computer name
	"
	http://LogMeIn.com
	pause
		
	echot "\
	- Home, Preference
	  - #ote Control, Default answer for confirmation message=No
	  - (for each secondary user that is not in the administrators group) Security Settings, Access Control, Add
	    - User name=<user name>, Add
	    - Check #ote Control R and W
	"
	https://LocalHost:2002/main.html

	return

	:Areca
	echot "\
	************************
	* Areca Backup
	************************
	"

	run "Shareware/Areca/areca-5.2.1-win-setup.exe"

	echo "Updating icons..."
	$mv "$pd/Areca.lnk" "$pp/Operating System"
	$mv "$ud/Areca.lnk" "$pp/Operating System"
	$mergeDir "$pp/Areca" "$pp/Operating System/Other"
	$mergeDir "$up/Areca" "$pp/Operating System/Other"


	echot "\
	- Notes
		- When creating a backup Target
			- Check Compression Zip 64
			- Check Track directories
			- Check Store permissions
		- To schedule a backup select Create backup shortcut
		- Encryption does not work
	"

	return

	:Silverlight
	:SilverlightPlayer
	:SilverlightRuntime
	# http://www.microsoft.com/silverlight/resources/install.aspx
	echot "\
	************************
	* Silverlight Player
	************************
	"

	run "Microsoft/.NET/Silverlight/setup/Silverlight v5.1.10411.exe"

	echo Testing...
	InternetExplorer.btm 32 http://www.microsoft.com/silverlight/default_ns.aspx

	echo "Updating icons..."
	SilverlightIcons

	return


	:IntelRapidStorage
	:IntelMatrix
	:rst
	# Download: http://downloadcenter.intel.com/Product_Filter.aspx?ProductID=2101
	# Installs
	# - System Run : IAStorIcon - C:/Program Files (x86)/Intel/Intel(R) Rapid Storage Technology/IAStorIcon.exe
	# - Service: IAStorDataMgrSvc - Intel(R) Rapid Storage Technology - "C:/Program Files (x86)/Intel/Intel(R) Rapid Storage Technology/IAStorDataMgrSvc.exe"
	#    Provides storage event notification and manages communication between the storage driver and user space applications 
	# - Driver: iaStor - Intel RAID Controller -c:/windows/system32/drivers/iastor.sys - Intel Rapid Storage Technology driver - x64
	# - Driver: iaStorV	- c:/windows/system32/drivers/iastorv.sys - Intel Matrix Storage Manager driver - x64
	echot "\
	************************************************
	* Intel Rapid Storage RAID Controller
	************************************************
	- check Install Intel Control Center
	"

	run "Intel/Rapid Storage/setup/RST v12.5.0.1066.exe"

	echo "Updating icons..."
	$mergeDir "$pp/Intel" "$pp/Operating System/Other"

	echot "\
	- Intel Matrix Storage Console, right click on volume, Enable Volume Write-Back Cache
	"

	return

	:IntelProNetworkAdapter
	:ProSet
	# http://downloadcenter.intel.com/SearchResult.aspx?lang=eng&keyword=$22PRO$22Network$22Connections$22LAN$22Driver#
	# http://ark.intel.com/products/52963/Intel-82579V-Gigabit-Ethernet-PHY?wapkw=Intel$2082579V
	# Installs:
	# - Service: Intel(R) PROMonitoring Service - C:/Windows/system32/IProsetMonitor.exe
	#   The Intel(R) PROMonitoring Service actively monitors changes to the system and updates affected network devices to keep them running in optimal condition.  Stopping this service may negatively affect the performance of the network devices on the system.
	# - Path: C:/Program Files/Intel/WiFi/bin/; C:/Program Files/Common Files/Intel/WirelessCommon/
	echot "\
	*******************************
	* Intel PRO Network Adapter
	*******************************
	- (optional) Uncheck Advanced Networking Services 
	"

	run "Intel/PRO Network Adapter/setup/PROWin$@WindowsVersion[]_$@OsBits[]_v17.4.exe"

	ProSetFinal
	return

	:ProSetFinal

	echot "\
	- LAN, Properties, Configure...
	  - (optional) Advanced, Locally Administered Address=<MAC address from HostInfo>
	"
	network connections
	pause

	return

	:IntelSsdToolbox
	# download - http://downloadcenter.intel.com/SearchResult.aspx?lang=eng&keyword=$22SSD+510$22
	echot "\
	************************
	* Intel SSD Toolbox
	************************
	"

	run "Intel/ssd/toolbox/setup/Intel SSD Toolbox - v3.1.2.exe"

	echo "Updating icons..."
	$rm "$pd/Intel SSD Toolbox.lnk"
	$rm "$ud/Intel SSD Toolbox.lnk"
	$mergeDir "$pp/Intel" "$pp/Operating System/Other"
	$mergeDir "$up/Intel" "$pp/Operating System/Other"

	echot "\
	- Intel SSD Optimizer, Schedule, Add
	- Fix other areas with an exclamation point
	"
	intel SsdToolbox
	pause

	# Common SSD setup
	ssd 

	return

	:IntelMotherboardUtilities

	ask "Do you want to install the Intel Desktop Utilities?" n
	if $? == 1 IntelDesktopUtilities

	ask "Do you want to install the Intel Ext#e Tuning Utility?" n
	if $? == 1 IntelExt#eTuningUtility

	ask "Do you want to install the Intel Integrator Assistant?" n
	if $? == 1 IntelIntegratorAssistant

	return

	:IntelDesktopUtilities
	# Monitor hardware devices (temperature and fan speed)
	# http://www.intel.com/design/motherbd/software/idu/index.htm
	# http://downloadcenter.intel.com/SearchResult.aspx?keyword=$22$22intel+desktop+utilities$22$22
	# Installs 
	# - Driver: smbusp - Intel(R) SMBus 2.0 Driver - c:/windows/system32/drivers/intelsmb.sys - System Management Bus 2.0 (SMBus) Driver
	# - System Run: ipTray.exe - "C:/Program Files (x86)/Intel/Intel Desktop Utilities/ipTray.exe" - Tray application for Intel(R) Desktop Utilities
	# - Service: Intel(R) Desktop Boards FSC Application Service - C:/Program Files (x86)/Intel/FSC/FSCAppServ.exe
	#    Supports the instrumentation of the Sensors and Fan Speed Controllers utilized on Intel® Desktop Boards.
	# - Service : IduService - Intel(R) Desktop Utilities Service - "C:/Program Files (x86)/Intel/Intel Desktop Utilities/iduServ.exe"
	#   Manages IDU component communication and alerts
	# -  smbusp
	echot "\
	*******************************
	* Intel Desktop Utilities
	*******************************
	"

	run "Intel/Motherboard/utility/Desktop Utilities/setup v3.2.3.052/Setup.exe"

	echo "Updating icons..."
	MergeDir /e "$pp/Intel" "$pp/Operating System/Other"
	MergeDir /e "$up/Intel" "$pp/Operating System/Other"
	$rm "$pd/Intel(R) Desktop Utilities.lnk"

	echo Updating registry...

	# Delete ipTray.exe - "C:/Program Files (x86)/Intel/Intel Desktop Utilities/ipTray.exe"
	registry 32 delete "HKLM/SOFTWARE/Microsoft/Windows/CurrentVersion/Run/ipTray.exe"

	echot "\
	- Options
	  - Active Alterting Options, uncheck Blink tray icon and Pop up message
	  - Sensor Threshold
	    - Rename hard drive to SSD and RAID Array and Upper to 50
	"
	intel DesktopUtilities
	pause

	echo Updating services...

	# service to manual to prevent audio stutter
	service manual "Intel(R) Desktop Boards FSC Application Service"
	service manual "IduService"

	return

	:IntelExt#eTuningUtility
	# Change motherboard configuration, control cooling, monitor hardware, perform stress and performance tests
	# - http://www.intel.com/design/motherbd/software/xtu/index.htm
	# - http://downloadcenter.intel.com/SearchResult.aspx?lang=eng&keyword=$22Intel+Ext#e+Tuning+Utility$22
	# Installs
	# - Service: XTUService - Intel(R) Ext#e Tuning Utility - "C:/Program Files (x86)/Common Files/Intel/Intel Ext#e Tuning Utility/PerfTuneService.exe" - Intel Ext#e Tuning Utility hardware interface.
	echot "\
	*******************************
	* Intel Ext#e Tuning Utility
	*******************************
	"

	# Version 3.0 only works on SandyBridge-E systems
	run "Intel/Motherboard/utility/Ext#e Tuning Utility/setup v2.1.408.35.exe"

	echo Updating services...

	# Change to manual as it crashes regularly
	service manual XTUSERVICE

	echo "Updating icons..."
	$rm "$pd/Intel*Ext#e Tuning Utility.lnk"
	$mergeDir --rename "$pp/Intel Ext#e Tuning Utility" "$pp/Operating System/Other/Intel/Ext#e Tuning Utility"

	return

	:IntelIntegratorAssistant
	# purpose: change bios, customize bios
	# http://www.intel.com/design/motherbd/software/iia/index.htm 
	# http://downloadcenter.intel.com/Detail_Desc.aspx?agr=Y&DwnldID=18672&ProdId=3273&lang=eng&OSVersion=$0A&DownloadType=$0ASoftware$20Applications$0A  and search http://downloadcenter.intel.com/SearchResult.aspx?keyword=$22$22integrator+assistant$22$22  and home path http://www.intel.com/design/motherbd/software/iia/index.htm 
	echot "\
	*******************************
	* Intel Integrator Assistant
	*******************************
	"

	installDir=$P/Intel Integrator Assistant
	run "Intel/Motherboard/utility/Integrator Assistant/IIA_1.1.7.872a.zip"

	return

	:IntelDP67BG
	# http://downloadcenter.intel.com/SearchResult.aspx?lang=eng&keyword=$22DP67BG$22#
	# Installs
	# - Sytem Run (x86) - NUSB3MON - "C:/Program Files (x86)/Renesas Electronics/USB 3.0 Host Controller Driver/Application/nusb3mon.exe"
	echot "\
	****************************
	* Intel DP67BG Motherboard
	****************************
	"

	driver=Intel/Motherboard/DP67BG/driver
	run "$driver/ESATA_allOS_1.2.0.7700_PV/drvSetup.exe"

	echo "Updating icons..."	
	$mergeDir "$pp/Renesas Electronics" "$pp/Operating System/Other/Intel"
	$mergeDir "$up/Marvell" "$pp/Operating System/Other/Intel"

	inst IntelRapidStorage

	echo Checking for updated drivers...
	if $? == 1 ShellRun http://www.intel.com/p/en_US/support/detect?redirector_count=1&

	return

	:IntelP35

	# Windows 7  comes with P35 chipdrivers
	if $@IsWindows7[] == 1 return

	echo Installing Intel Northbridge (P35 Bearlake) and southbridge (ICH9R) Chipdrivers..
	run "Intel/Chipset/V8.3.1.1009/infinst_autol.exe"

	return

	:Intel865Perl
	echot "\
	************************
	* Intel Box 865 Motherboard
	************************
	"

	driver=Intel/865PerlX/driver

	echo Intel 865 Chipdrivers...
	run "$driver/chipset/INF_AllOS_8.4.0.1016_PV_Intel.exe"

	inst IntelProNetworkAdapter IntelMotherboardUtilities

	if not defined NewOs then
		run "$driver/AUD_ALL32_5.12.1.5240_PV2.EXE"

		# SoundMAX "C:/Program Files/Analog Devices/SoundMAX/Smax4.exe" /tray
		echo Delete SoundMAX tray icon:
		registry 32 delete "HKLM/SOFTWARE/Microsoft/Windows/CurrentVersion/Run/SoundMAX"

		MergeDir /e "$pp/SoundMAX" "$pp/Operating System/Other"
	fi
		
	return

	:LenovoLaptop
	************************************************
	* Lenovo Laptop
	************************************************

	# Fan control and temperature monitoring - need if have issues with fan speed under high cpu utilization
	ThinkPadFanContoller

	run "Lenovo/drivers/Hotkey v3.02.0000.exe"
	run "Lenovo/drivers/Power Manager v3.12.exe"
	run "Lenovo/drivers/UltraNav v14.0.16.0 ${architecture}.exe"

	# Instal Bluetooth drivers to enable additional profiles (devices) such as the Voyager PRO+.
	run "Lenovo/drivers/Bluetooth v6.2.1.2900.exe" 
	BroadcomBluetooth false

	return

	:LenovoT400Laptop
	************************************************
	* Lenovo T400 Laptop
	************************************************
	"

	LenovoLaptop
	run "Lenovo/T400/drivers/video 7xd652ww.exe"
	run "Lenovo/T400/drivers/audio v4.92.12.0.exe"
	run "Lenovo/T400/drivers/card reader 7kss73ww.exe"

	return

	:Hp8560wLaptop
	:Laptop
	# download - http://h20000.www2.hp.com/bizsupport/TechSupport/SoftwareIndex.jsp?lang=en&cc=us&prodNameId=5071173&prodTypeId=321957&prodSeriesId=5071171&swLang=13&taskId=135&swEnvOID=4060
	echot "\
	************************************************
	* HP EliteBook 8560w Laptop
	************************************************
	"

	DriverDir=Hewlett Packard/EliteBook 8560w/driver

	# Instal Bluetooth drivers to enable additional profiles (devices) such as the Voyager PRO+.
	# run "$DriverDir/Broadcom 2070 Bluetooth/v20110430/Setup.exe" 
	# BroadcomBluetooth false

	# PROSet/Wireless Networking
	# run "$DriverDir/PROWireless/Wireless_15.3.1_s64.exe"
	# run "$DriverDir/NIC/PROWinx64.exe"
	# ProSetFinal

	echo Updating registry...

	# Delete QLBController - C:/Program Files (x86)/Hewlett-Packard/HP HotKey Support/QLBController.exe /start
	registry 32 delete "HKLM/SOFTWARE/Microsoft/Windows/CurrentVersion/Run/QLBController"

	return

	:GigabyteGaP35Dq6
	echot "\
	************************************************
	* Gigabyte GA-P35-DQ6 Motherboard
	************************************************
	"

	inst RealTekNic RealTekAudio

	# Intel Matrix RAID Controller
	# - 6 SATA ports on Intel southbridge ICH9R SATA controller, IDE/ACHI/RAID modes.
	# - AHCI/RAID supports eSata.  
	IntelRapidStorage

	# EasyTune - fan control, tune motherboard, not needed in Windows 7
	inst EasyTune

	# GSATA - Gigabyte SATA controler 
	# - 2 SATA ports.  IDE/AHCI/RAID modes.  AHCI/RAID supports eSata and  requires boot disk for OS install.  Installs drivers JGOGO, JRAID
	# - Gigabyte SATA controller in ACHI/RAID mode requires boot disk for OS install
	# - May be a cause of blue screens.
	# run "Gigabyte/motherboard/GA-P35-DQ6/driver/disk/GigaByte SATA RAID V1.17.20.03/setup.exe"

	# BIOS updater - view or update BIOS
	run "Gigabyte/motherboard/GA-P35-DQ6/utility/atBIOS/Setup.exe"

	echo "Updating icons..."
	$mergeDir --rename "$pp/GIGABYTE" "$pp/Operating System/Other/Gigabyte"
	$mv "$pp/Gigabyte Technology Corp/Gigabyte Raid Configurer.lnk" "$pp/Operating System/Other/Gigabyte"
	$rmd "$pp/Gigabyte Technology Corp"

	return

	:PowerMixer
	# Download - http://www.actualsolution.com/download.htm
	# Beta - http://www.actualsolution.com/power_mixer/beta.htm
	echot "\
	************************
	* Power Mixer
	************************
	"

	if defined NewOs then
		run "Actual Solution/Power_Mixer_3.6.exe"
	else
		run "Actual Solution/Power_Mixer_2.7.exe"
	fi

	echo "Updating icons..."
	$mergeDir "$up/Power Mixer" "$ao"
	$rm "$ao/Power Mixer/Home Page.lnk"
	$rm "$ao/Power Mixer/Online Registration.lnk"
	$rm "$ao/Power Mixer/Uninstall Power Mixer.lnk"

	echo Updating registry...

	# Delete Power Mixer - "C:/Program Files (x86)/Power Mixer/pwmixer.exe" /m
	registry 32 delete "HKCU/SOFTWARE/Microsoft/Windows/CurrentVersion/Run/Power Mixer"

	echo Restoring the default profile...
	PowerMixer profile restore default

	# LogMeIn tries to create wheel.dll if it is not present when Power Mixer is running
	if IsDir "$P32/LogMeIn" .and. not exist "$P32/LogMeIn" then
		copy /q "$P32/Power Mixer/wheel.dll" "$P32/LogMeIn"
	fi

	echot "\
	Options
	- View, Display for 1.0 sec
	- Mixer
	  - (prevent excessive references to wheel.dll by processes in ProcExp)
	    - Uncheck By mouse wheel when cursor is over
	    - Uncheck By mouse wheel
	    - Uncheck By mouse
	  - Method=Audio Taper
	  - Speed=40
	- System
	  - Uncheck Run on Windows Startup
	  - Check Start minimized
	  - Check Minimize to tray on Close
	- Presets, New
	  - Enter prename=Analog&Digital
	  - Select Realtek High Definition Audio, Edit
	    - Priority=1, Speaker settings=Stereo speakers|5.1 speakers|Stereo speakers
			- Priority=2, Default playback device=Realtek HD Audio output|Realtek Digital Output
	  - Select output Realtek HD Audio output|Realtek Digital Output, Edit, Volume=20|50|50
	  - Select line front|rear|na |100/50/Enable
		- (all lines to not change) Right click on Vol|Bal|M/S columns until grey
	- HotKeys, select audio device, Edit
	  - Check all, Ctrl+Num8/2/1/3/.
	- Tray icon, 
	  - Double-click action=Open Standard Mixer
	  - Tray icon image=Chameleon
	- Note: 
	  - PowerMixer crashes when setting options: delete configuration files
	  - Presets
	    - default audio device: Edit the audio device
	    - levels: right click on Vol|Bal|M/S (mute) to toggle between not changing (grey) and setting.
	    - Outputs: the level for the output
	    - Lines: the level for the outputs individual lines of the output, usually to 100
	"

	return


	return

	:XboxWirelessReceiver
	# http://www.microsoft.com/hardware/download/download.aspx?category=Gaming
	echot "\
	************************
	* Xbox Wireless Receiver
	************************
	"

	run "Microsoft/Xbox/Wiresless Receiver/Xbox360_v6.2.0029_$@OsBits[]Eng.exe"

	echo Updating...
	start /pgm "$P32/Microsoft Xbox 360 Accessories/Checker.exe" -forcecheck
	pause

	echo "Updating icons..."
	$mergeDir --rename "$pp/Microsoft Xbox 360 Accessories" "$pp/Games/Other/Xbox Accessories"

	return

	:AmazonCloudPlayer
	# https://www.amazon.com/gp/dmusic/mp3/player?ie=UTF8&$2AVersion$2A=1&$2Aentries$2A=0#latestUploads
	# https://www.amazon.com/gp/dmusic/order/amd-get-interstitial.html/ref=dp_amp_get_amd_for_dl_click
	echot "\
	************************
	* Amazon Cloud Player
	************************
	"

	run "Amazon/other/AmazonCloudPlayerInstaller337.exe"

	echo "Updating icons..."
	$makeDir "$ao/Amazon"
	$mergeDir --rename "$up/Amazon Cloud Player" "$ao/Amazon/Cloud Player"
	$rm "$ud/Amazon Cloud Player.lnk"

	echot "\
	- Configuratioin, General
	  - All downloads are sgtored here=Libraries/Music (roo) Public Music or Music
	"

	return

	:AdobeDigitalEditions
	# http://www.adobe.com/products/digital-editions/download.html
	echot "\
	*************************
	* Adobe Digital Additions
	*************************
	"

	run "Adobe/DigitalEditions/ADE_2.0_Installer.exe"

	# Move data folder
	$makeLink --merge --hide "$udata/Adobe Digital Editions" hide "$udoc/My Digital Editions"

	echo "Updating icons..."
	MergeDir.btm /quiet "$pp/Adobe" "$ao"
	$rm.btm "$pp/Adobe Digital Editions 2.0.lnk"
	$rm.btm "$pd/Adobe Digital Editions 2.0.lnk"

	return

	:Kindle
	# http://www.amazon.com/gp/feature.html/ref=kcp_pc_mkt_lnd?docId=1000426311
	# http://www.ebook-converter.com/kindle-drm-#oval.htm
	echot "\
	************************
	* Kindle
	************************
	- Installs: Kindle reader for PC
	"

	run "Amazon/Kindle/setup/Kindle for PC v1.10.6.40500.exe"
	run "Amazon/Kindle/converter/Kindle DRM #oval v5.0.0.0.exe"

	echo Creating data folders...
	$makeDir "$udata/Kindle"
	$makeDir "$udata/Kindle DRM #oval"
	$makeDir "$udoc/Kindle DRM #oval"
	$hide +h "$udoc/Kindle DRM #oval"

	echo "Updating icons..."
	$mergeDir "$pp/Amazon" "$ao"
	$mergeDir "$up/Amazon" "$ao"
	$mergeDir --rename "$ao/Amazon/Amazon Kindle" "$ao/Amazon/Kindle"
	$mergeDir "$up/Kindle DRM #oval" "$ao"
	$rm "$pd/Kindle.lnk"
	$rm "$ud/Kindle.lnk"
	$rm "$ud/Kindle DRM #oval.lnk"
	$rm "$ao/Amazon/Kindle/Uninstall Kindle.lnk"

	echot "\
	Kindle for PC
	- Tools, Options
	  - General, uncheck Automatically install updates
	  - Content, Change Folder, data/Kindle

	- Kindle DRM #oval
	  - Check Check if eBook file copy from Kindle reader, input Kindle Serial Number
	  - Kindle Serial Number=NNN
	  - Output Folder=My Documents/data/Kindle DRM #oval
	  - #ote all Kindle ebooks in folder, Input Folder=My Documents/data/download
	"
	ShellRun "https://www.amazon.com/gp/digital/fiona/manage?ie=UTF8&ref_=sv_kinc_7&signInRedirect=1&#manageDevices"
	kindle start
	kindle decrupt
	pause

	return

	:BitTorrent
	echot "\
	************************
	* BitTorrent
	************************
	"

	run "shareware/BitTorrent/BitTorrent-6.0.exe"

	echo "Updating icons..."
	$mergeDir "$pp/BitTorrent" "$ao"

	return

	:DriveMonitor
	echot "\
	************************
	* Acronis Drive Monitor
	************************
	"

	run "Acronis/setup/Drive Monitor v1.0.0.187.exe"

	echo "Updating icons..."
	$mergeDir "$pp/Acronis" "$pp/Operating System/Other"
	$mv "$pd/Acronis Drive Monitor.lnk" "$pp/Operating System"

	return 

	:DiskDirector
	# http://www.acronis.com/support/updates/
	echot "\
	- Complete install
	"

	# Disk Director Suite cannot be install on servers
	if defined server return

	run "Acronis/setup/DiskDirector v11.0.0.2343.exe"

	echo "Updating icons..."
	$mergeDir "$pp/Acronis" "$pp/Operating System/Other"

	# Acronis shortcuts include special characters in place of spaces that interfere with normal processing
	$rm "$ud/Acronis OS Selector.lnk" "$pd/Acronis*.lnk"

	return

	:TrueImage
	# http://www.acronis.com/support/updates
	# 
	# Installs:
	# - Startup
	#    HKCU, TrueImageMonitor. c:/program files/acronis/trueimageworkstation/trueimagemonitor.exe	
	#    HKLM, Acronis Scheduler2 Service, "C:/Program Files (x86)/Common Files/Acronis/Schedule2/schedhlp.exe"
	# - Service
	#   fltsrv, Acronis Storage Filter Management
	#   fltsrv30, Acronis Storage Filter Management (Build 30)
	# - Other: Acronis True Image Shell Extensions
	# - Update (validate and update with new version on oversoul)
	#   Acronis Scheduler2 Service, Acronis Scheduler Helper	Acronis	c:/program files/common files/acronis/schedule2/schedhlp.exe	
	# - AcronisTimounterMonitor, Monitor for Acronis True Image Backup Archive Explorer	Acronis	c:/program files/acronis/trueimageworkstation/timountermonitor.exe	
	# - AcronisOSSReinstallSvc, File not found: C:/Program Files/Common Files/Acronis/Acronis Disk Director/oss_reinstall_svc.exe	
	# - AcrSch2SvcProvides task scheduling for Acronis applications.	Acronis	c:/program files/common files/acronis/schedule2/schedul2.exe	
	# - tifsfilter, Acronis True Image File System Filter	Acronis	c:/windows/system32/drivers/tifsfilt.sys	
	# - timounter, Acronis True Image Backup Archive Explorer	Acronis	c:/windows/system32/drivers/timntr.sys	
	# - relog_ap, Acronis Relogon Authentication Package	Acronis	c:/windows/system32/relog_ap.dll	
	# 
	# Disk Director Suite installs:
	# - snapman, Acronis Snapshot API	Acronis	c:/windows/system32/drivers/snapman.sys	
	echot "\
	************************
	* Acronis TrueImage
	************************
	- Complete install
	"

	run "Acronis/setup/True Image v15.0.0.6154.exe"
	run "Acronis/setup/True Image Plus Pack v15.0.0.6154.exe"

	echo "Updating icons..."

	$mergeDir "$pp/Acronis" "$pp/Operating System/Other"
	$rm "$pd/Acronis Online Backup.lnk"
	$rm "$pd/Acronis True Image Home 2012.lnk"

	# Delete Acronis Scheduler2 Service  - "C:/Program Files (x86)/Common Files/Acronis/Schedule2/schedhlp.exe"
	registry delete "HKLM/SOFTWARE/Microsoft/Windows/CurrentVersion/Run/Acronis Scheduler2 Service"

	echot "\
	- Tools, Options
	  - Default Backup Options, Compression Level, Maximum
	"
	RunProg "$P32/Acronis/TrueImage/TrueImage.exe"
	pause

	echot "\
	- Notes: Backup location: <backup drive>/acronis
	"

	return

	:OsSelector
	echot "\
	************************
	* Acronis OS Selector
	************************
	- Requires Acronis Disk Directory Suite
	- Install OS Selector only on on one partition
	"

	echo Installing OS Selector...
	RunProg "$P32/Acronis/Acronis Disk Director/OSSelectorSetup.exe"
	pause

	echot "\
	- Tools, Options
		- Display Properties=1,024x768, 72Hz
	- Select Boot from floppy A:, click Hide the selected operating system
	- #ove unused operating systems
	- Edit existing (Select os, Properties) or create new (Tools, OS Detection Wizard)
	  - General Propertes, Edit the operating system name
	  - Partitions, select other partitions, Hide
		- Close and open, verify C: boot,system, d: data drive, rest hidden
	"
	RunProg "$P32/Acronis/Acronis Disk Director/OS_Selector.exe"
	pause


	echot "\
	- Tools, Options
	  - Generation Options, No, do not protect folders
	  - Startup Options, With timeout=10sec
	  - Display Properties, Screen resolution=1,280 by 1,024 pixels, Color quality=High (24 bit)
	  - Input Devices=PS/2 or USB compatible (if OS fail to boot with restart, use No mouse)
	- Operating System, Properties
	  - General Properties, Edit the operating system name=<volume name>, Change Icon...
	  - Partitions, validate drive letters, ensure only one Windows partition is visible
	  - Folders, Properties, Enagle or disable restoring the folder contents=Disabled
	"

	return

	:RealTekNic
	# PCIe: http://www.realtek.com.tw/downloads/downloadsView.aspx?Langid=1&PNid=13&PFid=5&Level=5&Conn=4&DownTypeID=3&GetDown=false
	# PCI: http://www.realtek.com.tw/downloads/downloadsView.aspx?Langid=1&PNid=13&PFid=4&Level=5&Conn=4&DownTypeID=3&GetDown=false&Downloads=true
	echot "\
	************************
	* RealTek NIC
	************************
	"

	if $@IsWindows7[] == 1 then
		run "RealTek/PCIe NIC/Win7 Driver V7.009.11202009/setup/setup.exe"
	fi

	echo "Updating icons..."
	$mergeDir "$pp/Realtek" "$pp/Operating System/Other"

	echo - Verify Realtek driver is installed and if required run setup again 
	os DeviceManager
	pause

	return

	:RealTekAudio
	# Drivers: http://www.realtek.com.tw/downloads/downloadsView.aspx?Langid=1&PNid=14&PFid=24&Level=4&Conn=3&DownTypeID=3&GetDown=false
	echot "\
	************************
	* RealTek Audio
	************************
	"

	echo Closing audio software...
	WindowsMediaPlayer close
	iTunes close
	PowerMixer close

	run "RealTek/High Definition Audio/v2.70/setup.exe"

	echot "\
	- Realtek HD Audio Manager
	  - i, uncheck Display icon in notifcationa rea
	  - Digital Output
	    - (if present) DTS Connect, Music Mode
	    - Default Format, DTS Interactive (if present) or DVD Format
	  - Speakers, Back Panel, double click blue, check Front Speaker Out
	- Control Panel, Sound, Playback, Realtek Digital Output, properties
	  - Supported Formats click on an Encoded format and Sample Rate then Test
	  - Check Dolby Digital and 48.0 Khz
	"
	RealTekAudio.btm start
	pause

	SoundListen

	return

	:VgaEasyBoost
	# Change configuration and update BIOS
	# download - http://www.gigabyte.com/products/product-page.aspx?pid=3799#utility
	echot "\
	***************************
	* Gigabyte VGA Easy Boost
	***************************
	- Use VGA@BIOS only if cannot update BIOS using Easy Boost
	"

	run "Gigabyte/GPU/Easy Boost/vga_utility_easy_boost_v1.0.4.1.EXE"
	# run "Gigabyte/GPU/VGA@BIOS/vga_utility_atbios_ver4.3.exe"

	echo "Updating icons..."
	$rm "$pd/EasyBoost.lnk"
	$mergeDir "$pp/GIGABYTE" "$pp/Operating System/Other"
	$mergeDir "$up/GIGABYTE" "$pp/Operating System/Other"

	return

	:EasyTune
	# Tune motherboard settings, view system statistics (temperature, fan), control thermal (fan)
	# Updates http://www.gigabyte-usa.com/Support/Motherboard/Utility_List.aspx
	# EasyTune: Installs Drivers: ET5Drv and MarkFun_NT (previous: gdrv)
	echot "\
	************************
	* EasyTune
	************************
	"

	run "Gigabyte/motherboard/utility/Easytune/VB7.1221.1/Setup.exe"

	echo Updating registry...

	# Delete EasyTuneV - C:/Program Files (x86)/Gigabyte/ET5Pro/ETcall.exe
	registry 32 delete "HKLM/SOFTWARE/Microsoft/Windows/CurrentVersion/Run/EasyTuneVPro"

	echo "Updating icons..."
	$mv "$pd/EasyTune5 Pro.lnk" "$pp/Operating System"
	$mergeDir "$pp/Gigabyte" "$pp/Operating System/Other"

	echot "\
	- Smart Fan, 28$-100$ from 35c to 66c
	"
	app EasyTune
	pause

	return

	:XmlNotepad
	# http://www.microsoft.com/downloads/details.aspx?familyid=72d6aa49-787d-4118-ba5f-4f30fe913628&displaylang=en
	echot "\
	************************
	* XML Notepad
	************************
	"

	run "Microsoft/other/XmlNotepad.msi"

	echo "Updating icons..."
	$mv "$ud/XML Notepad 2007.lnk" "$pp/Development/XML Notepad.lnk"
	$mergeDir --rename "$up/XML Notepad 2007" "$pp/Development/Other/XML Notepad"


	echot "\
	- Notes
	  - Drag and drop files onto the XmlNotepad icon in QuickLinks
	"

	return

	:PinnacleGameProfiler
	# Installs: PinnacleUpdateSvc
	echot "\
	************************
	* Pinnacle Game Profiler
	************************
	"

	run "PowerUp Software/Pinnacle Game Profiler/setup/Pinnacle Game Profiler v5.5.0.2.exe"

	# Delete Pinnacle Game Profiler - "C:/Program Files (x86)/PowerUp Software/Pinnacle Game Profiler/pinnacle.exe" -atboottime
	registry 32 delete "HKCU/SOFTWARE/Microsoft/Windows/CurrentVersion/Run/Pinnacle Game Profiler"

	echo Updating services...
	service manual PinnacleUpdateSvc

	echo "Updating icons..."
	$rm "$pd/Pinnacle Game Profiler.lnk"
	$mergeDir "$pp/Pinnacle Game Profiler" "$pp/Games/Other"

	return

	:GameJackal
	echot "\
	************************
	* GameJackal
	************************
	- Profile Key: oversoul 52918-39382-4145361111-13536
	"

	run "SlySoft/Game Jackal/SetupGameJackal4117.exe"

	echo Updating registry...
	registry import "$install/SlySoft/Game Jackal/Key.GameJackal.reg"

	# Delete Maplom - C:/Program Files/SlySoft/Game Jackal/GameJackal.exe /silent
	registry 32 delete "HKLM/SOFTWARE/Microsoft/Windows/CurrentVersion/Run/Maplom"

	echo "Updating icons..."
	$rm "$ud/Game Jackal.lnk"
	$mergeDir "$pp/SlySoft" "$pp/Games/Other"
	CopyFile "$pp/Games/Other/SlySoft/Game Jackal/Game Jackal.lnk" "$pp/Games"

	return

	:GameTap
	echot "\
	************************
	* GameTap
	************************
	"

	run "GameTap/gametap_setup.exe"

	echo "Updating icons..."
	$rm "$pd/GameTap.lnk"
	$mergeDir "$pp/GameTap" "$pp/Games/Other"
	CopyFile "$pp/Games/Other/TameTap/GameTap.lnk" "$pp/Games"

	return

	:mmc
	# MMC 3.0 supports .NET snap-ins
	echot "\
	********************************
	* Microsoft Management Console
	********************************
	"

	# MMC 3.0 comes with server and new clients
	if defined NewOs .or. defined server return

	run "Microsoft/Windows/mmc/MMC V3.0 for Windows $_WinVer ${architecture}.exe"

	echo Optimizing...
	if "$@search[mmcperf]" != "" mmcperf

	return

	:FingerAuth
	echot "\
	************************
	* FingerAuth
	************************
	"

	# FingerCap driver supported only on x86
	if "${architecture}" != "x86" return 1

	# Install the fingerprint reader driver
	# x64 support: http://forum.griaule.com/viewtopic.php?t=3884
	run "Mozilla/Firefox/extension/setup/FingerCap_USB_Driver_1.2_Installer.exe"

	# Install FingerAuth	
	Firefox "$install/Mozilla/Firefox/extension/setup/FingerAuth1.0.1.0.xpi"
	pause
		
	# Restore the FingerAuth profile
	FingerAuth profile restore default

	return

	:IsoRecorder
	echot "\
	************************
	* ISO Recorder
	************************
	"

	if $@IsNewOs[] == 1 then
		run "shareware/ISO Recorder/ISORecorder v3 ${architecture}.msi"
	else
		run "shareware/ISO Recorder/ISORecorder v2.msi"
	fi

	return

	:LimeWire
	# http://www.limewire.com
	echot "\
	************************
	* LimeWire
	************************
	"

	# LimeWire installs a JRE if not present
	if not IsDir "$P32/Java" jre

	run "Shareware/LimeWire/LimeWireWin V5.4.6.exe"

	echo "Updating icons..."
	$makeDir "$pp/Media/Other"
	$mv "$ud/LimeWire*.lnk" "$pp/Media/LimeWire.lnk"
	$mergeDir "$up/LimeWire" "$pp/Media/Other"

	echot "\
	- Notes
	  - If connection not strong, File, Disconnect then File, Connect
	"

	return

	:7zip
	# download http://www.7-zip.org/download.html
	echot "\
	************************
	* 7-Zip
	************************
	"

	prefix=7z922
	ExeBase=Shareware/7-Zip/setup/$prefix
	exe32=$ExeBase-x86.exe
	exe64=$ExeBase-x64.msi

	# x64 OS 32 bit programs use x86 7-zip when running, install x64 exe last so the 7-zip file manager icon is x64
	run "$exe32"
	if "${architecture}" == "x64" then
		echo $@ClipW[$P/7-Zip/] >& nul:
		echo `- (ensure correct install location) *** Location, Browse, <paste> ***`
		run "$exe64"
	fi

	# Update bin files
	copy /q /u "$P/7-zip/7-zip.chm" "$PublicData/bin/win" >& nul:
	copy /q /u "$P32/7-zip/7z.exe" "$P32/7-zip/7z.dll" "$PublicData/bin/win" >& nul:
	copy /q /u "$programs64/7-zip/7z.exe" "$programs64/7-zip/7z.dll" "$PublicData/bin/win64" >& nul:

	echo "Updating icons..."
	$mergeDir "$pp/7-Zip" "$ao"

	echot "\
	- Tools, Options
	  - System, select all Types, click + above All Users
	  - Editor, C:/Program Files/Sublime Text 2/sublime_text.exe
	  - Dif=C:/Program Files (x86)/Beyond Compare 3/BComp.exe
	  - Settings, check Show system menu
	"
	7zip start
	pause

	return

	:SetPoint
	# Change hot key function, configure mouse (pointer speed and acceleration, Smart Move), view battery level.
	# - Downloads: http://www.logitech.com/en-us/support/mice/wireless-mouse-m510
	# - Services:  
	#   - LMouFilt: Logitech SetPoint KMDF Mouse Filter Driver
	#   - LHidFilt: Logitech SetPoint KMDF HID Filter Driver
	#   - LBTServ: Logitech Bluetooth Service
	# - Startup: "$P/Logitech/SetPoint/SetPoint.exe" /s
	echot "\
	***************************************
	* Logitech SetPoint (keyboard and mice)
	***************************************
	"

	run Logitech/SetPoint/setpoint651_${architecture}.exe

	echo Updating registry...

	# Delete EvtMgr6 - C:/Program Files/Logitech/SetPointP/SetPoint.exe /launchGaming
	registry 32 delete "HKLM/SOFTWARE/Microsoft/Windows/CurrentVersion/Run/EvtMgr6"

	echo "Updating icons..."
	$mergeDiruiet "$pp/Logitech" "$pp/Operating System/Other"
	$rm.btm "$up/Startup/Logitech . Product Registration.lnk"
	$rm.btm "$pd/Logitech Mouse and Keyboard Settings.lnk"
	$rm.btm "$pp/Logitech SetPoint.lnk"

	echot "\
	- Pointer and Scrolling Settings, Pointer Speed=2, Pointer Acceleration=Medium, 
	"
	start /pgm "$P/Logitech/SetPointP/SetPoint.exe" /ss
	pause

	return

	:LogitechWebCam
	# download http://www.logitech.com/index.cfm/435/3480&cl=us,en
	# updates "C:/Program Files/Common Files/logishrd/WUApp64.exe" -v 0x046d -p 0x0994 -b 0x0006 -f Video -d 11.80.1048.0 -m Logitech
	#
	# Version
	#  - Microsoft video camera driver used by default if LogitechWebcam not installed
	#  - Windows Update downloads  V11.4.0.1145 - driver only, did not crash system
	#  - Windows Update now downloads  QuickCam V11.80.1065 - driver and gui, stability not tested
	#  - QuickCam V11.5 software - drivers and GUI app, caused blue screen on Vista x64 when using GUI
	#  - QuickCam V11.90.1263 software - drivers and GUI app,  Worked fine on oversoul.
	#  - Webcam 1.00.1280 - testing on oversoul
	# 
	# Services:
	# LVCOMSer - Logitech Video COM Service
	# LVPrcSrv/LVPr64 - Process Monitor - Injector service
	# LVSrvLauncher - Launcher for Logitech Video Components.
	# 
	# Drivers:
	#  LVcKap/LVcKap64 - Logitech AEC Driver
	# LVMVDrv - Logitech Machine Vision Engine Loader
	# lvpopflt/lvpopf64 - Logitech POP Suppression Filter
	# LVPr2Mon/LVPr2M64 - Logitech LVPr2Mon Driver
	# lvrs/lvrs64 - Logitech RightSound Filter Driver
	# lvselsus/lvsels64 - Logitech Selective Suspend Filter
	# LVUSBSta/LVUSB64 - Logitech USB Monitor Filter
	# LVUVC/LVUVC64 - QuickCam Orbit/Sphere AF(UVC)
	# 
	# Run: HKLM/SOFTWARE/Microsoft/Windows/CurrentVersion/Run
	# LogitechCommunicationsManager - "C:/Program Files/Common Files/LogiShrd/LComMgr/Communications_Helper.exe"  - for advanced camera features
	# LogitechQuickCamRibbon - "C:/Program Files/Logitech/QuickCam/Quickcam.exe" /hide

	echot "\
	************************
	* Logitech Webcam
	************************
	"

	run "Logitech/Webcam/lws280_full.exe"

	echo Moving data folder...
	$makeLink --merge --hide "$udata/Logitech" hide "$UserHome/Logitech"

	echo Updating registry...

	registry delete "HKLM/SOFTWARE/Microsoft/Windows/CurrentVersion/Run/Logitech Download Assistant"

	# Delete LogitechQuickCamRibbon - "C:/Program Files/Logitech/QuickCam/Quickcam.exe" /hide
	registry 32 delete "HKLM/SOFTWARE/Microsoft/Windows/CurrentVersion/Run/LogitechQuickCamRibbon"

	# Delete Logitech Vid- "C:/Program Files (x86)/Logitech/Logitech Vid/vid.exe" -bootmode
	registry 32 delete "HKCU/SOFTWARE/Microsoft/Windows/CurrentVersion/Run/Logitech Vid"

	# Delete LWS - C:/Program Files (x86)/Logitech/LWS/Webcam Software/LWS.exe -hide
	registry 32 delete "HKLM/SOFTWARE/Microsoft/Windows/CurrentVersion/Run/LWS"

	echo "Updating icons..."
	dest=$ao/Logitech/Logitech Webcam Software
	$mergeDir --rename "$pp/Logitech" "$dest"
	$mv "$pd/Logitech Webcam Software*.lnk" "$dest"
	$mv "$pd/Logitech Vid HD.lnk"  "$dest"
	$rm "$up/Startup/Logitech . Product Registration.lnk"

	return

	:WigginPrinter

	if $@IsWindows8[] == 1 then
		text
	- Add a printer
	- Windows Update
	- Brother, Brother HL-4070CDW
	- Printer name=study
	- Do not share this printer
	- Printer preferences
	  - Layout, Print on Both Sides=Flip on Long Edge
	  - Paper/Quality, Color=Black & White
		"
		printer.btm add
		pause
		return 0

	elif $@IsWindows7[] == 1 then
		text
	- Add a network, wireless or Bluetooth printer
	- Select HL-4070CWD series (Brother)
	- Printer name=office (desktop) or wiggin (mobile)
	- Do not share this printer
		"
		printer.btm add
		pause
		return 0
	fi

	echo Installing Brother HL-4070cdw...
	ask "Do you want to install the print monitor?" n
	if $? == 1 then
		BrotherHl4070
	else
		run "Brother/HL-4070cdw/driver/deploy/Wiggin Printer ${architecture}.exe"		
		BrotherHl4070Final
	fi

	return

	:BrotherHl4070
	# Driver: http://welcome.solutions.brother.com/bsc/public/us/us/en/dlf/download_top.html?reg=us&c=us&lang=pskillen&prod=hl4070cdw_all
	# Installs:(xp) BrPar service, BrSplService (Brother XP spl Service).   These services are not required to print, and caused the LAN drive to fail to start on jjbutare-mobl.
	echot "\
	************************
	* Brother HL-4070cdw
	************************
	- (Select Driver) Brother HL-4070CDW series
	- (option) Custom Installation, check PS(PostScript Emulation) Driver
	-	(Select Connection) Brother Peer-to-Peer Network Printer
	- (Select a Printer) Uncheck by Node Name
	- Printrs
	  - Rename, printer
	  - Properties, Printer Preferences...m Custom, Duplex/Booklet=Duplex
	"

	run "Brother/HL-4070cdw/driver/Full V1.01/Driver/Inst/ENGLISH/setup.exe"
	run "Brother/HL-4070cdw/driver/Deployment Wizard V1.42.10/setup.exe"

	echo Updating registry...
	registry import "$install/Brother/HL-4070cdw/driver/deploy/monitor.reg"

	echo "Updating icons..."
	dest=$pp/Operating System/Other 
	$mergeDir "$pp/Brother HL-4070CDW" "src=$pp/Brother Personal Utilities"

	BrotherHl4070Final

	return

	:BrotherHl4070Final

	# Parallel port driver is not needed for new Windows operating systems
	if $@IsNewOs[] == 0 service demand BrPar

	echot "\
	- Note: printer is installed to a printer port that specified the IP address explicitly.  
	  Host file entries do not function correctly (no status updates and hung while printing).
	  If the printer IP address changes, update the printer port with the new IP address.
	"

	return

	:GraphEdit
	echot "\
	**********************************
	* DirectShow SDK Filter Graph Edit
	**********************************
	"

	FindExe "Microsoft/DirectX/GraphEdit/GraphEdit Setup x86.reg"
	if $_? != 0 return $_?

	# Filter property pages
	regsvr32 /s "$_PublicBin/x86/PropPage.dll"
	registry import "$exe"

	echo "Updating icons..."
	$makeDir "$pp/Media/Other"
	$makeShortcut "$_PublicBin/win/GraphEdit.exe" "$pp/Media/Graph Edit 32.lnk"

	echo Configuring x64 filter support...
	if "${architecture}" == "x64" then
		regsvr32 /s "$_PublicBin/x64/PropPage.dll"
		registry import "$ExeDir/GraphEdit Setup x64.reg"
		$makeShortcut "$_PublicBin/win64/GraphEdit.exe" "$pp/Media/Graph Edit 64.lnk"
	fi

	return

	:CoreAVC
	# https://customers.corecodec.com/
	echot "\
	****************************************
	* CoreAVC - H.264 Multi-core video codec
	****************************************
	- Uncheck Haali
	"

	run "CoreCodec/CoreAVC/CoreAVC Professional v3.0.1.0.exe"

	echo "Updating icons..."
	$mergeDir "$pp/CoreCodec" "$pp/Media/Other"

	return

	:K-Lite
	# Software based codec package (mpeg-2, H.264, DivX), x86 explorer thumbnail generation
	# Download Mega: http://www.codecguide.com/ http://www.codecguide.com/klcp_64bit.htm
	echot "\
	************************
	* K-Lite Codec Package
	************************
	"

	if IsDir "$P32/K-Lite Codec Pack" .or. IsDir "$programs64/KLCP64" .or. IsDir "$P32/QuickTime Alternative" then
		echo - Uninstall K-Lite and QuickTime Alternative
		os programs
		pause
	fi

	echo.
	echo Installing K-Lite x86 codecs...
	run "Shareware/K-Lite/K-Lite Mega Codec Pack V4.4.5.exe" /silent /norestart /LoadInf="./klmcp.ini"
	if $_? != 0 return $_?

	if "${architecture}" == "x64" then
		echo.
		echo Installing K-Lite x64 codecs...
		
		run "Microsoft/Visual Studio/redistributable/vcredist_x64.exe"	
		if $_? != 0 return $_?
		
		run "Shareware/K-Lite/K-Lite Codec Pack x64 V1.6.2.exe"
		if $_? != 0 return $_?
		
	fi

	# QuickTime Lite - install if QuickTime is not installed
	if not IsDir "$P32/QuickTime" then
		echo.
		echo Installing QuickTime Lite (required for QuickTime VR)...
		run "Shareware/K-Lite/quicktimealt270.exe" /norestart /LoadInf="./quicktimealt.ini"
		if $_? != 0 return $_?
	fi

	echo "Updating icons..."
	$makeDir "$pp/Media/Other"
	$mergeDir "$pp/K-Lite Codec Pack" "$pp/Media/Other"
	$mergeDir "$pp/K-Lite Codec Pack x64" "$pp/Media/Other"
	$mergeDir "$pp/QuickTime Alternative" "$pp/Media/Other"

	# Configure FFDShow Video
	echot "\

	Configuring ffdshow video decoder...
	- MPEG2=libavcodec (Windows MPEG2 codec stutters)
	"
	FFDShow 32 configure video
	if "${architecture}" == "x64" FFDShow 64 configure video
	pause

	# Configure Haali splitter
	echot "\

	Configuring Haali Media Splitter...
	- Options
	  - (optional) Compatiblity, Autoload VSFilter=No
	  - Input 
	    - Input buffer size=16192 (or 32000, for audio stutter on high bitrate video)
	    - Number of TS packets to scan=90000 ( prevent stutter on some computers for MP4 transport stream)
	  - Output, Decode priority boost=On (to prevent stutter on some computers) 
	"
	haali configure
	pause


	echot "\
	- Notes
	  - Useful filters (while video is playing or in ffdshow video decoder configuration):
	    - OSD (On Screen Display), Deinterlacing
	"

	return

	# Wireshark - Network packet capture and analyzer
	# http://www.wireshark.org/download.html
	# driver - NPF (Network Packet Filter, installed with WinPCAP, if stopped must be started manually, or wun WireShark as administrator)
	:Wireshark
	echot "\
	************************
	* Wireshark
	************************
	"

	run "Shareware/WireShark/setup/wireshark-win$@OsBits[]-1.8.3.exe"
	 
	echo "Updating icons..."
	$mv "$pp/Wireshark.lnk" "$pp/Operating System"
	$mergeDir "$pp/Wireshark" "$pp/Operating System/Other"
	$mergeDir "$pp/WinPcap" "$pp/Operating System/Other"

	echo Updating services...
	service manual NPF

	echot "\
	- View, Name Resolution, Enable for Network Layer
	"

	return

	# Nmap - port analyzer
	:Nmap
	echot "\
	************************
	* Nmap
	************************
	"

	run "Shareware/NMap/nmap-4.68-setup.exe"

	echo "Updating icons..."
	$mergeDir "$up/Nmap" "$pp/Operating System/Other"
	$mv "$ud/Nmap - Zenmap GUI.lnk" "$pp/Operating System"

	return

	:MediaInfo
	echot "\
	************************
	* MediaInfo
	************************
	"

	run "Shareware/MediaInfo/setup/MediaInfo_0.7.7.1_GUI_win.exe"

	echo "Updating icons..."
	$makeDir "$pp/Media/Other"
	$mergeDir "$up/MediaInfo" "$pp/Media/Other"


	echot "\
	- Setup
	  - Output format=Tree
	  - Check Shell InfoTip
	"

	return

	:Skype
	# http://www.skype.com/go/getskype-full, http://download.skype.com/msi/SkypeSetup_6.3.0.105.msi
	# http://www.skype.com/business/products/software/
	echot "\
	************************
	* Skype
	************************
	- Options, uncheck Install Skype Extras Manager
	"

	# ask "Install beta? ` n
	prefix=SkypeSetup_$@if[ 0 == 1 ,NA,6.3.0.105]
	run "Microsoft/Skype/setup/$prefix.exe"
	skype close

	echo Updating registry...

	# Delete Skype - "C:/PROGRAM FILES (X86)/SKYPE/PHONE/SKYPE.EXE" /nosplash /minimized
	registry 32 delete "HKCU/SOFTWARE/Microsoft/Windows/CurrentVersion/Run/Skype"

	echo "Updating icons..."
	$mv "$pd/Skype.lnk" "$pp/Applications"
	$mergeDir "$pp/Skype" "$ao"

	echot "\
	- Tools, Options
	  - Video settings, Webcam settings
	    - Webcam control, adjust pan and tilt
	    - Advanced Settings, uncheck right light, uncheck Gain Auto, 
	  - Advanced, uncheck Show Skype watermark during calls
	  - Advanced, Connection, uncheck use port 80 and port 443
	"

	return

	:PrimoPDF
	echot "\
	************************
	* PrimoPDF - Create PDF
	************************
	"

	run "Nitro PDF/InternationalPrimoPDF.exe"

	echo "Updating icons..."
	$mergeDir "$pp/PrimoPDF" "$ao"
	$mv "$pd/PrimoPDF - Drop Files Here to Convert!.lnk" "$ao/PrimoPDF"

	return

	:FileZilla
	echot "\
	************************
	* FileZilla
	************************
	- Uncheck Shell Extension
	"

	run "Shareware/FileZilla/setup/FileZilla_3.7.0.2_win-setup.exe"

	echo "Updating icons..."
	$mergeDir "$pp/FileZilla FTP Client" "$pp/Operating System/Other"

	echo Moving configuration data to the cloud...
	DropBox MoveConfig "$_ApplicationData/FileZilla" "$CloudData/FileZilla"

	echot "\
	- Edit, Settings
	  - (Intel network) Connection, FTP, FTP Proxy
	    - Type of FTP Proxy=USER@HOST
	    - Proxy host=proxy.fm.intel.com
	  - Transfers, Maximum simultaneous transfers=10
	"
	FileZilla
	pause

	return

	:HdTune
	echot "\
	************************
	* HD Tune
	************************
	"

	run "Shareware/HD Tune/hdtune_255.exe"

	echo "Updating icons..."
	$rm "$ud/HD Tune.url"
	$mergeDir "$pp/HD Tune" "$pp/Operating System/Other"

	return

	:SqlPrettyPrinter
	echot "\
	************************
	* SQL Pretty Printer
	************************
	"

	run "Gudu Software/SQL Pretty Printer/setup v2.9.0.msi"

	echo "Updating icons..."
	$mv "$ud/SQL Pretty Printer.lnk" "$pp/Development"
	$mergeDir "$up/SQL Pretty Printer" "$pp/Development/Other"


	echot "\
	- SQL / Code Options, Setup New Hotkey
	- Notes
	  - Select text in any program and Ctrl-Alt-Backspace to format
	"
	start /pgm "$P32/Gudu Software/SQL Pretty Printer/sqlpp.exe"

	return

	:TrueCrypt
	# download - http://www.truecrypt.org/downloads
	echot "\
	************************
	* TrueCrypt
	************************
	"

	run "Shareware/TrueCrypt/TrueCrypt Setup 7.1a.exe"

	$makeDir "$UserHome/Documents/data/TrueCrypt"

	echo "Updating icons..."
	$mergeDir "$pp/TrueCrypt" "$ao"
	$mergeDir "$up/TrueCrypt" "$ao"
	$rm "$ao/TrueCrypt/TrueCrypt Website.url"
	$rm "$ao/TrueCrypt/Uninstall TrueCrypt.lnk"
	$rm "$pd/TrueCrypt.lnk"

	echot "\
	- Settings, Hot Keys...
	  - Mount Favorite Volumes - Control+Shift+Alt+F2
	  - Dismount All - Control+Shift+Alt+F3
	  - Force Dismount All, Wipe Cache & Exit - Control+Shift+Alt+F4
	- Settings, Preferences
	  - Uncheck Preserve modification timestamp of file containers
	  - Check Cache passwords in driver memory
	  - Uncheck Wipe cached passwords on auto-dismount and exit
	- T:, Select File..., data/TrueCrypt, personal.tc, Mount
	- Favorites, Add Mounted Volumes to Favorites...
	  - Label of selected favorite volume=Personal
	"
	sudo /standard TrueCrypt start
	pause

	return

	:SecretAgent
	echot "\
	************************
	* SecretAgent
	************************
	"

	run "Information Security Corporation/SecretAgent/SA594.EXE"

	echo Installing OpenPGP interoperability...
	CopyFile "$install/Information Security Corporation/SecretAgent/OpenPGP Interoperability/gpgisc.dll" "$P32/SecretAgent 5"

	echo "Updating icons..."
	$rm "$pd/SecretAgent 5.lnk"
	$mergeDir "$pp/SecretAgent 5" "$ao"


	echot "\
	- Microsoft CryptoAPI Token Configuration: select certificate to use for Encryption and Signin
	"

	return

	:Paint.NET
	# http://www.getpaint.net/download.html
	echot "\
	************************
	* Paint.NET
	************************
	"

	run "Shareware/Paint.NET/Paint.NET.3.36.exe"

	echo "Updating icons..."
	$rm "$pd/Paint.NET.lnk"
	$mv "$pp/Paint.NET.lnk" "$pp/Media"

	return

	:CrystalReportsServer11
	echot "\
	****************************
	* Crystal Reports Server 11
	****************************
	- Prerequisite:  SQL Server database named CMS
	- Install Type=New, Use an existing database server
	- CMS Database Information, Browse,  Machine Data Source, New..., System, Select a type of data source=System Data Source, 
	  Select a driver=SQL Server, Name=CMS, Server=<db server>, Change the default database to=CMS
	- Choose Web Component Adapter Type, check only IIS ASP.NET
	"

	run "sap/Crystal Reports/Server XI Release 2 SP2/Setup.exe"

	echo.
	echo - Custom, uncheck all except Microsoft_SQL_Server_Wire_Protocol_Driver and Core
	run "sap/Crystal Reports/Data Drivers v5.1/setup.exe"

	echo "Updating icons..."
	$mergeDir "$pp/Business Objects" "$pp/Development/Other"


	echot "\
	- Notes:
	  - Default account: User Name=Administrator, Password=<blank>
	  - Crystal Central Configuration Manager – control Crystal Report Server services
	  - Crystal Import Wizard – import report files
	  - Crystal Central Management Console – manage Crystal Report Server, including add/#ove users, reports, plugins
	"

	return

	:OsLoader
	echot "\
	************************
	* OS Loader 2000
	************************
	- Installation replaced MBR with an MBR Boot Manager
	"

	# Copy install dir
	installDir=$P32/OS Loader 2000
	run "OS Loader 2000/setup"

	# Install OS Loader 2000 in the MBR
	OsLoader setup

	# Register OS Loader 2000
	OsLoader register
		
	echot "\
	- reboot, OS Loader menu
	  - F2(Timer)=5
	  - F3 (Options) 
	    - Check AutoHide Parittions
	    - Uncheck CD-Rom Boot Instructions
	  - Select default partition, ctrl-f2
	- reboot, BIOS: Boot, Hard Disk then CD-ROM
	- reboot, run OsLoader.btm register
	- Notes
	  - Hold down shift, ctrl or alt key during system startup to bypass the boot menu.
	  - OS installation: turn off AutoHide and hide all primary partitions except desired
	"

	return

	:BioShock
	echot "\
	************************
	* BioShock
	************************
	"

	echo Insert the BioShock DVD and run setup...
	pause

	run "2K/BioShock/update/Bioshock Version 1.1 Patch Worldwide Retail.exe"

	echot "\
	Creating Game Jackal profile...
	- Create a Profile
	- Profile name=BioShock
	- Locate title=C:/Program Files/2K Games/BioShock/Builds/Release/Bioshock.exe
	- Exit BioShock
	"
	GameJackal start
	pause


	echot "\
	- Update BioShock.btm with Game Jackal Profile ID
	- Graphics Options
	  - Resolution=1280x768
	  - Adjust Brightness
	- Customize Controls, Use XBox 360 Controller
	"

	return

	:Steam
	echot "\
	************************
	* Steam
	************************
	"

	run "Valve/Steam/SteamInstall.msi"

	echo - close Steam
	pause

	echo Moving data folders...
	$makeLink --merge "$udata/Steam" "$P32/Steam/steamapps"
	$makeLink --merge --hide "$udoc/game/Amnesia" hide "$udoc/Amnesia"

	echo Updating registry...

	# Delete Steam - "C:/Program Files (x86)/Steam/Steam.exe"
	registry 32 delete "HKCU/Software/Microsoft/Windows/CurrentVersion/Run/Steam"

	echo "Updating icons..."
	$mv "$pd/Steam.lnk" "$pp/Games"
	$mergeDir "$pp/Steam" "$pp/Games/Other"
	$mergeDir "$up/Steam" "$pp/Games/Other"

	return


	echo "Updating icons..."
	$mergeDir --rename "$pp/Beyond Compare 3" "$ao/Beyond Compare"
	$mv "$ao/Beyond Compare/Beyond Compare 3 Help.lnk" "$ao/Beyond Compare/Beyond Compare Help.lnk"
	$mv "$ao/Beyond Compare/Beyond Compare 3.lnk" "$ao/Beyond Compare/Beyond Compare.lnk"
	$rm "$ao/Beyond Compare/Uninstall Beyond Compare 3.lnk"
	$rm "$pd/Beyond Compare 3.lnk"


	echo Restoring the default profile...
	BeyondCompare profile restore default

	echo Moving data folder...
	$makeLink --merge --hide "$udata/.jalopy.15" hide "$UserHome/.jalopy.15"

	echot "\
	- Help, Enter Key..., check Register for all users, paste key
	"
	sudo /standard BeyondCompare start
	pause

	return

		:Sandra
	echot "\
	************************
	* Sandra Benchmark
	************************
	"

	run "SiSoftware/Sandra/san1560.exe"

	echo "Updating icons..."
	$mv "$pd/SiSoftware Sandra Lite 2009.SP1.lnk" "$pp/Operating System"
	$mergeDir "$pp/SiSoftware" "$pp/Operating System/Other"


	echot "\
	"

	return

	:Defraggler
	echot "\
	************************
	* Defraggler
	************************
	"

	run "Piriform/Defraggler/dfsetup116.exe"

	echo "Updating icons..."
	$rm "$ud/Defraggler.lnk"
	$mergeDir "$up/Defraggler" "$pp/Operating System/Other"

	return

	:PerfectDisk
	# http://www.raxco.com/products/downloadit/perfectdisk_download.cfm
	# Installation MSI is saved to $P32/Raxco/PD80Install for repairs
	# Services: PD91Agent
	echot "\
	************************
	* PerfectDisk
	************************
	- Do not register or check for updates
	"

	run "Raxco/setup v10.00.114/Install.exe"
	run "Raxco/update/PD10ENp_${architecture}.exe"

	echo Updating services...
	service manual PDAgent

	echo "Updating icons..."
	$mv "$pp/PerfectDisk 10.lnk" "$pp/Operating System"
	$mv "$pp/PerfectDisk 11.lnk" "$pp/Operating System"
	$rm "$pd/PerfectDisk 10.lnk"
	$rm "$pd/PerfectDisk 11.lnk"

	echot "\
	- Select schedule type, none
	- PerfectDisk Settings, 
	  - General, Close button behavior=Exit PerfectDisk
	  - System Resource Priority
	    - CPU Priority=Below normal
	    - Disk I/O, check Monitor and throttle
	"
	PerfectDisk.btm start

	return

	:Mp3tag
	# http://www.mp3tag.de/en/
	echot "\
	************************
	* MP3tag
	************************
	"

	run "Shareware/Mp3Tag/mp3tagv252setup.exe"

	echo "Updating icons..."
	$mv "$pd/Mp3tag.lnk" "$pp/Media"
	$mergeDir "$pp/Mp3tag" "$pp/Media/Other"


	echot "\
	- Add extended columns as needed, i.e. Rating=$rating wmp$
	"

	return

	:FreeClip
	# http://m8software.com/clipboards/freeclip/freeclip.htm
	echot "\
	************************
	* Free Clip
	************************
	"

	run "Shareware/FreeClip/freeclip.exe"

	echo "Updating icons..."
	$rm "$ud/Spartan.lnk"
	$mergeDir "$up/M8 Free Multi Clipboard" "$ao"

	echot "\
	- Tools, Options
	  - Use key=F12
	  - Check Skip "Are you sure" dialog when permanently deleting
	  - Uncheck Sound when new clips are cpatured
	- Notes: F12 to show, click to paste
	"

	return

	:HDHomeRun
	# Updates: http://www.silicondust.com/downloads
	# Instructions: http://www.silicondust.com/support/hdhomerun/instructions/
	# Zap2It: http://tvlistings.zap2it.com/tvlistings/ZCGrid.do?zipcode=87109
	# Lineup: http://www.silicondust.com/hdhomerun/lineup_web/US:87109#lineup_341416
	# Enables: WMC Capture Device Service and Windows Media Center Receiver Service
	echot "\
	************************
	* HDHomeRun Tuner
	************************
	"

	run "SiliconDust/HDHomeRun/setup/hdhomerun_windows_20100609beta1.exe"

	echo "Updating icons..."
	$rm "$pp/Startup/HDHomeRun Manager.lnk"
	$mergeDir "$pp/HDHomeRun" "$pp/Media/Other"
	$mergeDir "$pp/GuideTool" "$pp/Media/Other"
	$mergeDir "$up/GuideTool" "$pp/Media/Other"

	echo Updating tasks...
	SchTasks /Change /Tn "updater.exe" /Disable >& nul:
	SchTasks /Create /RU $@SystemAccount[] /RP * /SC OnIdle /I $SleepTaskIdleTime /TN "sleep" /TR "$@sfn[$pdoc/data/bin/]/tcc.exe /c SleepTaskSleep.btm"

	echot "\
	- Location, Country=United States, Zip/Postal Code=87109
	- Application, Mainn Application=Windows Media Center, Preview Application=Windows Media Player
	- Tuners, Source=Digital Cable
	- Digital Cable, Scan
	  - Zap2It Website, ZIP=87109, provider=Comcast - Digital
	  - View
	    - Check only desired channels
	    - Guide Number=<zap2it channel number (except for digital channels, such as 2.1)>
	    - Guide Name=<zap2it channel name>
	"
	HdHomeRun.btm start
	pause

	echot "\
	- Tasks, Settings, TV
	  - TV Signal, Up TV Signal
		- Guide, Edit Channels, Show Preview, check desired unlocked (unencrypted) channels
	    - Note: scroll with page and arrow up/down
	- TV, guide, click each channel (2nd column), Edit Channel
	  - Find the channel in zap2it by comparing:
	    - WMC channel number with HDHomeRun Setup Tune / Guide Number / GuideName
	    - current program in the preview with zap2it current program
		- Channel number=<zap2it channel number (except for digital channels, such as 2.1)>
	  - Rename, name=<zap2it channel name>
		- Edit Listings
	    - type first few letters of channel name (i.e. kasa)
	    - select correct listing (validate current listing with program in the preview)
	    - validate 
	  - Recorder, Recorder Storage, Record on drive=D:
	"
	WindowsMediaCenter.btm start
	pause

	return

	:ExtensionColumn
	echot "\
	************************
	* Extension Column
	************************
	"

	if defined NewOs return 1

	FindExe "Shareware/Extension Column/setup ${architecture}"
	if $_? != 0 return $_?

	echo Right click on CPExt.info and select Install
	explorer.btm "$exe"
	pause

	registry import "$ExeDir/setup.reg"

	echot "\
	- Columns, More..., check Ext
	- Columns: Name, Size, Ext, Type, Data Modified
	- Tools, Folder Options, View, Apply to All Folders
	" 
	explorer.btm restart
	explorer.btm c:/
	pause

	return

	:MceStandbyTool
	# download: http://slicksolutions.eu/mst.shtml
	# windows 7: http://www.degroeneknop.nl/forum/index.php/topic,4989.0/all.html
	echot "\
	************************
	* MCE Standby Tool
	************************
	"

	run "Shareware/MCE Standby Tool/setup/mst09098.exe"

	echo Updating registry...

	# Delete MCE Standby Tool - "C:/Program Files (x86)/MCE Standby Tool/mst.exe" engine
	registry 32 delete "HKLM/SOFTWARE/Microsoft/Windows/CurrentVersion/Run/MCE Standby Tool"

	echot "\
	- Reboot, check Do not force reboots
	- USB, Unacheck Disable selective USB suspend 
	"

	return

	:QualityCenter
	echot "\
	************************
	* Quality Center
	************************
	"

	run "Hewlett Packard/Quality Center/QCExplorerAddIn.exe"

	echo "Updating icons..."
	$mergeDir "$pp/Quality Center" "$ao"
	CopyFile "$ao/Quality Center/QCExplorer.lnk" "$pp/Applications/QualityCenter.lnk"

	echo Address=http://qualitycenterrr.intel.com:8080/qcbin/start_a.htm

	return

	:Foglight
	echot "\
	************************
	* Foglight
	************************
	"

	run "Quest Software/Foglight/setup/setup.exe"

	echo "Updating icons..."
	$mergeDir "$pp/Quest Software" "$pp/Operating System/Other"
	$mv "$pd/4.2 Foglight Operations Console.lnk" "$pp/Operating System/Foglight.lnk"

	return

	:Easy2Sync
	# download: http://www.easy2sync.com/en/produkte/e2s4o_down_ex.php
	# archive: http://www.easy2sync.com/en/produkte/e2s4o_down_ver.php
	echot "\
	************************
	* Easy2Sync
	************************
	- Close Easy2Sync
	"

	run "ITSTH/Easy2Sync/Easy2Sync Business v4.00.exe"

	echo Restoring the default profile...
	Easy2Sync.btm profile restore default

	echo "Updating icons..."
	$mergeDir "$pp/Easy2Sync for Outlook" "$ao"

	echot "\
	- Tools, Options, Confirm when, check When syncronizing a task for the first time, enable ALL confirmations
	- New..., New Task...
	  - What=Syncronize (Calendar Copy Intel to Wiggin)
	  - Which Date=Contacts, (optional) Contacts, Notes, Tasks
	  - With what=Local file or shared file in the local network
	    - Search manually
	    - Select PST file=//oversoul/John/Documents/data/mail/home.pst
			- Select Contacts|Calendar|Notes|Tasks
	  - Ready to sync!
	    - This task will be saved as=contacts|calendar|contacts|notes|tasks
		  - Uncheck Start synchronizing when I click on "Finish".
	  - Select task, Edit..., 
	    - Data storages, Choose data storage...
	      - Data storage 1|2, Passwords, Icons, Shortname..., Computer name=Intel|Wiggin
	"
	pause

	echo Saving profile changes...
	Easy2Sync.btm profile backup

	return

	:WindowsLiveEssentials
	:WindowsLive
	:wle
	# http://download.live.com
	# Includes: Messenger, Mail, PhotoGallery, Toolbar, Writer, Family Safety, Add-In
	echot "\
	************************
	* Windows Live Essentials
	************************
	- Check Photo Gallery, Live Write
	- (optional) Check other application as needed
	"

	run "Microsoft/Live/wlsetup-web.exe"

	echo Moving data folder...
	$makeLink --merge --hide "$udata/Live Writer" hide "$udoc/My Weblog Posts"

	echo "Updating icons..."
	$mergeDir "$pp/Windows Live" "$ao"
	$mv "$pp/Windows Live ID.lnk" "$pp/Applications"
	$mv "$pd/Windows Live Messenger.lnk" "$ao/Windows Live"
	$mv "$pp/Windows Live Movie Maker.lnk" "$ao/Windows Live"
	$mv "$pp/Windows Live Photo Gallery.lnk" "$ao/Windows Live"

	return

	:radioSHARK
	echot "\
	************************
	* radioSHARK
	************************
	"

	run "Grifin Technology/radioSHARK/radioSHARK_v2.1.exe"

	echo Restoring the default profile...
	radioSHARK.btm profile restore default

	echo "Updating icons..."
	$mergeDir "$pp/Grifin Technology" "$ao"
	$rm "$up/Startup/radio SHARK Scheduler.lnk"

	echo - Recording, Show Disabled Devices, radioSHARK, Enable
	os.btm sound
	pause

	echot "\
	- Configuration
	  - Record & Playback, Quality=Best
	  - Startup, uncheck Check for updates at startup and Stay in Systray on close
	"
	radioSHARK.btm start
	pause

	return

	:Airfoil
	echot "\
	************************
	* Airfoil
	************************
	"

	echo DO NOT INSTALL - causes programs to launch in a suspended state
	return 0

	run "Rogue Amoeba/Airfoil/Airfoil v2.7.5.exe"

	echo "Updating icons..."
	$mergeDir "$pp/Grifin Technology" "$ao"

	if "$@domain[]" != "" then
		echo - Inbound Rules, Airofoil and Airfoil speakers, Advanced, check Domain (4 rules
		firewall console
		pause
	fi

	echo "Updating icons..."
	$rm "$pd/Airfoil.lnk"
	$rm "$pd/Airfoil Speakers.lnk"
	$mergeDir "$pp/Airfoil" "$pp/Media/Other"

	echot "\
	- Interface, check Show Airfoil icon in system tray and Minimize Airfoil to system tray
	- Startup, Automatically transmit to, check all
	"
	AirFoil.btm start

	return

	:ProtectorSuite
	# Does not allow individual component installation, and password component nags to buy full version
	echot "\
	************************
	* Protector Suite
	************************
	"

	run "UPEK/Protector Suite for Windows 7 Build 5668 x86/setup.msi"

	echo "Updating icons..."
	$mergeDir "$pp/Protector Suite" "$pp/Operating System/Other"

	return

	:SoundSpectrumNotes

	echot "\
	- Notes
	  - WMP: ~10$ CPU utilization, 32bit only, not all shortcut keys function
	  - iTunes: ~30$ CPU utilization
	- Shortcuts
		- Information
			- [shfit] h=documentation/help
			- [shift] t=[auto] trackinfo
			- l=list current configs
			- r=frame rate
		- Other
			- /=hide console
	    - u=reload and recreate current config
			- v=verbose
			- escape/shift return=full screen	
			- m=full screen resolution
			- `=snapshot
			- -+/[]=music response/preamp
			- qwe/asd/zxc=prev/next/slideshow ColorScheme/Background/WaveShape
			- f/g=slideshows off/on
			- 1,2,...=preset
	"

	return

	:Aeon
	# http://www.soundspectrum.com/aeon/download.html
	# http://www.soundspectrum.com/support/download_products.html
	# http://www.soundspectrum.com/aeon/Documentation/version-history.html
	echot "\
	************************
	* Aeon
	************************
	"

	run SoundSpectrum/Aeon/Aeon_101_Platinum.exe

	echo "Updating icons..."
	$mergeDir "$pp/Aeon" "$pp/Media/Other"

	SoundSpectrumNotes

	return

	:WhiteCap
	# http://www.soundspectrum.com/whitecap/Documentation/version-history.html
	# http://www.soundspectrum.com/support/download_products.html
	echot "\
	************************
	* WhiteCap
	************************
	"

	run SoundSpectrum/WhiteCap/WhiteCap_571_Platinum.exe

	echo "Updating icons..."
	$mergeDir "$pp/WhiteCap" "$pp/Media/Other"
	$rm "$pp/Media/Other/WhiteCap/SoundSpectrum Website.url"

	SoundSpectrumNotes

	return

	:LogParser
	echot "\
	************************
	* Log Parser
	************************
	"

	run "Microsoft/Log Parser/setup/LogParser.msi"
	run "Microsoft/Log Parser/setup/logparserlizardsetup.msi"

	echo "Updating icons..."
	$mergeDir "$pp/Log Parser 2.2" "$pp/Development/Other"
	$mergeDir "$up/Log Parser Lizard" "$pp/Development/Other"

	return

	:Saba
	echot "\
	************************
	* Saba
	************************
	"

	saba.btm install all

	return

	:DesktopGadgets
	echot "\
	***************************
	* Windows Desktop Gadgets
	***************************
	"

	d=Microsoft/Windows/gadgets/setup

	if $@IsIntelHost[] == 1 then
		for file in ($SharedDocuments/data/install/Intel/gadgets/*.gadget) run "$file"
	fi

	pause

	echot "\
	- Gadgets, Clock, Weather
	"
	os.btm gadget show
	pause

	return

	:HttpWatch
	# http://www.httpwatch.com/download/
	echot "\
	************************
	* HttpWatch
	************************
	"

	run "Simtec/httpwatch.exe"

	echo "Updating icons..."
	$mergeDir "$pp/HttpWatch Basic Edition" "$pp/Development/Other"

	return

	:Fiddler
	# http://www.fiddler2.com/fiddler2/
	echot "\
	************************
	* Fiddler
	************************
	"

	# run "Shareware/Fiddler/Fiddler 2 Setup v2.3.6.4.exe"
	run "Shareware/Fiddler/Fiddler4BetaSetup.exe"
	run "Shareware/Fiddler/FiddlerSyntaxSetup.exe"

	echo Moving data folder...
	$makeLink --merge --hide "$udata/Fiddler2" hide "$udoc/Fiddler2"

	echo "Updating icons..."
	$makeDir "$pp/Development/Fiddler/Other"
	$mv "$pp/Fiddler2.lnk" "$pp/Development/Other/Fiddler"
	$mv "$up/Fiddler2 ScriptEditor.lnk" "$pp/Development/Other/Fiddler"

	return

	:NirSoftLauncher
	# http://blog.nirsoft.net/2009/08/15/nirsoft-launcher-is-in-development-process/
	echot "\
	************************
	* NirSoftLauncher
	************************
	"

	installDir=$pdoc/programs/NirSoft Launcher
	run "Shareware/NirSoft/NirSoft Launcher v1.00 beta.7z"

	$makeShortcut "$pdoc/programs/NirSoft Launcher/NirLauncher.exe" "$pp/Operating System/NirSoft Launcher.lnk"

	return

	:LiberKey
	# http://www.liberkey.com/en/
	echot "\
	************************
	* LiberKey
	************************
	"

	installDir=$pdoc/programs/LiberKey
	run "Shareware/LiberKey/LiberKey v4.5.zip"

	$makeShortcut "$pdoc/programs/LiberKey/LiberKey.exe" "$pp/Applications/LiberKey.lnk"

	return

	:Defraggler
	echot "\
	************************
	* Defraggler
	************************
	"

	run "Shareware/Defraggler/dfsetup115.exe"

	echo "Updating icons..."
	$mergeDir "$up/Defraggler" "$pp/Operating System/Other"
	$mv "$pd/Defraggler.lnk" "$pp/Operating System"

	return

	:MyDefrag
	echot "\
	************************
	* MyDefrag
	************************
	"

	echo - #ove previous versions
	os.btm programs
	pause

	version=4.2.7
	run "Shareware/MyDefrag/setup/MyDefrag-v$version.exe"

	echo "Updating icons..."
	$mergeDir "$pp/MyDefrag v$version" "$pp/Operating System/Other"
	$mv "$pd/MyDefrag.lnk" "$pp/Operating System"
	return

	:Gears
	echot "\
	************************
	* Gears
	************************
	"
	run "Google/Gears/GearsSetup.exe"
	return

	:WindowsDriverKit
	echot "\
	************************
	* Windows Driver Kit
	************************
	- Check Full Development Environment
	- Install Path=$code/WinDDK/7600.16385.0/
	"

	run "Microsoft/Windows/Driver Kit/en_windows_driver_kit_for_windows_7_and_windows_server_2008_r2_x86_x64_ia64_dvd_400380.iso"

	echo "Updating icons..."
	$mergeDir "$pp/Windows Driver Kits" "$pp/Development/Other"

	return

	:Smilebox
	echot "\
	************************
	* Smilebox
	************************
	"

	run "Smilebox/SmileboxInstaller.exe"

	echo Moving data folder...
	$makeLink --merge --hide "$udata/Smilebox" hide "$udoc/My Smilebox Creations"

	echo Updating registry...

	# Delete SmileboxTray - "C:/Users/jjbutare/AppData/Roaming/Smilebox/SmileboxTray.exe"
	registry delete "HKCU/SOFTWARE/Microsoft/Windows/CurrentVersion/Run/SmileboxTray"

	echo "Updating icons..."
	$rm "$ud/Smilebox.lnk"
	$mv "$up/Smilebox.lnk" "$pp/Applications"

	return

	:ImageMagick
	# - download http://www.imagemagick.org/script/binary-releases.php#windows
	# Graphic editing with command line and COM interfaces
	echot "\
	************************
	* ImageMagick
	************************
	- Check ImageMagickObject OLE Control
	"

	run "shareware/ImageMagick/setup/ImageMagick-6.7.3-7-Q16-windows-${architecture}-static.exe"

	echo "Updating icons..."
	$rm "$ud/ImageMagick Display.lnk"
	$mergeDir --rename "$pp/ImageMagick 6.7.3 Q16" "$pp/Media/Other/ImageMagick"

	return

	:SubsystemForUnix
	:sfu
	:sua
	# - Utilities and SDK: http://www.microsoft.com/downloads/en/details.aspx?FamilyID=dc03485b-629b-49a6-b5ef-18617d1a9804
	# - SUA packages: http://www.suacommunity.com/SUA.aspx#bundles (download the complete toolset) 
	# - SUA Tools: http://www.suacommunity.com/tool_warehouse.htm or ftp://ftp.interopsystems.com
	# - Xming:   http://www.straightrunning.com/candidate/
	# - Xming Fonts: http://sourceforge.net/projects/xming/files/Xming-fonts/7.5.0.25/Xming-fonts-7-5-0-25-setup.exe/download
	echot "\
	******************************
	* Microsoft Subsystem for Unix
	******************************
	"

	# Initialize
	p=Microsoft/Unix

	# Core
	os.btm optional
	echo - Check Subsystem for UNIX-based Applications
	pause

	ask "Minimal installation?" n
	if $? == 1 then
		run "$p/tools/bash-current.exe"
	else
		SubsystemForUnixFull
	fi

	echo Installing tools....
	run "$p/tools/tkman-current.exe"

	echo Updating registry...
	registry import "$install/$p/other/setup.reg"

	echo "Updating icons..."
	$mv.btm "$ud/XLaunch.lnk" "$pp/Operating System"
	$mv.btm "$ud/XMing.lnk" "$pp/Operating System"
	MergeDir.btm /q "$pp/Subsystem for UNIX-based Applications" "$pp/Operating System/Other"
	MergeDir.btm /q "$pp/Xming" "$pp/Operating System/Other"

	if "$UserSysHome" != "$UserHome" then
		echo Updating user home directory...	
		echo - paste clipboard contents after if [ "$HOME" != "" ]; then
		echo $@ClipW[export HOME=/dev/fs/D/Users/$(whoami)] >& nul:
		TextEdit "$WinDir/SUA/etc/homedir.conf" "$WinDir/SUA/etc/profile"
		pause
	fi

	return

	:SubsystemForUnixFull
	:SfuFull

	# Initialize
	p=Microsoft/Unix

	# SDK
	echot "\
	Installing utilities and SDK...
	- Custom Install
	  - Check Base Utilities, Base SDK, GNU Utilities, and GNU SDK
	- Security Settings, check all
	"
	run "$p/SDK/${architecture}/setup.exe"

	# Tool bundle - x86 package is more complete and contains additional packages
	echot "\
	Installing SUA community add-on tool bundles...
	- Do not install X server
	"
	run "$p/packages/pkg-current-bundlecomplete60x64.exe"
	run "$p/packages/pkg-current-bundlecomplete60x86.exe"

	# Additional tools
	echo Installing tools....
	run "$p/tools/tkman-current.exe"

	# X Server
	echot "\
	Installing X Window components...
	- Standard PuTTY Link SSH client - use with orginal PuTTY
	"
	run "UNIX/Xming/Xming-7-5-0-29-setup.exe"
	echo - Check all fonts
	run "UNIX/Xming/Xming-fonts-7-5-0-25-setup.exe"

	return
	


	return

	:Pandora
	echot "\
	************************
	* Pandora
	************************
	"

	if "$@assoc[.air]" == "" AdobeAir

	run "Pandora/pandora_2_0_5.air"
	run "Microsoft/Windows/gadgets/setup/PandoraOther.gadget"

	echo "Updating icons..."
	$rm "$pd/Pandora.lnk"
	$mv "$pp/Pandora.lnk" "$pp/Media"

	return
	
	:VirtualBox
	# http://www.virtualbox.org/
	echot "\
	************************
	* VirtualBox
	************************
	"

	run "Sun/VirtualBox/setup/VirtualBox-3.1.2-56127-Win.exe"

	echo "Updating icons..."
	MergeDir.btm /q "$pp/Sun VirtualBox" "$pp/Operating System/Other"
	$rm.btm "$pd/Sun VirtualBox.lnk"

	$makeDir.btm "$udata/VirtualBox"

	echot "\
	- File, Preferences...
	  - General, Default Folders=Documents/data/VirtualBox
	"

	return

	MotionPictureBrowser

	:PlayMemoryies
	:Pictu#otionBrowser
	:pmb
	# Installs: the autorun program and service are used for device recognition .
	#    Leave them enabled during initial recognition and setup, and then disable as don't currently
	#    use value added import for DSC-HX5V (GPS added to video moff/modd metadata files), and can run import manually from PMB Launcher
	echot "\
	*****************************
	* Sony Motion Picture Browser
	*****************************
	- Install, uncheck Restart Now
	- Connect a Sony product and a Blu-ray burner, when prompted install special features
	"

	# PMB must be installed from ISO image, otherwise setup fails
	run "Sony/Play Memories/setup/PMH_Upgrade1209a.exe"

	echo Moving data folders...
	$makeLink --merge --hide "$udata/Sony PMB" hide "$udoc/Sony PMB"

	echo Updating registry...

	# Delete PMBVolumeWatcher - C:/Program Files (x86)/Sony/PMB/PMBVolumeWatcher.exe
	registry 32 delete "HKLM/SOFTWARE/Microsoft/Windows/CurrentVersion/Run/PMBVolumeWatcher"

	echo Updating services...

	# pmbdeviceinfoprovider to manual
	service manual pmbdeviceinfoprovider

	echo "Updating icons..."
	MergeDir.btm /q "$pp/PlayMemories Home" "$pp/Media/Other"
	$rm.btm "$pd/PlayMemories Home.lnk"
	$rm.btm "$pd/PlayMemories Home Help.lnk"
	$rm.btm "$pp/PlayMemories Home.lnk"

	echot "\
	- Connect Sony devices to get dialog to add addition features
	  - HDR-12 video camera to recognize video
	"
	Pictu#otionBrowser service start
	pause

	echot "\
	- Tools, Settings..., 
	  - Add Folders, My Pictures, My Videos, Public Pictures and Public Videos	
	- Share Publicly, Check for new Sharing Services...
	"
	Pictu#otionBrowser start
	pause

	return

	:PDFZilla
	echot "\
	****************************
	* PDFZilla - PDF to Word
	****************************
	- Where should PDFZilla be installed=<paste>
	"

	echo $@ClipW[$P32/PDFZilla] >& nul:
	run "Shareware/PDFZilla/setup v1.2.9.exe"

	echo "Updating icons..."
	$rm "$pd/PDFZilla.lnk"
	$mergeDir "$pp/PDFZilla" "$ao"

	echot "\
	- Please Enter the Registration Code=8061822TWDV6YUK
	- PDF To Word Converter, Output Folder=Downloads
	"

	return
	
	:calibre
	# Download - http://calibre-ebook.com/download
	#   Windows - http://calibre-ebook.com/download_windows
	#   All - https://dev.mobileread.com/dist/kovid/calibre/
	echot "\
	************************
	* Calibre Reader
	************************
	- Advanced, uncheck Add install directory to path
	"

	run "Shareware/Calibre/setup/calibre-0.9.38.msi"

	echo "Updating icons..."
	$mv "$pd/calibre - E-book management.lnk" "$pp/Applications"
	$mergeDiruiet "$pp/calibre - E-book Management" "$ao"

	echot "\
	- choose a location for your books=Documents/data/books or cloud:/data/books
	- Manufacturers=Amazon, Devices=Kindle PaperWhite
	- E-Book Viewer, Configure, General, Page Flip options, Page flip duration=0 secs
	- Notes: 
	  - Organizes library folders by <author>/<book> on import or metadata change
	  - Search uses regular expressions: not mobi and not pdf and not azw
	  - Import content from the download directory using the Add books button (content
	    is copied to the ebook location) 
	"

	return

	:calibre2opds
	# http://calibre2opds.com/downloads/
	echot "\
	************************
	* calibre2opds
	************************
	"

	installDir=$P/calibre2opds
	run "Shareware/calibre2opds/setup/calibre2opds-3.1-170M.zip"

	echo "Updating icons..."
	XxMkLink /q "$pp/Media/OPDS Catalog Generator.lnk" cmd "/c /"$P/calibre2opds/rungui.cmd/"" "$P/calibre2opds" "" 7

	return


	:SecurityEssentials
	:mse
	# download: http://www.microsoft.com/security_essentials/
	# EMET download: http://blogs.technet.com/b/srd/, http://www.microsoft.com/download/en/details.aspx?id=1677
	# notes: scans for malware - virus (new) and spyware (replaces Windows Defender)
	echot "\
	************************************
	* Microsoft Security Essentials
	************************************
	"

	run "Microsoft/security/essentials/mse v4.2.223.1 ${architecture}.exe"
	run "Microsoft/security/EMET/EMET Setup.msi"

	echo "Updating icons..."
	$rm "$pd/Microsoft Security Essentials.lnk"
	$mv "$pp/Microsoft Security Essentials.lnk" "$pp/Operating System/Security Essentials.lnk"
	$mergeDir "$up/Enhanced Mitigation Experience Toolkit" "$pp/Operating System/Other"

	# Real time monitoring increases  bin/*.exe file copy time 50x (1s->50s) 
	echot "\
	Optionally disable components which significantly degrade system performance...
	- Settings
	  - Scheduled scan, uncheck Run a schedule scan on my computer
	  - Real-time protection, uncheck Monitor file and program activity on your computer
	"
	os.btm SecurityEssentials
	pause
		
	echo - Action Center, Change Action Center settings, Turn on/off Spyware and related protection and Virus protection
	os.btm ControlPanel
	pause

	return

	# Omron blood pressure monitor health management software
	:Omron
	echot "\
	************************
	* Omron
	************************
	- Prefix installation directory with c:/Program Files
	"

	run "Omron/HEM-790IT/setup/setup.exe"

	echo "Updating icons..."
	$rm "$ud/Omron Health Management Software Users Manual.pdf.lnk"
	$rm "$ud/Omron Health Management Software.lnk"
	$mergeDir "$up/Omron Health Management Software" "$ao"

	return

	:Comcast
	echot "\
	************************
	* Comcast Applications
	************************
	- ComcastAccess: non-intrusive DRM, works with Win7 x64, allows 3 computers to play Fancast xfinity content
	"

	run "Comcast/ComcastAccessInstaller.exe"

	echo "Updating icons..."
	$mv "$pp/ComcastAccess.lnk" "$pp/Media"

	return

	:HandBrake
	echot "\
	************************
	* HandBrake
	************************
	"

	run "Shareware/HandBrake/setup/HandBrake-0.9.4-Win_GUI.exe"

	echo "Updating icons..."
	$rm "$ud/Handbrake.lnk"
	$mergeDir "$pp/Handbrake" "$pp/Media/other"
	$rmd /q "$up/Handbrake"

	echo Restoring the default profile...
	HandBrake profile restore default

	echot "\
	- Tools, Options, 
	  - Default Path=D:/Users/jjbutare/Videos/converted
	"

	return

	:TouchPack
	echot "\
	************************
	* Touch Pack
	************************
	"

	run "Microsoft/Windows/touch/touch-pack-web.exe"

	echo "Updating icons..."
	$rm "$pp/Bing Maps 3D.lnk"
	$mergeDir --rename "$pp/Microsoft Touch Pack for Windows 7" "$ao/Touch Pack"
	$mv "$pd/Bing Maps 3D.lnk" "$ao/Touch Pack"
	return

	:MediaCoder
	# - Updates: http://www.mediacoderhq.com/
	# - Codecs
	#   - http://www1.mplayerhq.hu/MPlayer/releases/codecs/windows-essential-20071007.zip
	#   - http://xulplayer.googlecode.com/files/avisynth-20100223.7z 
	#   - http://d10xg45o6p6dbl.cloudfront.net/projects/m/mediacoder/lossless_audio_encoders_20090814.7z 
	# - XUL Player: http://xulplayer.sourceforge.net/xulplayer-bin.7z
	echot "\
	************************
	* MediaCoder
	************************
	"

	run "Shareware/MediaCoder/setup/MediaCoder v2011 build 5025 ${architecture}.exe"

	ask "Install additional codecs (AVI support)?` n
	if $? == 1 unzip.exe -o -j -e "$ExeDir/../codecs/windows-essential-20071007.zip" -d "$P/MediaCoder/codecs"

	echo "Updating icons..."
	$rm "$ud/MediaCoder x64.lnk"
	$mergeDir "$up/MediaCoder x64" "$pp/Media/other"

	echot "\
	- Config Wizard
	  - Advanced Mode
	  - Do you want to enable multi-threaded decoding? Enable
	  - Do you want to the output video resolution? No
	  - How do you want to deal with the aspect ratio? I want to keep the original picture proportion. 
	  - Do you want to adjust the video frame rate? No
	  - Which format do you want to convert to? H.264 / AVC
	  - Which bitrate mode do you want to use for video encoding? Variable Bitrate, High Quality
	  - Which container format do you want to use? MP4
	  - Which audio format do you want to encode to? AAC
	  - Do you want to adjust the audio sample rate? No
	  - Do you want to adjust the audio channels? No
	- Notes:
	  - Test playback with mplayer, install additional codecs if needed:
	    "$P/MediaCoder/codecs/mplayer.exe" //oversoul/john/Desktop/1994_02_12.wmv
	  - Average bitrates: SVHS video=3000, DV=4000
	  - Profiles in Cloud/data/MediaCoder
	"

	return

	:AviDemux
	# http://avidemux.berlios.de/download.html
	echot "\
	************************
	* AviDemux
	************************
	- Select the type of install=Full, uncheck Additional Languages
	"

	run "Shareware/Avidemux/avidemux_2.5.4_win.exe"

	echo "Updating icons..."
	$mv "$pd/Avidemux 2.5.lnk" "$pp/Media"
	$mergeDir "$pp/Avidemux" "$pp/Media/Other"

	return

	:SonyVegas
	:vegas
	# http://www.sonycreativesoftware.com/download/updates/moviestudiope
	# http://www.sonycreativesoftware.com/download/updates/dvdastudio
	echot "\
	**************************
	* Sony Vegas Movie Studio
	**************************
	"

	run "Sony/Vegas/setup/moviestudiope11.0.283.exe"
	run "Sony/Vegas/setup/dvdarchitectstudio5.0.157.exe"

	echo "Updating icons..."
	as=$pp/Media/Other/Sony/DVD Architect Studio
	vms=$pp/Media/Other/Sony/Vegas Movie Studio
	$mergeDir "$pp/Sony" "$pp/Media/Other"
	$mergeDir --rename "$pp/Media/Other/Sony/Vegas Movie Studio HD Platinum 11.0" "$vms"
	$mergeDir --rename "$pp/Media/Other/Sony/DVD Architect Studio 5.0" "$as"
	$mv "$vms/Vegas Movie Studio HD Platinum 11.0.lnk" "$vms/Vegas Movie Studio.lnk"
	$mv "$as/DVD Architect Studio 5.0.lnk" "$as/DVD Architect Studio.lnk"
	$rm "$vms/Vegas Movie Studio HD Platinum 11.0 Readme.lnk"
	$rm "$vms/Video Capture 6.0 Readme.lnk"
	$rm "$as/DVD Architect Studio 5.0 Readme.lnk"

	echo Moving data folders...
	$makeDir "$udata/DVD Architect Studio"
	$makeLink --merge --hide "$udata/Vegas" hide "$udoc/Vegas Movie Studio HD Platinum 11.0 Projects"

	echot "\
	- Vegas Movie Studio, Options, shift click Preferences..., 
	  - General, Temporary files folder=d:/temp
	  - Internal
	    - path, all c: paths to D:/Users/jjbutare/Documents/data/Vegas/temp/NNN
	    - threads, Maximum Video Render Threads=8, Max for Maximum Video Render Threads=12 
	- DVD Archtiect Studio
	  - File, Properties...
	    - Aspect ratio=16:9
	    - Check Start all new projects with these settings
	  - Options, Preferences
	    - General, uncheck Show logo splash screen on startup
			- Preview, Aspect ratio=16:9
			- Burning
				- Default  prepare folder=$udata/DVD Architect Studio
				- Temporary files folder=d:/temp
	"
	pause

	return

	:Eraser
	# http://eraser.heidi.ie/
	echot "\
	************************
	* Eraser
	************************
	"

	run "Shareware/Eraser/Eraser 6.0.8.2273.exe"

	echo "Updating icons..."
	$rm "$pd/(prog).lnk"
	$mv "$pd/(prog).lnk" "$pp/Applications"
	$mergeDir "$pp/(dir)" "$ao"

	return

	:InternetDownloadAccelerator
	:IDA
	echot "\
	********************************
	* Internet Download Accelerator
	********************************
	"

	run "WestByte/Internet Download Accelerator/IDA v5.10.1.1269.exe"

	echo "Updating icons..."
	$rm "$ud/Internet Download Accelerator.lnk"
	$rm "$ud/Play!.lnk                        "
	$mergeDir "$pp/Internet Download Accelerator" "$pp/Operating System/Other"

	echo Updating registry...

	# Delete Internet Download Accelerator - C:/Program Files (x86)/IDA/ida.exe -autorun
	registry delete "HKCU/SOFTWARE/Microsoft/Windows/CurrentVersion/Run/Internet Download Accelerator"

	echo Uninstall Firefox IDA plugins...
	firefox start
	pause

	echo $@ClipW[$udata/download] >& nul:
	echot "\
	- Tools, Options
	  - General, uncheck Minimize to tray when closing
	  - Downloads
	    - Current folder for saving files=<paste>
	    - Download folder detection type=Do not use
	  - User Interface
	    - Uncheck Show splash screen while starting
	    - Uncheck Always open "Add download" window when adding new download
	    - Events, Unmark on=selection of the download
	  - Other
	    - MyTopFiles setting, check Disable sending link info to the service
	    - Uncheck Get news on popular files
	"
	ida
	pause

	return

	:UltraVNC
	# Installs: uvnc_service, mv2.sys driver
	echot "\
	************************
	* UltraVNC
	************************
	- Select Additional Tasks
	  - Check Register UltraVNC Server as a system service (for Ctrl-Alt-Delete handling)
	  - Check Create UltraVNC desktop icons
	  - Check Associate UltraVNC Viewer with the .vnc file extension
	  - Check UltraVNC Server driver install  
	"

	run "UltraVNC/setup/UltraVNC_1.0.9.5_${architecture}_Setup.exe"

	echo "Updating icons..."
	$rm "$ud/UltraVNC Server.lnk"
	$rm "$ud/UltraVNC Viewer.lnk"
	$mergeDir "$pp/UltraVNC" "$pp/Operating System/Other"

	echot "\
	- Security, VNC Password=NNN
	- Screen Capture
	  - Check Low Accuracy
	  - Check Use system hookdll
	  - Check Use mirror driver and Show Primary Display
	  - Check Capture Alpha-Beldning
	  - Check #ove Aero while connected
	  - Check #ove Wallpaper while connected
	"
	UltraVNC config
	pause

	echot "\
	- Admin Properties
	  - Check Allow Loopback Conenctions
	  - Uncheck Loopback Only
	"
	UltraVNC server
	pause

	return

	:LinkShellExtension
	echot "\
	************************
	* Link Shell Extension
	************************
	"

	run "Shareware/Link/setup/HardLinkShellExt_${architecture}.exe"

	echo "Updating icons..."
	$mergeDir "$pp/Link Shell Extension" "$pp/Operating System/Other"
	$mergeDir "$up/Link Shell Extension" "$pp/Operating System/Other"

	echo Enabling icon overlays...
	echo - Icon, HardLink, Priority for overlay icon=1
	"$P/LinkShellExtension/LSEConfig.exe"
	pause 
	echo - Icon, HardLink, Priority for overlay icon=-
	"$P/LinkShellExtension/LSEConfig.exe"
	pause

	return

	:miro
	echot "\
	************************
	* Miro
	************************
	"

	run "Shareware/Miro/Miro_Installer.exe"

	echo "Updating icons..."
	$rm "$pd/Miro.lnk"
	$mergeDir "$pp/Miro" "$pp/Media/Other"

	return

	:PSI
	# http://secunia.com/vulnerability_scanning/personal/
	echot "\
	************************************************
	* Secuina PSI - Personal Software Inspector
	************************************************
	- Uncheck Enable Auto-Updates
	"

	run "Secunia/PSI/PSISetup.exe"

	echo "Updating icons..."
	$mv "$pp/Secunia PSI.lnk" "$pp/Operating System"

	echot "\
	- Configuration, Settings, uncheck all except Show detailed program changes
	"
	psi
	pause

	return

	:LinkSysBluetooth
	# HKLM/Microsoft/Windows/CurrentVersion/Run/BluetoothAuthenticationAgent, c:/windows/system32/bthprops.cpl, is required to store Bluetooth link keys
	# #oval requires manual deletion of services: btaudio, BTDriver, BTWDNDIS, BTWUSB
	echot "\
	*****************************
	* LinkSys Bluetooth Software
	*****************************
	"

	run "Linksys/Bluetooth USB Adapter USBBT100/Driver V1.05/setup.exe"

	# Hide desktop icon
	registry 32 "HKCU/Software/Microsoft/Windows/CurrentVersion/Explorer/HideDesktopIcons/NewStartPanel/{6AF09EC9-B429-11D4-A1FB-0090960218CB}" REG_DWORD 1

	echo "Updating icons..."
	$rm "$pp/My Bluetooth Places.lnk"
	$rm "$pp/../My Bluetooth Places.lnk"
	$rm "$pp/Startup/BTTray.lnk"
	$mergeDir "$pp/Accessories" "$pp/Applications/Accessories"

	echo Update driver...
	RunProg devmgmt.msc
	echo - Bluetooth Radios, Generic Bluetooth Radio, Update Driver..., No, Advanced, Don't search, Linksys Bluetooth USB Adapter

	return

	:BroadcomBluetooth [update]
	# http://www.broadcom.com/support/bluetooth/update.php
	# Path: $P/WIDCOMM/Bluetooth Software and $P/WIDCOMM/Bluetooth Software/syswow64
	echot "\
	*****************************
	* Broadcom Bluetooth Software
	*****************************
	"

	# Run the setup that downloads the correct installer to ensure the correct licensing for the Bluetooth device is used.
	# Only run if update is true for cases where vendor specific driver is used.  Using the Broadcom software directly
	# can cause some errors with some systems and  devices (such as Lenovo laptops and Voyager PRO+)
	if "$update" != "false" run "Broadcom/Widcomm/Setup Download v6.5.1.2300.exe"

	echo "Updating icons..."
	$rm "$pp/Startup/Bluetooth.lnk"
	$mv "$pd/Bluetooth Problem Report.lnk" "$pp/Operating System"
	$mv "$pp/Bluetooth Problem Report.lnk" "$pp/Operating System"
	$mergeDir "$pp/Accessories" "$pp/Applications"
	$mergeDir "$up/Bluetooth Devices" "$pp/Operating System"
	$rmd /q "$udoc/Bluetooth Exchange Folder"

	echot "\
	- Options
	  - Check Allow Bluetooth devices to find this computer
	  - Check Allow Bluetooth device to connect to this computer
	  - Check Show the Bluetooth icon in the notification area
	- Share, Bluetooth Exchange Folder location=Downloads
	"
	os bluetooth properties
	pause

	return

	:IoGearBluetooth
	# Required for Plantronics Voyager Headset, Microsoft drivers are sufficient for Bluetooth keyboard and mouse decvices
	# http://www.iogear.com/support/dm/driver/GBU321#display
	echot "\
	*****************************
	* IOGear Bluetooth Software
	*****************************
	"

	# Instal the base  Bluetooth driver from IOGear to get the correct license then update the driver from Broadcom
	run "IOGear/BlueTooth Adapter GBU2210-321/setup/setup v6.2.1.500.exe"
	BroadcomBluetooth

	return

	:Growl
	# http://www.growlforwindows.com/gfw/
	# http://code.google.com/p/android-notifier/
	echot "\
	************************
	* Growl
	************************
	"

	run "Shareware/Growl/setup/Growl_v2.0.6.1.msi"

	echo Installing applications...
	installDir=`$P32/Growl for Windows/apps/$@UnQuote[$app]`
	for app in ("Android Notifier Desktop" "Gmail Growl" "System Monitor") (
		run "Shareware/Growl/apps/$@UnQuote[$app]"
	)

	echo "Updating icons..."
	$mv "$ud/Growl.lnk" "$pp/Operating System/Other"
	$mv "$up/Growl.lnk" "$pp/Operating System/Other"

	echot "\
	- Security
	  - Uncheck Require password for LAN apps
	  - Check Allow network notification
	"
	pause

	return

	
	return

	:UpdateChecker
	echot "\
	****************************
	* FileHippo Update Checker
	****************************
	"

	echot "\
	- Settings
	  - Results, Open results in Custom Browser=Chrome
	  - Results, uncheck Hide beta versions, check Show the installation path
	  - Custom Locations, Add..., Public Documents/data/bin/win and win64, Folder only
	"
	UpdateChecker.exe
	pause

	return

	:TableauReader
	echot "\
	************************
	* Tableau Reader
	************************
	"

	run "Tableau/TableauReader.msi"

	echo Moving data folder...
	$makeLink --merge --hide "$udata/Tableau Repository" hide "$udoc/My Tableau Repository"

	echo "Updating icons..."
	$rm "$pd/Tableau Reader 7.0.lnk"
	$mv "$pp/Tableau Reader 7.0.lnk" "$pp/Applications/Tableau Reader.lnk"

	return

	:SoundBlaster
	:CreativeSoundBlasterXFi
	# http://support.creative.com/Products/ProductDetails.aspx?catID=1&CatName=Sound+Blaster&subCatID=208&subCatName=X-Fi&prodID=16770&prodName=PCI+Express+Sound+Blaster+X-Fi+Xt#e+Audio&bTopTwenty=1&VARSET=prodfaq:PRODFAQ_16770,VARSET=CategoryID:1
	# Installs
	# - System Run: SPIRunE - Rundll32 SPIRunE.dll,RunDLLEntry
	# - User Run: CTAutoUpdate - "C:/Program Files (x86)/Creative/Shared Files/Software Update/AutoUpdate.exe" /RunFromInstaller
	echot "\
	******************************
	* Creative Sound Blaster X-Fi
	******************************
	"

	run "Creative/PCI Express Sound Blaster X-Fi Xt#e Audio/setup/XFXA_PCDRV_LB_WIN8_1_05.exe"

	echo Updating registry...

	# Delete CTAutoUpdate - "C:/Program Files (x86)/Creative/Shared Files/Software Update/AutoUpdate.exe" /RunFromInstaller
	registry delete "HKCU/SOFTWARE/Microsoft/Windows/CurrentVersion/Run/CTAutoUpdate"

	echo "Updating icons..."
	$mergeDir "$pp/Creative" "$pp/Operating System/Other"

	SoundListen

	return

	:SoundListen

	echot "\
	- Recording, Listen, check Listen to this device, Levels=100
	  - Advanced, Default Format=2 channel, 24 bit, 44100 Hz (Studio Quality)
	- Notes
	  - If audio playback stutters try other formats
	  - If the computer does not sleep, try powercfg /requestoverride, disable Listen, 
	    or disable the Recording device
	"
	os sound
	pause

	return

	:SeaTools
	# download - http://www.seagate.com/ww/v/index.jsp?locale=en-US&name=SeaTools&vgnextoid=720bd20cacdec010VgnVCM100000dd04090aRCRD
	# test and replace Seagate drives
	echot "\
	************************
	* Seagate Tools
	************************
	"

	run "Seagate/SeaTools/SeaToolsforWindowsSetup-1208.exe"

	echo "Updating icons..."
	$rm "$pd/SeaTools for Windows.lnk"
	$mergeDir "$pp/Seagate" "$pp/Operating System/Other"

	return

	:PerformanceTest
	echot "\
	************************
	* Performance Test
	************************
	"

	run "PassMark/PerformanceTest/petst_x64.exe"

	echo "Updating icons..."
	$mergeDir "$pp/PerformanceTest (64-bit)" "$pp/Operating System/Other"

	return

	:xxcopy
	echot "\
	************************
	* xxcopy
	************************
	"

	run "Shareware/xxcopy/xxcopy.reg"

	return

	:ssd
	echot "\
	****************************************
	* SSD (Solid State Drive) common setup
	****************************************
	"

	echo Disabling SuprtFetch (not required for SSD systems)...
	os.btm DisableSuperFetch

	echo Configuring disk defragmentation schedule...
	echo - Configure schedule..., uncheck Run on a schedule
	os defrag
	pause

	echo Other setup...
	echo - Enable AHCI in BIOS
	echo - Ensure SSD supports TRIM
	pause

	return

	:AirPortExpress
	# http://support.apple.com/downloads/#airport utility windows
	echot "\
	************************
	* AirPort Express
	************************
	"

	run "Apple/AirPort/AirPortSetup v5.5.3.2.exe"

	# Delete System Run - AirPort Base Station Agent - "C:/Program Files (x86)/AirPort/APAgent.exe"
	registry 32 delete "HKLM/SOFTWARE/Microsoft/Windows/CurrentVersion/Run/AirPort Base Station Agent"

	echo "Updating icons..."
	$mv "$pp/AirPort Utility.lnk" "$pp/Operating System"
	$mv "$pp/Apple Software Update.lnk" "$pp/Operating System"

	echot "\
	- Preferences
	  - uncheck Check for updates Weekly
	  - uncheck Monitor AirPort wireless devices for problems
	"
	pause

	return

	:AiCharger
	# Charge high current over USB spec (iPad)
	# http://event.asus.com/mb/2010/ai_charger/
	echot "\
	************************
	* AI Charger
	************************
	"

	run "Asus/AI Charger/V1.00.06/Setup.exe"

	return

	:MotorolaDroid
	# https://motorola-global-portal.custhelp.com/app/answers/detail/a_id/88481
	echot "\
	*****************************
	* Motorola Droid
	*****************************
	"

	run "Motorola/Droid/MotorolaDeviceManager_2.3.9.exe"

	echo "Updating icons..."
	$mergeDir "$pp/Motorola" "$pp/Operating System/Other"

	echot "\
	- Connect the DroidX in USB Mass Storage mode
	- Notification Area, MotoHelper, When Device Connects..., Do Nothing
	"
	pause

	return

	:ooVoo
	# http://www.oovoo.com/Download.aspx
	echot "\
	************************
	* ooVoo - video chat
	************************
	- uncheck Yes, I want to install the ooVoo Toolbar
	"

	run "ooVoo/setup/ooVoo Setup v3.0.7.21.exe"

	echo Updating registry...

	# Delete ooVoo.exe - C:/Program Files (x86)/ooVoo/oovoo.exe /minimized
	registry 32 delete "HKCU/SOFTWARE/Microsoft/Windows/CurrentVersion/Run/ooVoo.exe"

	echo "Updating icons..."
	$rm "$pd/ooVoo.lnk"
	$mergeDir "$pp/ooVoo" "$ao"

	return

	:VistaSwitcher
	echot "\
	************************
	* VistaSwitcher
	************************
	"

	run "Shareware/VistaSwitcher/VistaSwitcher_1.1.4-x64.exe"

	echo Updating registry...

	# Delete VistaSwitcher - "C:/Program Files/VistaSwitcher/vswitch64.exe" /startup
	registry 32 delete "HKCU/SOFTWARE/Microsoft/Windows/CurrentVersion/Run/VistaSwitcher"

	echo "Updating icons..."
	$rm "$pd/VistaSwitcher.lnk"
	$mergeDir "$pp/VistaSwitcher" "$pp/Operating System/Other"

	echo Restoring the default profile...
	VistaSwitcher profile restore default

	echo Starting VistaSwitcher...
	sudo /standard VistaSwitcher startup

	return

	:newt
	echot "\
	************************************************
	* NEWT - Network Emulator for Windows Toolkit 
	************************************************
	"

	run "Microsoft/other/newt v2.5.1 ${architecture}.msi"

	echo "Updating icons..."
	$mergeDir "$pp/Network Emulator for Windows Toolkit" "$pp/Operating System/Other"

	return



	:.NetMemoryProfiler
	:MemProfiler
	# - download http://memprofiler.com/download.aspx
	echot "\
	************************
	* .NET Memory Profiler
	************************
	"

	run "SciTech/.NET Memory Profiler/MemProfilerInstaller4_5_184.exe"

	echo "Updating icons..."
	$mergeDir "$pp/.NET Memory Profiler 4.0" "$pp/Development/.NET/Other"

	return

	:dotTrace
	# download http://www.jetbrains.com/profiler/download/index.html
	echot "\
	************************
	* dotTrace
	************************
	"

	run "JetBrains/dotTrace/dotTracePerformanceSetup.5.2.1100.108.msi"
	run "JetBrains/dotTrace/dotTraceMemorySetup.${architecture}.3.5.360.114.exe"

	echo "Updating icons..."
	$mergeDir "$pp/JetBrains dotTrace Performance 5.0" "$pp/Development/Other/"
	$mergeDir "$pp/JetBrains dotTrace Memory 3.5" "$pp/Development/Other/"

	return

	:DBArtisan
	#  download - https://downloads.embarcadero.com/reg/dbartisan
	#     //azea1pub002/dev_rndaz/LicensedSoftware/Embarcadero/Embarcadero Products 2011/dbart900_11324.exe
	echot "\
	************************
	* DBArtisan
	************************
	- Serial Number=NNN
	- DN Login name or Email=john3909
	"

	run "Embarcadero/DBartisan/setup/dbart911_12210.exe"

	echo Moving data folder...
	$mergeDir --rename "$udoc/Embarcadero" "$udata/Embarcadero"

	echo Updating registry...
	r=HKEY_CURRENT_USER/Software/Embarcadero/DBArtisan/9.1.1
	dir=$udata/Embarcadero/DBArtisan
	registry "$r/UserSQLScripts" REG_SZ "$@RegQuote[$udata/sql]" >& nul:
	registry "$r/Directories/ETSQLXJobCfg" REG_SZ "$@RegQuote[$dir/Directories/ETSQLXJobCfg]" >& nul:
	registry "$r/Directories/IncludeFiles" REG_SZ "$@RegQuote[$dir/Directories/IncludeFiles]" >& nul:

	registry "$r/Schema/Definition Directory" REG_SZ "$@RegQuote[$dir/DefFiles]" >& nul:
	registry "$r/Schema/Report Directory" REG_SZ "$@RegQuote[$dir/Report]" >& nul:
	registry "$r/Schema/Extraction Directory" REG_SZ "$@RegQuote[$dir/Extract]" >& nul:

	echo Restoring the default profile...

	# Create the profile directory if it does not exist so it can be restored (profile method detection requires the directory exist)
	$makeDir "$_ApplicationData/Embarcadero/Data Sources"
	DBartisan profile restore default

	echo "Updating icons..."
	$mergeDir /r "$pp/Embarcadero DBArtisan 9.1.1" "$pp/Development/Other/DBArtisan"

	echot "\
	File, Options...
	- Datasource, Datasource Storage Management=File based datasource catalog
	- Connection, Login Timeout=2
	"
	sudo /standard DBartisan start
	pause

	return

	:Telerik
	# download http://www.telerik.com/account/your-products.aspx
	echot "\
	************************
	* Telerik
	************************
	"

	run "Telerik/setup/Telerik.Web.UI_2012_1_215_Dev.msi"
	run "Telerik/setup/RadControls_for_Silverlight5_2012_1_0326_Dev.msi"

	echo "Updating icons..."
	$rm "$pd/RadControls for ASP.NET AJAX*Live Examples.lnk"
	$rm "$pd/RadControls for Silverlight*Demos.lnk"
	$mergeDir "$pp/Telerik" "$pp/Development/.NET/Other"

	return

	:ErStudio
	# Intel - install //vmspaedm501/erstudio$, repository server vmspaedm551,  http://ersportal.intel.com
	echot "\
	************************
	* ErStudio
	************************
	- slp file=<paste>
	- Repository Server=vmspaedm551
	"

	echo Finding the license file...
	FindExe "Embarcadero/ErStudio/setup/concurrent_132702.slip"
	echo $@clipw[$exe] >& nul:

	run "Embarcadero/ErStudio/setup/erda_901.exe"

	echo Moving data folder...
	$makeLink --merge --hide "$udata/Embarcadero/ERStudio" hide "$udoc/ERStudio Data Architect XE"

	echo "Updating icons..."
	$mergeDir --rename "$pp/Embarcadero ERStudio Data Architect XE" "$pp/Development/Other/ERStudio"

	return

	:PowerPanel
	# download - http://www.cyberpowersystems.com/products/management-software/pppe.html?selectedTabId=resources&imageI=#tab-box
	echot "\
	************************
	* PowerPanel
	************************
	"

	run "CyberPower/PowerPanel/setup/pppe134-setup.exe"

	# Delete PowerPanel Personal Edition User Interaction - C:/Program Files (x86)/CyberPower PowerPanel Personal Edition/pppeuser.exe
	registry 32 delete "HKLM/SOFTWARE/Microsoft/Windows/CurrentVersion/Run/PowerPanel Personal Edition User Interaction"

	echo "Updating icons..."
	$mergeDir "$pp/CyberPower PowerPanel Personal Edition" "$pp/Operating System/Other"

	return

	:ThinkPadFanController
	# download - http://www.staff.uni-marburg.de/~schmitzr/donate.html (was http://sourceforge.net/project/shownotes.php?release_id=376867)
	echot "\
	**************************
	* ThinkPad Fan Controller
	**************************
	"

	run "Shareware/ThinkPadFanController/tpfc_v062.exe"

	echo "Updating icons..."
	$rm "$pd/TPFanControl.lnk"
	$mergeDir "$pp/TPFanControl" "$pp/Operating System/Other"

	return

	:BetterExplorer
	# http://bexplorer.codeplex.com/
	echot "\
	************************
	* Better Explorer
	************************
	"

	run "Shareware/Better Explorer/setup/setup v2.0.0.631.exe"

	echo "Updating icons..."
	$mergeDir "$pp/Better Explorer" "$pp/Operating System/Other"
	$mergeDir "$up/Better Explorer" "$pp/Operating System/Other"

	return

	:Toad
	# download Toad development suite - https://support.quest.com/Search/SearchDownloads.aspx?dsNav=Ns:P_DateLastModifiedSortable|101|-1|,N:268441797&Dt=Toad$20for$20SQL$20Server
	echot "\
	************************
	* Toad
	************************
	"

	run "Quest/Toad/setup/msxml.msi"
	run "Quest/Toad/setup/Toad Development Suite for SQL Server 5.8 Commercial.exe"

	echo Moving data folder...
	$makeLink --merge --hide "$udata/Benchmark Factory" hide "$udoc/My Benchmark Factory"

	echo "Updating icons..."
	$rm "$pd/Benchmark Factory for Databases*.lnk"
	$rm "$pd/Toad for SQL Server 5.8*.lnk"
	$mv "$pd/(prog).lnk" "$pp/Applications"
	$mergeDir "$pp/Quest Software" "$pp/Development/Other"

	return

	:JpegLosslessRotator
	# http://annystudio.com/software/jpeglosslessrotator/#jpegr-download
	echot "\
	************************
	* JPEG Lossless Rotator
	************************
	"

	run "Shareware/JPEG Lossless Rotator/jpegr v8.0.0.0.exe"

	echo "Updating icons..."
	$rm "$pd/JPEG Lossless Rotator.lnk"
	$mergeDir "$pp/JPEG Lossless Rotator" "$pp/Media/Other"

	return

	:PreviewHandlerPack
	# http://previewhandlers.codeplex.com/
	echot "\
	************************
	* Preview Handler Pack
	************************
	"

	run "Shareware/other/PreviewHandlerPackSetup.msi"

	return

	:GoogleDrive
	:gd
	echot "\
	************************
	* Google Drive
	************************
	"

	run "Google/Drive/gsync.msi"

	echo Updating registry...

	# Delete GoogleDriveSync - "C:/Program Files (x86)/Google/Drive/googledrivesync.exe" /autostart
	registry 32 delete "HKCU/SOFTWARE/Microsoft/Windows/CurrentVersion/Run/GoogleDriveSync"

	echo "Updating icons..."
	$rm "$ud/Google Drive.lnk"
	$mergeDir "$pp/Google Drive" "$pp/Operating System/Other"
	if "$date" != "c:" $makeShortcut.btm "$UserHome/Google Drive" "$UserSysHome/Google Drive.lnk"

	return

	CloudFoundy

	:CloudFoundry
	# http://www.cloudfoundry.com/
	echot "\
	************************
	* Cloud Foundry
	************************
	"

	run "CloudFoundry/setup/IronFoundry.CloudFoundryExplorer.${architecture}.msi"
	run "CloudFoundry/setup/IronFoundry.Vmc.x64.msi"

	echo "Updating icons..."
	$rm "$pd/JPEG Lossless Rotator.lnk"
	$mergeDir "$pp/Iron Foundry" "$pp/Development/Other"

	echot "\
	- Manage Clouds, Login name:  your intel.com email address. Password:  your WWID
	"

	return

	:WindowsSdk
	echot "\
	************************
	* Windows SDK
	************************
	"

	run "Microsoft/Windows/sdk/GRMSDK$@if[ ${architecture} == x64 ,X]_EN_DVD.iso"

	echo "Updating icons..."
	$mergeDir --rename "$pp/Microsoft Windows SDK v7.1" "$pp/Development/Other/Windows SDK"

	return

	:NuGetPackageExplorer
	:npe
	echot "\
	************************
	* NuGet Package Explorer
	************************
	"

	run "Shareware/.NET/NuGet/Package Explorer/NuGetPackageExplorer.application"

	$mv "$ud/NuGet Package Explorer.appref-ms" "$pp/Development/.NET"
	$rmd "$up/NuGet Package Explorer"

	return

	:doxygen
	echot "\
	************************
	* Doxygen
	************************
	"

	run "Shareware/Doxygen/setup/doxygen-1.8.2-setup.exe"

	echo "Updating icons..."
	$mergeDir "$pp/doxygen" "$pp/Development/Other"

	return

	:Nxt
	echot "\
	************************
	* NXT 
	************************
	"

	run "National Instruments/NXT/setup/setup.exe"

	installDir="$P32/LEGO Software/LEGO MINDSTORMS Edu NXT/manual"
	run "National Instruments/NXT/manual"

	echo "Updating icons..."
	$mergeDir "$pp/LEGO MINDSTORMS Edu NXT 2.1" "$ao"
	$rm "$pd/NXT 2.1 *.lnk"
	$makeShortcut "$P32/LEGO Software/LEGO MINDSTORMS Edu NXT/manual/assets/languages/english/index.html" ^
		"$ao/LEGO MINDSTORMS Edu NXT 2.1/NXT Manual.lnk"

	echo Moving data folder...
	$makeLink --merge --hide "$udata/LEGO Creations" hide "$udoc/LEGO Creations"

	return

	:Plex
	# http://www.plexapp.com/download/plex-media-center.php
	echot "\
	************************
	* Plex Media Center
	************************
	"

	run "Plex/setup/Plex-Media-Center-v3213059-en-US.exe"

	echo "Updating icons..."
	$mergeDir "$up/Plex Media Center" "$pp/Media/Other"

	return

	:Synology
	echot "\
	************************
	* Synology Assistant
	************************
	"

	run "Synology/DSM/setup/DSAssistant_2647/SynologyAssistantSetup-4.1-2647.exe"

	echo "Updating icons..."
	$mergeDir "$pp/Synology" "$pp/Operating System/Other"
	$rm "$pd/Synology Assistant.lnk"

	return

	:OpenVPN
	echot "\
	************************
	* OpenVPN
	************************
	"

	run "Shareware/OpenVPN/setup/openvpn-install-2.3.0-I004-x86_64.exe"

	echo Restoring the default profile...
	OpenVPN profile restore default

	echo "Updating icons..."
	$mergeDir "$pp/TAP-Windows" "$pp/Operating System/Other"
	$mergeDir "$pp/OpenVPN" "$pp/Operating System/Other"
	$rm "$pd/OpenVPN GUI.lnk"

	return

	:ApacheDirectoryStudio
	echot "\
	************************
	* Apache Directory Studio
	************************
	"

	run "Apache/Directory Studio/setup/ApacheDirectoryStudio-win-x86_64-2.0.0.v20130308.exe"

	echo "Updating icons..."
	$mergeDir "$up/Apache Directory Studio" "$pp/Operating System/other"

	return

	:MySqlWorkbench
	echot "\
	************************
	* MySQL Workbench
	************************
	"

	run "Shareware/MySql/mysql-workbench-gpl-5.2.47-win.msi"

	echo "Updating icons..."
	$mergeDir "$pp/MySQL" "$pp/Development/Other"

	return

	:BlueGrifon
	# http://bluegrifon.org/pages/Download
	echot "\
	************************
	* BlueGrifon
	************************
	"

	installDir=$P32/BlueGrifon
	run "Shareware/BlueGrifon/setup/bluegrifon-win.zip"

	echo "Updating icons..."
	$makeShortcut "$P32/BlueGrifon/bluegrifon.exe" "$pp/Development/BlueGrifon.lnk"

	return

	:SoapUI
	# http://sourceforge.net/projects/soapui/files/soapui/
	echot "\
	************************
	* SoapUI
	************************
	"

	installDir=$P32/SoapUI
	run "Shareware/SoapUI/soapui-4.5.2-windows-bin.zip"

	return

	:EyeFi
	echot "\
	************************
	* Eye-Fi
	************************
	"

	run "Eye-Fi/setup.exe"

	echo "Updating icons..."
	$mergeDir "$up/Eye-Fi" "$pp/Media/Other"

	return
