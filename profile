#!/usr/bin/env bash
. "${BASH_SOURCE[0]%/*}/function.sh" script color AppControl || exit

usage()
{
	echot "\
usage: profile [save|restore|dir|SaveDir](dir)
	Profile services for batch files
	save|restore [profile](default)

	-a,  --app NAME					name of the application
	,e,  --editor						copy text to an editor for profile save
	-f,  --files FILE...		for directory profiles, file patterns in the profile
	-m,  --method	<dir>|<program>|<key>
	-nc, --no-control				do not control the applciation
	-p,  --platform 				use platform specific unzip
	-se, --save-extension  	for program profiles, the profile extension used by the program
	-s,  --sudo  						restore the profile as the root user"
	exit $1 
}

argStart() { unset -v app editor files method noControl platform profile saveExtension sudo; }

argEnd()
{
	[[ ! $force && ! $noControl ]] && AppHasHelper "$app" && { AppInstallVerify "$app" || return; }
	[[ ! $method ]] && MissingOption "method"

	# create the profile directory if needed - assume we have a file profile if the parent directory of the method is a directory
	[[ ! -f "$method" && -d "$(GetParentDir "$(EnsureDir "$method")")" && ! -d "$method" ]] && { mkdir "$method" || return; }

	# registry - profile contains registry entries
	if IsPlatform win && CanElevate && registry IsKey "$method";  then
		methodType="registry"
		profileKey="$method"
		saveExtension=reg

	# program - program it will be used to import and export the profile  
	# IN: profileDir, profileSaveExtension -  the profile file extension used by the program must be specified
	elif which "$method" > /dev/null ; then
		methodType="program"
		profileProgram="$method"
		
		[[ ! $saveExtension ]] && { ScriptErr "the profile save extension was not specified"; return 1; }

	# files - profile contains ZIP of specified files
	elif [[ -d "$method" ]]; then
		methodType="file"
		profileDir="$method"
		saveExtension="zip"

	else
		ScriptErr "unknown profile method '$method'"
		return 1
		
	fi

	method="$methodType"
	profileSaveDir="$UDATA/profile"
	appProfileSaveDir="$profileSaveDir/$app"
	userProfileSaveDir="$profileSaveDir/default"
	userProfile="$userProfileSaveDir/$app Profile.$saveExtension"	
	cloudProfileSaveDir=""; CloudConf --quiet && cloudProfileSaveDir="$CLOUD/network/profile/"

	return 0
}

opt()
{
	case "$1" in
		-a|--app) ScriptOptGet "app" "$@";;
		-e|--editor) editor="--editor";;
		-F|--files|-F=*|--files=*) ScriptOptGet "files" "$@";;
		-m|--method) ScriptOptGet "method" "$@";;
		-nc|--no-control) noControl="--no-control";;
		-p|--platform) platform="--platform";;
		-se|--save-extension|-se=*|--save-extension=*) ScriptOptGet "saveExtension" "$@";;
		-s|--sudo) sudo="sudo";;
		*) return 1;;
	esac
}

dirCommand()
{
	case "$method" in
		file) echo "$profileDir";;
		program) start "$profileProgram";;
		registry) registry edit $verbose "$profileKey";;
	esac
}

restoreArgs() { ScriptArgGet "profile" -- "$@"; shift; }

