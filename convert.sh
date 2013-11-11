#!/bin/bash

:sync
media nas all
# WindowsMediaPlayer SyncPlaylist
# AmazonMp3 sync
# WindowsMediaPlayer sync
# media router sync
return $?


:backup

for portable in (1 2) (
	dir=c:/dev/portable$portable/backup
	
	iff IsDir "$dir" then
		rc /purge "$userPictures" "$dir/Pictures" /xf thumbs.db
		rc /purge "$userVideos" "$dir/Videos" /xf thumbs.db
	endiff
	
)

return 0

:get

# Initialize
GMT=
operation=$OperationArg

# Process specified drive
iff "$drive" != "" then
	gosub ProcessDrive
	
# Find a drive to process
elseiff "$source" != "" then	
	gosub ProcessDir "$source" clean
	
# Default directories and all drives
else
	for dir in ($pictureDirs) gosub ProcessDir $dir
	for drive in ($_ready) gosub ProcessDrive

endiff

# Process the media
iff defined ProcessedDirs then
	echo.
	if not defined NoPostProcess gosub PostProcess
endiff

return 0

# Process newly downloaded media
:PostProcess

iff "$ProcessedDirs" != "" then
	gosub NasMedia
endiff

for dir in ($ProcessedDirs) (

	# Use the 32 bit explorer to improve video thumbnail generation
	explorer.btm 32 "$dir"
	
)

return 0

:ProcessDrive

if "$drive" == "" return

