#!/usr/bin/env bash
. script.sh || exit
. color.sh || exit
. AppControl.sh || exit

usage()
{
	echot "\
usage: profile [save|restore|dir|SaveDir|CopyGlobal](dir)
	Profile services for batch files
	save|restore [profile](default)

	-a,  --app NAME					name of the application
	-f,  --files FILE...		for directory profiles, file patterns in the profile
	-g,  --global 					use the global profile in install/bootstrap/profile
	-m,  --method	<dir>|<program>|<key>
	-nc, --no-control				do not control the applciation
	-p,  --platform 				use platform specific unzip
	-se, --save-extension  	for program profiles, the profile extension used by the program
	-s,  --sudo  						restore the profile as the root user"
	exit $1 
}

init() { defaultCommand="dir"; }
argStart() { unset -v app files global method noControl platform profile saveExtension sudo; }

argEnd()
{
	[[ ! $force && ! $noControl ]] && AppHasHelper "$app" && { AppInstallVerify "$app" || return; }
	[[ ! $method ]] && MissingOption "method"

	# Registry profile - profile contains registry entries
	if IsPlatform win && CanElevate && registry IsKey "$method";  then
		methodType="registry"
		profileKey="$method"
		saveExtension=reg

	# ProfileFiles program - program it will be used to import and export the profile  
	# IN: profileDir, profileSaveExtension -  the profile file extension used by the program must be specified
	elif which "$method" > /dev/null ; then
		methodType="program"
		profileProgram="$method"
		
		[[ ! $saveExtension ]] && { ScriptErr "the profile save extension was not specified"; return 1; }

	# Profile files - profile contains ZIP of specified files
	elif [[ ! -f "$method" && -d "$(GetParentDir "$(EnsureDir "$method")")" ]]; then
		[[ ! -d "$method" ]] && { mkdir "$method" || return; }
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
	cloudProfileSaveDir=""; CloudConf && cloudProfileSaveDir="$CLOUD/network/profile/"
}

opt()
{
	case "$1" in
		-a|--app) ScriptOptGet "app" "$@";;
		-F|--files|-F=*|--files=*) ScriptOptGet "files" "$@";;
		-g|--global) global="--global";;
		-m|--method) ScriptOptGet "method" "$@";;
		-nc|--no-control) noControl="--no-control";;
		-p|--platform) platform="--platform";;
		-se|--save-extension|-se=*|--save-extension=*) ScriptOptGet "saveExtension" "$@";;
		-s|--sudo) sudo="sudo";;
		*) return 1;;
	esac
}

copyGlobalCommand()
{
	findGlobalProfile || return
	[[ ! -f "$userProfile" ]] && { ScriptErr " cannot access user profile \`$userProfile\`: No such file"; return 1; }
	cp "$userProfile" "$globalProfile" || return
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
	local globalDescription

	if [[ ! $profile || "$profile" == "default" ]]; then

		if [[ $global || ! -f "$userProfile" ]]; then
			findGlobalProfile || return
			profile="$globalProfile"
			globalDescription=" global"
		else
			profile="$userProfile"
		fi
		[[ ! -f "$profile" ]] && { echo "profile: no default $app profile found"; return 0; }
		
	fi

	[[ "$(GetFileExtension "$profile")" == "" ]] && profile+=".$saveExtension"
	[[ "$(GetFilePath "$profile")" == "" ]] && profile="$appProfileSaveDir/$profile"
	local filename; GetFileName "$profile" filename
	
	[[ ! -f "$profile" ]] && { ScriptErr "cannot access profile \`$filename\`: No such file"; return 1; }

	! askp "Restore $app$globalDescription profile \"$filename\"" -dr n && return 0

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
		clipw "$(utw "$dest/$file")"
		echo "Export the profile to the filename contained in the clipboard"
		askp "Start $(GetFileName "$profileProgram")" && { start "$profileProgram" || return; }
		pause
		
	# save the registry
	elif [[ "$method" == "registry" ]]; then
		printf 'Backing up to "%s"...' "$file"
		registry export "$profileKey" "$dest/$file" $verbose || return
		echo "done"
		
	fi
		
	# Copy the default profile to the replicate directory
	if [[ "$file" == "default.$saveExtension" && -f "$dest/$file" ]]; then
		if [[ $global ]]; then
			findGlobalProfile || return
			copyDefaultProfile "$dest/$file" "$globalProfile" || return
		else
			copyDefaultProfile "$dest/$file" "$userProfile" || return
		fi
	fi

}

savedirCommand()
{
	if [[ $global ]]; then
		findGlobalProfile || return
		echo "$globalProfileSaveDir"
	elif [[ -d "$appProfileSaveDir" ]]; then
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

askp()
{
	if [[ $noPrompt ]]; then
		echo "${GREEN}$1...${RESET}"
	else
		ask "$1"
	fi
}

copyDefaultProfile()
{
	local src="$1" dest="$2"

	# backup
	if [[ -f "$dest" && [[ $cloudProfileSaveDir && -d "$cloudProfileSaveDir" ]]; then
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

findGlobalProfile()
{
	 globalProfileSaveDir="$(FindInstallFile "profile")" || return
	 globalProfile="$globalProfileSaveDir/$app Profile.$saveExtension"
}

ScriptRun "$@"