restoreCommand()
{
	if [[ ! $profile || "$profile" == "default" ]]; then
		profile="$userProfile"
		[[ ! -f "$profile" ]] && { echo "profile: no default $app profile found"; return 0; }
	fi

	[[ "$(GetFileExtension "$profile")" == "" ]] && profile+=".$saveExtension"
	[[ "$(GetFilePath "$profile")" == "" ]] && profile="$appProfileSaveDir/$profile"
	local filename; GetFileName "$profile" filename
	
	[[ ! -f "$profile" ]] && { ScriptErr "cannot access profile \`$filename\`: No such file"; return 1; }

	! askp "Restore $app profile \"$filename\"" -dr n && return 0

	if [[ "$method" == "file" ]]; then
		[[ ! $noControl ]] && { AppCloseSave "$app" || return; }

		if [[ $platform ]]; then
			$sudo UnzipPlatform "$profile" "$profileDir" || return
		else
			$sudo unzip  -o "$profile" -d "$profileDir" || return
		fi
		[[ ! $noControl ]] && { AppStartRestore "$app" || return; }
		
	elif [[ "$method" == "program" ]]; then
		[[ $noPrompt ]] && return
		clipw "$(utw "$profile")"
		echo "Import the profile using the filemame contained in the clipboard"
		askp "Start $(GetFileName "$profileProgram")" && { start --wait "$profileProgram" || return; }

	elif [[ "$method" == "registry" ]]; then
		[[ ! $noControl ]] && AppCloseSave "$app" || return
		registry import $verbose "$profile" || return
		[[ ! $noControl ]] && AppStartRestore "$app" || return

	fi

	echo "$app profile \"$filename\" has been restored"

	return 0
}

saveArgs() { ! [[ $@ ]] && return; ScriptArgGet "profile" -- "$@"; }

saveCommand()
{
	local src="$profileDir" dest="$appProfileSaveDir" file status

	if [[ $profile ]]; then
		file="$profile.$saveExtension"
	else
		file="$(echo "$HOSTNAME" | RemoveDnsSuffix | ProperCase) $app Profile $(GetTimeStamp).$saveExtension"		
	fi

	${G}mkdir --parents "$dest" || return

	# save specified files to a zip file
	if [[ "$method" ==  "file" && -d "$src" ]]; then
		printf 'Backing up to "%s"...\n' "$file"
		
		pushd "$src" > /dev/null || return
		zip -r "$dest/$file" $files -x "*.*_sync.txt*" -x Cache/\* -x htdocs/netboot.xyz/\* # Cache (Sublime Cache)
		status="$?"
		popd > /dev/null || return
		[[ "$status" != "0" ]] && return "$status"

	# save using the specified import/export program		
	elif [[ "$method" == "program" ]]; then		
		if [[ $editor ]]; then
			touch "$dest/$file" || return
			echo "Copy the profile to the text editor"
		else
			clipw "$(utw "$dest/$file")"
			echo "Export the profile to the filename contained in the clipboard"
		fi		
		askp "Start $(GetFileName "$profileProgram")" && { start "$profileProgram" || return; }
		[[ $editor ]] && { TextEdit "$dest/$file" || return; }
		pause
		
	# save the registry
	elif [[ "$method" == "registry" ]]; then
		printf 'Backing up to "%s"...' "$file"
		registry export "$profileKey" "$dest/$file" $verbose || return
		echo "done"
		
	fi
		
	# Copy the default profile to the replicate directory
	[[ "$file" == "default.$saveExtension" && -f "$dest/$file" ]] && { copyDefaultProfile "$dest/$file" "$userProfile" || return; }

	return 0
}

savedirCommand()
{
	if [[ -d "$appProfileSaveDir" ]]; then
		echo "$appProfileSaveDir"
	elif [[ -d "$profileSaveDir" ]]; then
		echo "$profileSaveDir"		
	else
		echo "The profile save directory $UDATA/profile does not exist"
	fi
}

#
# helper
#

askp() { [[ $noPrompt ]] && echo "${GREEN}$1...${RESET}" || ask "$1"; }

copyDefaultProfile()
{
	local src="$1" dest="$2"

	# backup
	if [[ -f "$dest" && $cloudProfileSaveDir && -d "$cloudProfileSaveDir" ]]; then
		copyProfile "$src" "$cloudProfileSaveDir/$(GetFileName "$dest")" || return
	fi

	# copy
	copyProfile "$src" "$dest" || return
}

copyProfile()
{
	local srcFile="$1" destFile="$2"
	local destDir="$(GetFilePath "$destFile")"; [[ ! -d "$destDir" ]] && { ${G}mkdir --parents "$destDir" || return; }

	printf "Copying profile to $(FileToDesc "$destDir")..."
	cp "$srcFile" "$destFile" || return
	echo "done"
}

ScriptRun "$@"