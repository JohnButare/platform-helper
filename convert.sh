#!/bin/bash

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