# Ensure we have the drive letter only by removing :, /, /, and "
drive=$@strip[://^",$drive]

# Return if the drive is not ready and removable
if $@ready[$drive:] !=  1 .or. $@removable[$drive:] != 1 return

# Look for various picture directories
for MediaDir in ($MediaDirs) (

	# Determine the options to use from the media directory, change : separate options into space separated list
	options=$@replace[:, ,$@field[":",1-100,$MediaDir]]

	GMT=
	operation=$OperationArg
	
	iff "$options" != "" then
	
		if $@IsInList[GMT $options] == 1 GMT=true
		
		# Use copy operation if it is the default option and an operation has not been specified on the command line
		iff $@IsInList[copy $options] == 1 .and. "$operation" == "default" then
			operation=copy
		endiff
		
  endiff
		
	# Process the media on the drive
	gosub ProcessDir "$drive:$@field[":",0,$MediaDir]"
  
)

return

:ProcessDir [DirArg clean]

dir=$@UnQuote[$DirArg]

# Return if the directory does not exist
if not IsDir "$dir" return 0	

# Return if the directory is empty
if $@DirSize[b,$dir] == 0 return 0
		
# Process each file in the directory
echo Processing $dir...
for $file in ("$dir/*") gosub ProcessFile

# Remove the folder if we are cleaning and the directory is empty (can't use defined clean with gosub arguments)
if "$clean" == "clean" if $@DirSize[b,$dir] == 0 RmDir /q "$dir"
		
return

:ProcessFile

file=$@UnQuote[$file]
FileName=$@FileName[$file]

# the default operation
if "$operation" == "default" operation=move

# Determine the source and destination extension
ext=$@ext[$file]
DestExt=$ext

# AVCHD Video - mpg, mts, m2ts, or mp4 - Pre-Windows 7 did not recognize mts, mpg not recognized by Sony Motion Picture Broweser and stutter on Win 7, Sony Handycam import utility renames from mts to m2ts, so keep mts extension
# if "$ext" == "mts" DestExt=mpg

# Determine the type of media  (picture or video)
MediaType=picture
if $@index[$videoExtensions,$ext] != -1 MediaType=video

# If not specified, detemrine the destination directory based on the computer name and media type
DestPrefix=$destination
iff "$DestPrefix" = "" then
	
	iff "$ComputerName" == "$mediaRoo" .and. "$MediaType" == "picture" then
		DestPrefix=$@PublicPictures[]/Camera/$PersonName
	elseiff "$ComputerName" == "$mediaRoo" .and. "$MediaType" == "video" then
		DestPrefix=$@PublicVideos[]/Camera/$PersonName
	elseiff "$MediaType" == "picture" then
		DestPrefix=$userPictures/Camera
	else
		DestPrefix=$userVideos/Camera
	endiff
  
	iff not IsDir "$DestPrefix" then
		ask.btm `Create the destination directory $DestPrefix?` y
		if $? == 0 quit 1
		MakeDir "$DestPrefix"
	endiff
	
endiff

# Get the date and time the media was taken
gosub ProcessDate

# Convert GMT to Mountain Time for devices that store date and time in GMT
iff defined GMT then
	FileAgeDate=$@AgeDate[$@eval[$@MakeAge[$FileDate $FileTime] - (36000000000 * 6)],1]

	FileDate=$@word[0,$FileAgeDate]
	FileTime=$@word[".",0,$@word[1,$FileAgeDate]]	
endiff

# Don't download files before the specified get date to save time
if "$getDate" != "" .and. $@MakeAge[$FileDate,$FileTime] lt $@MakeAge[$getDate] return 0

DestDir=$DestPrefix/$@year[$FileDate]/$@year[$FileDate]$@word["-",1,$FileDate]
FileDateTime=$@replace[-,_,$FileDate] $@replace[:,_,$FileTime]
DestFile=$@if[ defined NoRename ,$@name[$FileName],$@if[ defined KeepName ,$FileDateTime - $@name[$FileName],$FileDateTime]]
DestSuffix=
DestFileName=`$DestFile$$DestSuffix$.$DestExt$`
dest=`$DestDir/$DestFileName$`
if not IsDir "$DestDir" MakeDir "$DestDir"

# Check for duplicate and prompt to remove if moving
gosub ProcessDuplicates
iff $_? == 1 then
	
	if "$operation" == "copy" return
	
	iff defined AskRemoveDups then
		ask `Remove identical file $FileName from the source media?` n
		if $? == 0 return
	endiff

	echos Removing duplicate file $FileName...
	DelFile $test "$file"
	echo done.
	
	return
	
endiff

# If the destination filename already exists but it is  a different size (rapid picture taking), append a numeric suffix
do while IsFile "$dest"
	
	iff "$DestSuffix" == "" then
		DestSuffix= 1
	else
		DestSuffix= $@eval[$DestSuffix + 1]
	endiff

enddo

# Update the list of processed directories
iff $@IsInList["$DestDir" $ProcessedDirs] == 0 then
	ProcessedDirs=$ProcessedDirs "$DestDir"
endiff

BigFile=$@if[ $@FileSize["$file",m] gt 50,true]

# Process the file 
echos $@if[ "$operation" == "move",Moving,Copying] $FileName$$@if[ "$FileName" != "$DestFile" , ($DestFile)]...
gosub GetCopyFile

iff not defined NoiCloud .and. ^
	"$MediaType" == "picture" .and. IsDir "$iCloudPhotoUpload" .and. "$dir" != "$iCloudPhotoStream" then

	echos iCloud...
	dest=$iCloudPhotoUpload/$DestFileName$
	gosub GetCopyFile
	
endiff

iff "$operation" == "move" then
	DelFile.btm $test "$file"
endiff

echo done.

return 0

:GetCopyFile

copy $@if[ defined test ,/n] $@if[ defined BigFile ,/g] ^
	$@if[ not defined test and not defined BigFile ,/q] "$file" "$dest"

return

# Return 1  if the file exists with the same size and name (original new nanme) 
:ProcessDuplicates

FileSize=$@FileSize["$file"]

DupFile=$@FindFirst[ /[s$FileSize,$FileSize] "$DestDir/$DestFile$*.$DestExt"]
if "$DupFile" != "" return 1

DupFile=$@FindFirst[ /[s$FileSize,$FileSize] "$DestDir/$FileName"]
if "$DupFile" != "" return 1

# For mts/m2ts file the extension and date/time stamp may is different when importing through Picture Motion Browser as the 
# start time of the video is used, so don't look at the minutes, seconds, or extension
iff $@index[mts m2ts,$ext] != -1 then
	DupFile=$@FindFirst[ /[s$FileSize,$FileSize] "$DestDir/$@left[-5,$DestFile$]*.m?ts"]
	if "$DupFile" != "" return 1
endiff

return 0

# Get the data and time of the file to process 
:ProcessDate

FileDate=
FileTime=

iff "$MediaType" == "picture" then
	gosub ProcessFileExifDate
endiff

iff "$FileDate" == "" .or. "$FileTime" == "" then
	gosub ProcessFileDate
endiff

return

# Get file FileDate  (YYYY-MM-DD) and FileTime (HH:MM:SS)  from the EXIF data last write time
:ProcessFileExifDate

FileDateTime=$@ExecStr[exiftool.exe -s3 -d `"$Y-$m-$d $H:$M:$S"` -CreateDate "$file"]
FileDate=$@word[0,$FileDateTime]
FileTime=$@word[1,$FileDateTime]

return

# Get file FileDate  (YYYY-MM-DD) and FileTime (HH:MM:SS)  from the file system last write time
:ProcessFileDate

# Get the file date and time from the last modification time by defails
FileDate=$@FileDate["$file",w,4]
FileTime=$@FileTime["$file",w,s]

# DSC-HX5v importerd video last modification date is not correct, but the file name is in the  format YYYYMMDDHHMMSS
#   This is the preferred date to use as it is the start time of the recording not the end time.
p=$@word[".",0,$@name["$file"]]
iff $@numeric[$p] == 1 .and. $@len[$p] == 14 then
	FileDate=$@InStr[0,4,$p]-$@InStr[4,2,$p]-$@InStr[6,2,$p]
	FileTime=$@InStr[8,2,$p]:$@InStr[10,2,$p]:$@InStr[12,2,$p]
endiff

return

:frame

# Initialize
FrameDir=`$drive/frame`

iff $@IsInstalled[ImageMagick] == 0 then
	EchoErr ImageMagick is not installed.
	return 1
endiff

# Search for drives with picture frame media
found=
for drive in ($_ready) (
	iff IsDir "$FrameDir" then
		gosub ProcessFrameDrive
		if $_? != 0 LeaveFor
	endiff
)

FindRandomFile done

iff not defined found then
	EchoErr Media with a frame directory is not present.
	return 1
endiff

return 0

:ProcessFrameDrive

iff not defined found then
	gosub FindPictures
	if $_? != 0 return $_?
endiff
found=true

echos Adding pictures to frame media in drive $drive...

do 

	# Get the next file
	FindRandomFile next
	if $? != 0 leave
	
	dest=$FrameDir/$@FileName[$file]
	if IsFile "$dest" iterate
	
	# Leave if the drive does not have enough disk space for the file
	if $@diskfree[$drive. M] lt 200 .or. $@diskfree[$drive] lt $@FileSize["$file"] leave

	# Copy the file
	iff not IsFile "$dest" then
		echos $@FileName[$dest]..
		ImageMagick.btm convert -resize 1024x768 "$file" "$dest"
	endiff
	
	echos .
enddo

echo done.
return

:collect

# Arguments
iff $# == 0 then
  NumPictures=50
elseiff $@Numeric[$1] == 1 then
  NumPictures=$1
else
  goto usage
endiff

# Prepare destination folder
dest=$@PublicPictures[]/Collected
if not IsDir "$dest" md /s "$dest"

gosub FindPictures
if $_? != 0 return $_?

echos Copying $NumPictures pictures from $host... 
do $NumPictures
  FindRandomFile next
  if $? != 0 return $?
  copy /q "$file" "$dest"
  echos .
enddo

echo done.

FindRandomFile done
if $? != 0 return $?

return 0

# Get an active host with media, checking if the localhost supports media first
:FindPictures

host=$ComputerName
dir=$PublicHome/Pictures

iff "$ComputerName" != "oversoul" then

	host=oversoul
	
	if $@PrepareHost[$host] == 0 return 1
	
	dir=//$host/Public/Pictures
	
endiff

iff not IsDir "$dir" then
	EchoErr Public picture folder does not exist on $host.
	return 1
endiff

echo Collecting pictures...
FindRandomFile "$dir/*.jpg"
return $?

:transfer

# Return if we are already on Oversoul
iff "$ComputerName" == "oversoul" then
	EchoErr Already on Oversoul
	return 1
endiff

# Transfer media to oversoul
ask.btm `Transfer media?` y
iff $? == 1 then
	Explorer.btm "//oversoul/Public"
	Explorer.btm "$UserHome"
	pause Move pictures to Oversoul then press any key to continue...
endiff

:clean
:cleanup

echo Hiding media files...
HideFiles.btm "pub:/Music" "folder.jpg foo.jpg"

return 0

:router

# Arguments
if $@IsHelpArg[$@UnQuote[$1]] == 1 goto usage

# Find router
router=
for /d device in (c:/dev/router* //router/router1) (
	iff IsDir "$device/Music" then
		router=$device
		LeaveFor
	endiff	
)
iff "$router" == "" then
	EchoErr Could not find the router.
	return 1
endiff

command=all
iff $# gt 0 then
	command=$1
	shift
endiff
if not IsLabel Router$command goto usage

gosub Router$command
return $_?

:RouterAll
gosub RouterMusic
gosub RouterAudible
gosub RouterPictures
gosub RouterVideos
gosub RouterConvert
gosub RouterClean
return

:RouterAudible

dir=$UserDocuments/data/Audible/downloads
if not IsDir "$dir" return 0

# - Use /fft  (2 second granularity between file times) as router does not store exact times
echo Copying Audible audio books to the router...
robocopy "$dir" "$router/Audible" ^
	/s /mir /fft /if *.aa
	
return

:RouterMusic

ask.btm `Update MP3 playlists?` n 3
iff $? == 1 then 
	text
- In Windows Media Player, click Playlists
- Right click the playlist and select play (Auto Playlists: 5 stars, Best)
- Save list as... (on the drop down to the right of Clear list)
- Save as type-M3u playlist, location D:/Users/Public/Music/Playlists
	endtext
	wmp start
	pause
endiff

# - Use /fft  (2 second granularity between file times) as router does not store exact times
# - Exclude WPL (Windows Playlists) - Sonos shows WPL but doesn't support auto playlists, so save auto playlists as M3U before copying
echo Copying $mediaRoo Music to the router...
robocopy "$mediaUnc/Music" "$router/Music" ^
	/s /mir /fft /xd Podcasts /xf *.jpg *.ini *.db *.wpl *.plist

echo (optional) Update the Sonos library immediately: Manage, Update Music Library Now
Sonos start

return

:RouterPictures

# - Use /fft  (2 second granularity between file times) as router does not store exact times
echo Copying $mediaRoo Pictures to the router...
robocopy "$mediaUnc/Pictures" "$router/Pictures" ^
	/s /mir /fft /xd "iPod Photo Cache" /xf *.modd *.moff *.db *.lnk *.txt *.nri *.ini *.url *.mov *.mpg *.3g2 *.wav *.docx *.jps *.msg *.pdf *.zip

return

:RouterVideos

# - Copy Videos from all video sources
for $dir in ($videoSources) gosub RouterCopyVideo $dir

return

:RouterCopyVideo [source]

if not IsDir "$source" return 1

echos Copying $source mp4 videos to the router...

DestPrefix=$router/Videos
SrcPrefix=$@UnQuote[$source]

pushd "$SrcPrefix"
for /r $src in ("*.mp4") (
	dest=$DestPrefix$$@right[-$@len[$SrcPrefix],$src]
	
	DestPath=$@path[$dest]
	if not IsDir "$DestPath" MakeDir "$DestPath"

	SplitFile=$@name[$src]_???.mp4
	
	# Copy small files 
	iff $@FileSize["$src",G] le 1 then
		CopyFile /SizeDifferent "$src" "$dest" /g
		echos .
		
	# Break up large files - they cause the router DLNA service to fail and are cumbersome to view
	elseiff not IsFile "$SplitFile" then
		echo.
		echo Splitting $@FileName["$src"] because it is too large....
		mp4box -split 300 "$src"
		for $SrcSplit in ("$SplitFile") (
			CopyFile /SizeDifferent "$SrcSplit" "$DestPath" /g
		)
	endiff
)
popd

echo ...done

return

# Clean old files and directories from the router
:RouterClean

echo Cleaning extra router videos...

# Only clean if all sources are present
clean=true
for src in ($videoSources) (
	iff not IsDir $@quote[$src] then
		clean=
		LeaveFor
	endiff
)

iff not defined clean then 
	echo Not cleaning since not all video sources could be found.
	return
endiff

echos Searching for extra video files on the router...

# Delete files that are not in one of the sources.  Nested for loop must be in a separate function otherwise file variable is corrupted.
pushd "$router/Videos"
for /r $file in ("*") gosub RouterCleanFile
popd

echo done.

# Remove empty directories from the router
DelDir quiet empty "$router/Videos"

return

:RouterCleanFile

# Find files not present in one of the soruces
for VideoSource in ($videoSources) (
	SrcFile=$@ChangeExtension[ "$@UnQuote[$VideoSource$]$@right[-$@len[$router/Videos],$file]",*]
	iff IsFile "$SrcFile" then
		file=
		LeaveFor
	endiff
	echos .
)

# Clean file if not found in a source
iff defined file then
	echo.
	echo del /p "$file"
endiff

return

:RouterConvert

# - Convert Videos from all video sources
for $dir in ($videoSources) gosub RouterConvertVideo $dir

return

# Convert video files for use on DLNA devices.  Note very short videos will not be converted and must be deleted manually.
:RouterConvertVideo [source]

DestPrefix=$router/Videos
SrcPrefix=$@UnQuote[$source]

if "$SrcPrefix" == "" return

echo Converting $source mts video files to mp4 and copying to the router...

osd /c >& nul:

pushd "$SrcPrefix"

# Get counts
current=0
total=0
echos Calculating the number of videos to convert...
for /r $src in ("*.mts") (
	dest=$@ChangeExtension[ "$DestPrefix$$@right[-$@len[$SrcPrefix],$src]" , mp4]

	iff not IsFile "$dest" then 
		total=$@eval[ $total + 1 ]
		echos .
	endiff
)
echo $total videos

# convert
for /r $src in ("*.mts") (
	dest=$@ChangeExtension[ "$DestPrefix$$@right[-$@len[$SrcPrefix],$src]" , mp4]
	
	iff not IsFile "$dest" then 
		current=$@eval[ $current + 1 ]
		osd /n /time=60 Converting $@name[$src] ($current of $total)... 
		handbrake convert DLNA "$src" "$dest"
		result=$?
		osd /c >& nul:
		
		iff $result != 0 then
			EchoErr Could not convert $src ($@FileSize["$src",K]K). 
			echo HandBrake does not convert small video files and exits with "No title found."
			
			ask `Do you want to play this video file?` n
			if $? == 1 "$src"
			
			ask `Do you want to delete this video file?` n
			if $? == 1 DelFile "$src"
		endiff
		
	endiff
)

popd

return

:RouterCheck

pushd C:/dev/media1/videos/Camera/John

echo Files requiring conversion:
for /r $file in (*.wmv *.mpg) (
	dest=$@ChangeExtension[ "$file" , mp4]
	iff not IsFile "$dest" then
		echo $file
	endiff
)

return

:nas

# Arguments
if $@IsHelpArg[$@UnQuote[$1]] == 1 goto usage

iff $@IsHostAvailable[$nas] == 0 then
	EchoErr Could not find the NAS server
	return 1
endiff

command=all
iff $# gt 0 then
	command=$1
	shift
endiff
if not IsLabel Nas$command goto usage

gosub Nas$command
return $_?

:NasAll

ask `Sync install?` n
if $? == 1 gosub NasInstall

ask `Sync media?` n
if $? == 1 gosub NasMedia

ask `Sync books?` n
if $? == 1 gosub NasBooks

return

:NasMedia
BeyondCompare start "$mediaUnc/Music" "$nas/music" /filters`=`$musicFilters
BeyondCompare start "$mediaUnc/Pictures" "$nas/photo"
BeyondCompare start "$mediaUnc/Videos" "$nas/video"
return

:NasInstall
BeyondCompare start "$mediaUnc/Documents/data/install" "$nas/public/documents/data/install"
return

:NasBooks
ask `Update OPD2 catalog?` n
if $? == 1 calibre.btm opds
BeyondCompare start "$UserData/books" "$nas/web/books"
return
