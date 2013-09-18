@echo off
SetLocal

# TODO: 
# - cleanup PATH - remove wbem, powershell
# - enable remote desktop Automatically
# - 

REM Ensure common functions and aliases are loaded  for new systems 
TcStart.btm force

REM Initialize
on break cancel 1
set DefaultSyncHost=oversoul.local
os init

REM Turn off system32 virtualization for x64 so system32 and syswow64 can be accessed
option //Wow64FsRedirection=No

set NetShareOptions=
iff defined NewOs then
  set NetShareOptions=/grant:Everyone,full
endiff

REM Arguments
if $# gt 0 goto Usage

set BinDir=$@path[$_batchname]

set path=$path;$BinDir
set SetupFiles=$BinDir$.../setup

set UserProfileReg=$@Replace[/,//,$UserProfile]

REM Setup must run as administrator with an elevated token.
iff $@IsElevated[] == 0 then
	sudo "$_BatchName"
	quit 1
endiff

REM Optionally jump to a specific setup step.
if IsLabel here goto here

echo *********************************
echo * Users folder location
echo *********************************

REM Setup users folder
account setup

REM Update common functions and aliases are loaded  in case the location of users folder changed
TcStart force

REM Create a link to the replicate folder for the browser home page  (Chrome, etc.)
MakeLink "$UserData/replicate" "$AppData/replicate"

echo *********************************
echo * Local files
echo *********************************

iff not IsDir "$PublicBin" then

  input What host do you want to synchronize with? ($DefaultSyncHost)?` ` $$SyncHost
  if "$SyncHost" == "" set SyncHost=$DefaultSyncHost

  REM Copy local files - full ensures templates are copied
  SyncLocalFiles.btm full $SyncHost
		
  REM Update the hosts
  host.btm file update
		
endiff

echo *********************************
echo * Setting console defaults
echo *********************************

SetConsoleDefaults.btm

echo *********************************
echo * Setting environment variables
echo *********************************

os environment set
pause

MakeLink merge "$UserData/download" "$UserHome/Downloads"
attrib +r "$UserHome/Downloads"

echo *********************************
echo * Updating icons
echo *********************************

echo Organizing start menu icons...
os StartMenuIcons
pause

:here

REM Change workgroup before create default accounts so the correct accounts for the workgroup are created
echo *********************************
echo * Computer Name and Workgroup
echo *********************************

text
- Change...
  - Computer name=<computer name>
  - (Wiggin) Workgroup=Wiggin
  - (Intel) Domain=amr.corp.intel.com
    - Enter username amr/<computer account owner> and password
	
endtext
os SystemProperties 1
pause

echo *********************************
echo * Policies
echo *********************************

REM Account policies
echos Setting account policies...

REM Set password policies (http://www.kellys-korner-xp.com/win_xp_passwords.htm)
if "$@WorkGroup[]" != "" net accounts /maxpwage:unlimited >& nul:

echo done

echo *********************************
echo * Accounts
echo *********************************

ask `Do you want to create the default accounts?` n
iff $? == 1 then
  account CreateDefault
  pause
endiff

echo - Make changes to my account in PC settings, Use a local account
echo - Manage Another Account, Change the picture, Pictures/Head Shots
account manager
pause

echo *********************************
echo * Creating shares
echo *********************************

iff $@IsIntelHost[] == 0 then
	net share "Public"="$PublicHome" $NetShareOptions /Remark:"Public files for everyone using this computer." >& nul:
	pause
endiff

echo *********************************
echo * Configuring tasks
echo *********************************

echo - Actions, Enable All Tasks History
os task
pause

echo *********************************
echo * Configuring services
echo *********************************

REM The messanger service (used by net send om xp) is a security hole, disable it.
iff $@ServiceExist[messenger] == 1 then
  service disable messenger
  service stop messenger
endiff

REM 
REM WebClient service
REM 
REM WebClient is used for access to WebDAV servers via UNC paths.  UNC browsing causes delays since 
REM WebClient initiates an HTTP request to the server, which some firewalls drop (i.e. Vista Windows Firewall).
REM By default, WebClient will wait 15 seconds for a response and will cache the non-response for 60 seconds.

REM Disable WebClient by default, enable for WebDAV use, but will cause 1 second delay when accessing UNC shares from JpSoftware TCC
iff $@ServiceExist[WebClient] then
	service manual WebClient
	
	REM Optimize WebClient UNC handling if WebClient is used.
	REM WebClient will wait 1 second for an HTTP response from server (NewOs setting, default 30s), and will cache the result until recycle (default 60s)
	set key=HKLM/SYSTEM/CurrentControlSet/Services/WebClient/Parameters
	iff defined NewOs then
		registry.btm set "$key/LocalServerTimeoutInSec" REG_DWORD 1
	endiff
	registry.btm set "$key/ServerNotFoundCacheLifeTimeInSec" REG_DWORD 0xFFFFFFFF

endiff

REM RemoteRegistry service is allowed for remote registry access and remote PsList process information
service auto RemoteRegistry
service start RemoteRegistry 

pause

echo *********************************
echo * Making registry updates
echo *********************************

REM Other registry updates
registry.btm import "$SetupFiles/Windows Setup $_WinVer.reg"
registry.btm import "$SetupFiles/AutoRun.reg"
registry.btm import "$SetupFiles/GetMedia.reg"

iff defined client then
  registry.btm import "$SetupFiles/HtmlHelp.reg"
endiff

pause

echo *********************************
echo * Shell Templates
echo *********************************
os TemplateSetup
pause

echo *********************************
echo * Search and Indexing
echo *********************************

text
- Modify, Show all locations
  - check Users/Public (except install)
  - check other users (except .dropbox.cache)
  - (optional) check Internet Explorer, OneNote, Outlook, SharePoint
endtext
os index options
pause

echo *********************************
echo * Install certificates
echo *********************************
certificate InstallDefault

echo *********************************
echo * Set windows system parameters
echo *********************************

REM Reference http://msdn.microsoft.com/library/default.asp?url=/library/en-us/sysinfo/base/systemparametersinfo.asp

REM Max keyboard repeat speed, default 31
echo $@WinSystem[11,31] >& NUL:

REM Keyboard - numlock on when system boots
NumLock boot on

REM Keyboard repeat delay, default 1
echo $@WinSystem[23,0] >& NUL:

REM Keyboard preference state=keyboard
echo $@WinSystem[69,1] >& NUL:

pause

echo *********************************
echo * Printers
echo *********************************

iff not defined server then
	ask `Do you want to add printers?` y
	iff $? == 1 then
		printer AddDefault
		pause 
	endiff
endiff

echo - Remove extra text in name for non-redirected printers
printer.btm control
pause

echo *********************************
echo * Disk Management
echo *********************************

text
- Label drives system/data, etc.
- Order drives letters: system, case top to bottom  
- Remove drive letters for unused drives
- (each hard disk) Properties, Policies, check Enable write cachine on the device
  - (battery) Check Turn off Windows write-cache buffer flushing on the device
endtext
os DiskManagement
pause

echo *********************************
echo * Device Manager
echo *********************************

echo - Check for unknown devices
os DeviceManager
pause

echo *********************************
echo * Network
echo *********************************

REM NetBIOS Node Type
REM http://www.networkuptime.com/archives/2001/08/troubleshooting.html
REM 
REM Broadcast slows down name resultion and should not be used, so use node types 2.
REM For networks without a WINS server, use static DHCP allocations with hosts entries, or
REM for UNC aliases for mobile computers use an lmhosts alias.
REM 
REM 1 = b-node, broadcast, Cache->Broadcast->LMHOSTS->HOSTS->DNS (default)
REM 2 = p-node, peer-peer in ipconfig, point-to-point, Cache->WINS->LMHOSTS->HOSTS->DNS
REM 4 = m-node, mixed, Cache->Broadcast->WINS->LMHOSTS->HOSTS->DNS
REM 8 = h-node. hybrid in ipconfig, Cache->WINS->Broadcast->LMHOSTS->HOSTS->DNS
registry.btm set "HKLM/SYSTEM/CurrentControlSet/Services/NetBT/Parameters/NodeType" REG_DWORD 2

REM DNS Suffix Search Order
network SetDnsSuffixSearchOrder

REM Allow other hosts to connect with DNS aliases using UNC (NetBIOS)
iff defined server then
	host StrictNameChecking disable
	pause
endiff

echo.
echo - Rename adapters (F2): LAN, WLAN, VPN, Bluetooth, 1394

iff defined client then

  text
- (Intel network, optional) LAN, Properties, Internet Protocol Version 4 (TCP/IPv4), 
  Properties, Advanced..., DNS, Select Append these DNS suffex (in order), Add..., intel.com 
- WLAN, Add, Wiggin
  - (Intel) "OnConnect v2.1" or "Primary WLAN Voice-Data v2" (was TSNOfficeWLAN or RSN2OfficeWLAN)
  endtext
	
  iff not defined vm then
    text
- LAN, Properties, Configure..., Power Management
  - Check Allow this device to wake the computer
  - Check Only allow a magic packet to wake the computer
  - Note: The computer must be shut down normally to enable WOL unless the NIC can be configured in BIOS 
    endtext
  endiff
		
endiff
network connections
pause

text
- View your active networks, click on network icon (i.e. House picture), Network name=<Wiggin, etc.>
- Change advanced sharing settings, Profile="Home or Work" and Domain
  - Network discovery, Turn on Network discovery 
  - File and printer sharing, Turn on file and printer sharing
  - Public folder sharing, Turn off Public folder sharing
  - (optional) Media streaming, Choose media streaming options..., Turn on media streaming, name your media library=<first name>
  - HomeGroup connections, Use user accounts and passwords to connect to other computers
endtext
network center
pause

echo *********************************
echo * Windows Components
echo *********************************

REM Windows Defender greatly drags down disk performance (file read/read) but provides malware production
echo.
echo Windows Defender...
echo - (optional, improve disk performance) Tools, Options, Administrator, Uncheck Use this program
os defender
pause

echo *********************************
echo * Security
echo *********************************

os uac AdminShare enable

iff $@IsIntelHost[] == 0 then

	text
- (optional) Security, Virus Protection, Turn off messages about virus protection	
- (optional) Security, Spyware, Turn off messages about spyware and related protection
	endtext
	os SecurityCenter
	pause
	
endiff

echo - Local Policies, User Rights Assignment, Create Symbolic Links, add $UserName
os LocalSecurityPolicy
pause

echo Granting the current user permission to change the public start menu...
echo - Start Menu, Properties, Security, Edit..., Add..., $UserName, check Full control
explorer "$psm/.."
pause

echo *********************************
echo * Explorer
echo *********************************

text
- View, Options, View
  - Uncheck Hide extensions for known file types
- Desktop, View, Large icons
- Organize, Folder and Search Options...,
  - General, check Show all folders 
  - View, Uncheck Use Sharing Wizard
- Desktop, Recycle Bin, Properties, uncheck Display delete confirmation dialog
- (force show) Libraries, <library>, Includes, add c:/temp, OK, remove c:/temp 
endtext
start /pgm explorer.exe
pause

echo *********************************
echo * Taskbar
echo *********************************

text
- Taskbar, Properties
  - Uncheck Show taskbar on all displays
	- Number of recent items to display in Jump Lists=15
endtext
pause

echo *********************************
echo * Display Settings
echo *********************************

text
- Performance, Settings, Visual Effects
  - (fast client) Let Windows choose what's best for my computer
  - (server) Adjust for best performance
  - (pre-Windows 7 vm) Check only
    - Show window contents while dragging
    - Smooth edges of screen fonts
    - Use visual styles on windows and buttons
  - (slow client) Check only
      - Smooth edges of screen fonts
      - Smooth-scroll list boxes
endtext
os SystemProperties 3
pause

text

- Screen resolution=recommended
- Advanced Settings, Monitor
  - Screen refresh rate=<maxiumum>
  - Colors=True Color (32 bit)
endtext
desk.cpl
pause

REM   ClearType:: http://www.microsoft.com/typography/cleartype/
echo - Display, Adjust ClearType text
os appearance
pause

echo *********************************
echo * Screen Saver and Background
echo *********************************

background install
background UpdateSelected

REM No Screen Saver in virtual machines
iff defined vm then
  registry import "$SetupFiles/Screen Saver None.reg"
endiff

echo *********************************
echo * Sound
echo *********************************

iff defined client then
  
  text
- right click, uncheck Show disbled and disconnected device
- Playback, playback device
  - (if present) Configure Speakers... 
  - Properties
    - (if present) Supported Formats, select, Test
    - (select default audio levels) Levels
    - (select default format) Advanced, Default Format, Test (for amplifiers)
  endtext
  os sound
  pause

endiff

echo *********************************
echo * Drivers
echo *********************************

echo - Review Logon and Drivers
start /pgm autoruns
pause

echo *********************************
echo * System
echo *********************************

REM Page File
text
- Setting, Advanced, Change
  - Uncheck Automatically manage paging file size for all drives
  - (data drive) C:, No paging file
  - C: or (data drive) D:, Custom size, Initial Size=Maximum Size=<memory>
endtext
os VirtualMemory
pause

REM System Restore
iff defined client then

	echo - (vm, SSD) Configure, Turn off system protection
	vss.btm configure 
	pause
	
	set key=HKLM/System/CurrentControlSet/Control/BackupRestore/FilesNotToSnapshot
	registry.btm set "$key/Acronis Backups" REG_MULTI_SZ $UserData/Acronis/*.* /s
	registry.btm set "$key/VMware Virtual Machines" REG_MULTI_SZ $UserData/VMware/*.* /s

	echo - Review FilesNotToSnapshot
	vss.btm exclude
	pause
	
	echo - Set RPGlobalInterval (seconds between restore points) and 
	echo - Set RPSessionInterval (seconds using computer between restore points)
	vss.btm interval
	pause
	
endiff

REM Remote Desktop

iff defined vm then
  echo - Uncheck Allow Remote Assistance connections to this computer
endiff

echo - Select Allow connections only from computers running Remote Desktop with Network Level Authentication
os SystemProperties 5
pause
	
echo *********************************
echo * Power
echo *********************************

power hibernate disable

iff defined client .and. not defined vm then

	text
- Change plan settings, Change advanced power settings
  - Require a password on wakeup=Yes
  - Sleep
    - Put the computer to sleep=15 minutes/2 hours
    - (on UPS) Sleep, Allow hybrid sleep=Off
    - (if issues waking up) Allow wake timers=Disable
  - Change what closing the lid does, all Sleep except
    - Plugged in, When I close the lid, Do nothing
  - Display, Turn off display after=5/10 minutes
  endtext
  power config
  pause

  text
- Computer Configuration, Administrative Templates, 
  System, Power Management, Button Settings, Select the Start Menu Power Button Action=sleep
endtext
  os GroupPolicyEditor
  pause

endiff

echo *********************************
echo * Event Log
echo *********************************

text
- Create Custom View...
  - Logged=Last hour, Check all logs, name=Last Hour
  - Logged=Last 24 hours, Check all logs, name=Last Day
endtext
event
pause

echo *********************************
echo * Firewall
echo *********************************

iff $@IsIntelHost[] == 0 then

	firewall setup

	REM Remote administration  (event viewer, performance monitor, etc)
	echo Enabling remote administration...
	firewall rule enable "Remote Administration (RPC)"

	echo Enabling ICMP (ping)....
	firewall rule enable "File and Printer Sharing (Echo Request - ICMPv4-In)"
	firewall rule enable "File and Printer Sharing (Echo Request - ICMPv6-In)"
	
endiff

REM Virtual Machine setup
iff defined vm then

  echo *********************************
  echo * Virtual Machine
  echo *********************************

  echo - (slower host to optimize performance on terminal server) Pointer Options, uncheck Enhance pointer precision
  mouse.btm configure
  pause

	REM Setup CD-ROM in correct order for iso mounting 
	echo - (each CD-ROM) Properties, CDR00 on D:, CDR10 on E:
	os DiskManagement
	pause

	REM For ISO mounting done through virtual CD-ROM drives
	drive mount d:/ c:/dev/iso1
	drive mount e:/ c:/dev/iso2
	
endiff

echo *********************************
echo * Legacy client setup
echo *********************************

if not defined NewClient SetupLegacy

echo *********************************
echo * $ComputerName$ specific setup...
echo *********************************

switch "$ComputerName"

case "oversoul"

echo Configuring install directory...
set dir=$PublicDocuments/data/install
MakeDir "$dir"
net share "Install"="$dir" $NetShareOptions /Remark:"Program installation."

echo Configuring drop directory...
set dir=$PublicDocuments/drop & MakeDir "$dir"
net share "Drop"="$dir" $NetShareOptions /Remark:"Public drop box."

echo Configuring Favorites...
text
- Favorties
  - remove Downloads and Recent Places
  - add Intel (//jjbutare-mobl1/John/Documents)
endtext
start /pgm explorer
pause

endswitch

echo *********************************
echo * Install core programs
echo *********************************

REM endlocal so install host is preserved for installs outside setup.btm
EndLocal DefaultSyncHost

install host $DefaultSyncHost core

echo Setup has finished.
quit 0

:usage
echo usage: setup
quit 1
