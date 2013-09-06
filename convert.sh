REM Add Intel excludes if this machine of the destination machine is an Intel host
iff %@IsIntelHost[] == 1 .or. %@IsIntelHost[%DestId] == 1 then
	set PublicBinExclude=%PublicBinExclude#%IntelExcludes%
REM endiff

REM Display status
switch %SyncMethod
case SrcOlder
	echos Replacing%FullDesc local files from 
case DestOlder
	echos Copying%FullDesc local files to 
case sync
	echos Synchronizing%FullDesc local files to
endswitch
echos  %DestMachine

REM Display destination true name
if "%DestMachine" != "%DestId" echos  (%DestId)
echo .

REM Identify source directories
set SrcUserHome=%UserHome
set SrcPublicDocuments=%PublicDocuments
set SrcUserDocuments=%UserDocuments
set SrcApplicationData=%ApplicationData
set SrcEtc=%system\drivers\etc
set SrcPrograms32=%programs32

REM Destination directories

call os FindDirs %DestMachine
if %? != 0 quit %?

set DestUserHome=%_UserHome
set DestPublicDocuments=%_PublicDocuments
set DestUserDocuments=%_UserDocuments
set DestApplicationData=%_ApplicationData
set DestEtc=%@if[defined _system,%_system\drivers\etc]
set DestPrograms32=%_programs32

set SyncTemplates=true

if IsLabel here goto here

REM Sync full applications
iff defined full then
	if "%@HostInfo[%ComputerName,mobile]" == "yes" call OneNote.btm sync
endiff

REM Sync bin folder
iff defined bin then

	iff defined UserOnly then
		set src=%SrcUserDocuments\data\bin
		set dest=%DestUserDocuments\data\bin
		gosub sds
		
	else
		gosub CloseProcesses
		
		set src=%SrcPublicDocuments\data\bin
		set dest=%DestPublicDocuments\data\bin	
		
		set options=/xf %PublicBinExclude%
		gosub sds
		
	endiff

REM Sync all folders
else 

	if not defined UserOnly gosub SyncShared
	if %UserName != wsystem gosub SyncUser

endiff

REM Update Take Command configuration
iff "%SyncMethod" != "DestOlder" then
	echo Updating Take Command configuration...
	call TcStart.btm force
endiff

timer off /3

quit 0

REM Sync Shared
:SyncShared

echo Syncing Shared folders...

gosub SyncPublic
gosub SyncEtc

return

:SyncEtc

if not defined DestEtc return

iff %@IsElevated[] == 0 then
	echo Elevation required to sync etc directory.
	return
endiff

set src=%SrcEtc
set dest=%DestEtc
set options=/xf %AlwaysExclude%#hosts#HostNetworks#hosts.ics#gm.dls#gmreadme.txt#*.tmp
gosub sd

return

:SyncPublic

set SrcPrefix=%SrcPublicDocuments
set DestPrefix=%DestPublicDocuments
gosub CloseProcesses

REM Sync Files
set dir=data\bin & set options=/xf %PublicBinExclude & gosub sdsp
set dir=data\doc & gosub sdp
set dir=data\lib & gosub sdp
set dir=data\man & gosub sdsp
set dir=data\setup & gosub sdp

REM Group templates
iff defined full .and. defined SyncTemplates then
	set dir=data\templates & gosub sdp
endiff

REM Sync icons - Don't sync icon subdirectories, put common icons in root of this folder.
set dir=icons & gosub sdp

return

REM Sync User
:SyncUser
echo Syncing %UserName folders...

set SrcPrefix=%SrcUserDocuments
set DestPrefix=%DestUserDocuments
set dir=data\bin & gosub sdsp
set dir=data\certificate\public & gosub sdsp
set dir=data\profile\default & gosub sdp
set dir=data\replicate & gosub sdp

REM Only sync private certificates on machines where the certificate private directory already exists
iff IsDir "%SrcPrefix\data\certificate\private" .and. IsDir "%DestPrefix\data\certificate\private" then
	set dir=data\certificate\private & gosub sdsp
endiff

set SrcPrefix=%SrcUserHome
set DestPrefix=%DestUserHome
set dir=.ssh & set options=/xf %AlwaysExclude#environment#known_hosts & gosub sdp

iff "%DestMachine" == "nas" then
	echos Updating nas ssh permissions...
	call pu.btm run root@nas chmod 700 /volume1/homes/%UserName/.ssh; chmod 644 /volume1/homes/%UserName/.ssh/authorized_keys; echo "done"
endiff

REM Sync User application Data
iff "%SrcApplicationData" != "" .and. "%DestApplicationData" != "" then 
	set SrcPrefix=%SrcApplicationData
	set DestPrefix=%DestApplicationData
	REM set dir=Sublime Text 2 && gosub mdp
endiff

REM Applications
if defined full (set dir=data\emacs & gosub sdp)

iff defined full .and. defined SyncTemplates then

	set dir=data\templates
	set options=/xf %AlwaysExclude%#normal.dot#normal.dotm#Document?Themes#LiveContent#SmartArt?Graphics
	gosub sdsp
	
	REM Copy replicated files to update the explorer shell template
	call CopyFile.btm /q "%SrcPrefix\data\templates\toc.docx" "%UserProfile\templates"

endiff

REM Update AutoHotKey configuration if we are not running elevated
iff "%SyncMethod" != "DestOlder" .and. %@IsElevated[] == 0 then
	echo Updating AutoHotKey configuration...
	bash --login AutoHotKey restart
endiff

return

:usage
text
SyncLocalFiles [full] [silient] [user] [bin] [sync|SycOlder|DestOlder](sync) [NoBak] [host|all](find)
	full - sync everything
	silent - no prompting
	user, bin - sync only user or bin files
	sync|SrcOlder|DestOlder - The syncrhonization method.
endtext
quit 1

REM SyncDir
:sd
gosub InitOptions
call SyncDir %diff %options %silent %SyncMethod %NoBak "%src\*" "%dest"
set options=
return

REM SyncDirPrefix
:sdp
gosub InitOptions
call SyncDir %diff %options %silent %SyncMethod %NoBak "%SrcPrefix\%dir\*" "%DestPrefix\%dir"
set options=
return

REM SyncDirSubdirectories
:sds
gosub InitOptions
call SyncDir %diff %options %silent %SyncMethod %NoBak /s "%src\*" %older "%dest"
set options=
return

REM SyncDirSubdirectoriesPrefix
:sdsp
gosub InitOptions
call SyncDir %diff %options %silent %SyncMethod %NoBak /s "%SrcPrefix\%dir\*" %older "%DestPrefix\%dir"
set options=
return

REM MergeDirPrefix
:mdp
call BeyondCompare "%SrcPrefix\%dir\*" "%DestPrefix\%dir"
return

:InitOptions

iff "%options" == "" then
	set options=/xf %AlwaysExclude%
endiff

return 

:CloseProcesses

for %process in (%CloseProcesses) (

	for %architecture in (. x86 x64) (
	
		REM Close process explorer if the file ages are different
		iff exist "%DestPublicDocuments\data\bin\%architecture\%process.exe" .and. exist "%SrcPublicDocuments\data\bin\%architecture\%process.exe" then

			iff %@FileAge["%DestPublicDocuments\data\bin\%architecture\%process.exe",w] != %@FileAge["%SrcPublicDocuments\data\bin\%architecture\%process.exe",w] then

				echo Forcing %process to close so that it can be updated...
				taskend /f %process >& nul:
				PsKill \\%DestMachine %process
		
			endiff
	
		endiff
	)
)

return
