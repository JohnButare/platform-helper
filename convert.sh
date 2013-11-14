#!/bin/bash

# copy to nas if present, else copy to local public
# if not on oversoul, use local public dirs as a source and if in right format do not rename files, ignore collection directory
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
# copy to nas if available?
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

:sync
media nas all
# WindowsMediaPlayer SyncPlaylist
# AmazonMp3 sync
# WindowsMediaPlayer sync
# media router sync
return $?

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

:nas
merge "$mediaUnc/Documents/data/install" "$nas/public/documents/data/install" || return
merge "$mediaUnc/Music" "$nas/music" "/filters=$musicFilters" || return
merge "$mediaUnc/Pictures" "$nas/photo" || return
merge "$mediaUnc/Videos" "$nas/video" || return
#ask 'Update books' && { calibre opds; merge "$UserData/books" "$nas/web/books"; }
return
