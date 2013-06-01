{
	if ($1 == "OLD") 
		old = -1
	else if ($1 == "NEW") 
		old = 0
	else if ($1 == "Volume" || $1 == "" || $3 == "<DIR>") 
		;
	else if ($1 == "Directory") 
		dir = substr($0, 16, length($0) - 17);
	else if (old) {
		file = substr($0, 34)
		fileOldA[dir,file] = $1 " " $2 " " $3
	} else {
		file = substr($0, 34)
		fileNewA[dir,file] = $1 " " $2 " " $3
	}
}

END {
	for (key in fileOldA) {
		if (key in fileNewA) {
			;
		} else {
			print "DELETE: " keyToFile(key) " (" fileOldA[key] ")"
		}
	}
	
	for (key in fileNewA) {
		if (key in fileOldA) {
			if (fileOldA[key] != fileNewA[key]) 
				print "CHANGE: " keyToFile(key) " (" fileOldA[key] ") to (" $1 " " $2 " " $3 ")"
		} else {
			print "ADD: " keyToFile(key) " (" fileNewA[key] ")"
		}
	}

}

function keyToFile(key   , keyA)
{
	split(key, keyA, SUBSEP)
	return(keyA[1] "\\" keyA[2])
}
