
iff "$@search[$app.btm]" != "" then
	$app close >& nul:
fi

# Restore profile from zip file
iff "$method" == "file" then
	unzip.exe -o "$profile" -d "$profileDir"
	
# Restore using the specified import/export program
elif "$method" == "program" then
	echo $@ClipW[$profile] > nul
	echo Import the profile using the filemame contained in the clipboard.
	start /pgm "$ProfileProgram"
	pause

elif "$method" == "registry" then
	regedit /s "$profile"

fi

echo $app profile "$@FileName[$profile]" has been restored.

iff "$@search[$app.btm]" != "" then
	$app start >& nul:
fi
