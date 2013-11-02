#!/bin/bash
. function.sh

	
	pushd "/cygdrive/d/users/Public/Documents/data/install/sun/Java/jre"

	local result items
	for file in jre*; do items+=( "$file" "" "off" ) done
 
	result=$(dialog --stdout \
		--backtitle "Select Installation Files" \
  	--radiolist "Choose file to install:" $(($LINES-5)) 50 $(($LINES)) "${items[@]}")
	clear

echo "$result"
	