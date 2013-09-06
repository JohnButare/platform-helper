
if not defined UserOnly gosub SyncShared
if $UserName != wsystem gosub SyncUser

# Update Take Command configuration
iff "$SyncMethod" != "DestOlder" then
	echo Updating Take Command configuration...
	call TcStart.btm force
endiff

timer off /3

quit 0

# Sync Shared
:SyncShared

echo Syncing Shared folders...

gosub SyncPublic
gosub SyncEtc

return

:SyncEtc

if not defined DestEtc return

iff $@IsElevated[] == 0 then
	echo Elevation required to sync etc directory.
	return
endiff

src="SrcEtc
dest="DestEtc
options=/xf $AlwaysExclude$#hosts#HostNetworks#hosts.ics#gm.dls#gmreadme.txt#*.tmp
gosub sd

return

:SyncPublic

SrcPrefix="SrcPublicDocuments
DestPrefix="DestPublicDocuments
gosub CloseProcesses

# Sync Files
dir=data/bin & options=/xf $PublicBinExclude & gosub sdsp
dir=data/doc & gosub sdp
dir=data/lib & gosub sdp
dir=data/man & gosub sdsp
dir=data/setup & gosub sdp

# Group templates
dir=data/templates & gosub sdp

# Sync icons - Don''t sync icon subdirectories, put common icons in root of this folder.
dir=icons & gosub sdp

return

# Sync User
:SyncUser
echo Syncing $UserName folders...

SrcPrefix="SrcUserDocuments
DestPrefix="DestUserDocuments
dir=data/bin & gosub sdsp
dir=data/certificate/public & gosub sdsp
dir=data/profile/default & gosub sdp
dir=data/replicate & gosub sdp

# Only sync private certificates on machines where the certificate private directory already exists
iff IsDir "$SrcPrefix/data/certificate/private" .and. IsDir "$DestPrefix/data/certificate/private" then
	dir=data/certificate/private & gosub sdsp
endiff

SrcPrefix="SrcUserHome
DestPrefix="DestUserHome
dir=.ssh & options=/xf $AlwaysExclude#environment#known_hosts & gosub sdp

iff "$host" == "nas" then
	echos Updating nas ssh permissions...
	call pu.btm run root@nas chmod 700 /volume1/homes/$UserName/.ssh; chmod 644 /volume1/homes/$UserName/.ssh/authorized_keys; echo "done"
endiff

# Sync User application Data
iff "$SrcApplicationData" != "" .and. "$DestApplicationData" != "" then 
	SrcPrefix="SrcApplicationData
	DestPrefix="DestApplicationData
	# dir=Sublime Text 2 && gosub mdp
endiff

# Applications
dir=data/emacs & gosub sdp

dir=data/templates
options=/xf $AlwaysExclude$#normal.dot#normal.dotm#Document?Themes#LiveContent#SmartArt?Graphics
gosub sdsp

# Copy replicated files to update the explorer shell template
call CopyFile.btm /q "$SrcPrefix/data/templates/toc.docx" "$UserProfile/templates"

# Update AutoHotKey configuration if we are not running elevated
iff "$SyncMethod" != "DestOlder" .and. $@IsElevated[] == 0 then
	echo Updating AutoHotKey configuration...
	bash --login AutoHotKey restart
endiff

return

:usage
text
SyncLocalFiles [diff] [full] [silient] [user] [bin] [sync|SycOlder|DestOlder](sync) [NoBak] [host|all](find)
	full - sync everything
	silent - no prompting
	user, bin - sync only user or bin files
	sync|SrcOlder|DestOlder - The syncrhonization method.
endtext
quit 1

# SyncDir
:sd
gosub InitOptions
call SyncDir $diff $options $SyncMethod $NoBak "$src/*" "$dest"
options=
return

# SyncDirPrefix
:sdp
gosub InitOptions
call SyncDir $diff $options $SyncMethod $NoBak "$SrcPrefix/$dir/*" "$DestPrefix/$dir"
options=
return

# SyncDirSubdirectories
:sds
gosub InitOptions
call SyncDir $diff $options $SyncMethod $NoBak /s "$src/*" $older "$dest"
options=
return

# SyncDirSubdirectoriesPrefix
:sdsp
gosub InitOptions
call SyncDir $diff $options $SyncMethod $NoBak /s "$SrcPrefix/$dir/*" $older "$DestPrefix/$dir"
options=
return

# MergeDirPrefix
:mdp
call BeyondCompare "$SrcPrefix/$dir/*" "$DestPrefix/$dir"
return

:InitOptions

iff "$options" == "" then
	options=/xf $AlwaysExclude$
endiff

return 

:CloseProcesses

for $process in ($CloseProcesses) (

	for $architecture in (. x86 x64) (
	
		# Close process explorer if the file ages are different
		iff exist "$DestPublicDocuments/data/bin/$architecture/$process.exe" .and. exist "$SrcPublicDocuments/data/bin/$architecture/$process.exe" then

			iff $@FileAge["$DestPublicDocuments/data/bin/$architecture/$process.exe",w] != $@FileAge["$SrcPublicDocuments/data/bin/$architecture/$process.exe",w] then

				echo Forcing $process to close so that it can be updated...
				taskend /f $process >& nul:
				PsKill //$host $process
		
			endiff
	
		endiff
	)
)

return
