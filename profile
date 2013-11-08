#!/bin/bash
. app.sh || exit

usage()
{
	echot "\
usage: profile [save|restore|dir|SaveDir|CopyGlobal](dir)
	Profile services for batch files
	save|restore [profile](default)
	-a|--app NAME					name of the application
	-f|--files FILE...		for directory profiles, file patterns in the profile
	-g|--global 					use the global profile in install/bootstrap/profile
	-m|--method	<dir>|<program>|<key>
	-se|--save-extension  for program profiles, the profile extension used by the program"
	exit $1
}

args()
{
	unset app files global method profile saveExtension
	while (( $# != 0 )); do
		case "$1" in
			-a|--app) app="$2"; shift;;
			-f|--files) files="$2"; shift;;
			-g|--global) global="--global";;
			-m|--method) method="$2"; shift;;
			-se|--save-extension) saveExtension="$2"; shift;;
			-h|--help) IsFunction "${command}Usage" && ${command}Usage || usage 0;;
			CopyGlobal) command="CopyGlobal";; SaveDir) command="SaveDir";;
			*)
				[[ ! $command ]] && IsFunction "${1,,}Command" && { command="${1,,}"; shift; continue; }
				! IsOption "$1" && [[ ! $profile &&  "${command}" == @(save|restore) ]] && { profile="$1"; shift; continue; }
				UnknownOption "$1"
		esac
		shift
	done
	[[ ! $command ]] && command='dir'
	[[ ! $app ]] && MissingOperand "app"
	args=("$@")
}

init()
{
	local methodType

	# Profile files - profile contains ZIP of specified files
	if [[ -d "$method" ]]; then
		methodType="file"
		profileDir="$method"
		saveExtension="zip"

	# ProfileFiles program - program it will be used to import and export the profile  
	# IN: profileDir, profileSaveExtension -  the profile file extension used by the program must be specified
	elif [[ -f "$method" && "$(GetExtension "$method")" == "exe" ]]; then
		methodType="program"
		profileProgram="$method"
		
		[[ ! $saveExtension ]] && { EchoErr "The profile save extension was not specified"; return 1; }
		
	# Registry profile - profile contains registry entries
	elif registry IsKey "$method";  then
		methodType="registry"
	  profileKey="$method"
		saveExtension=reg
		
	else
		echo "Unknown profile method $method"
		return 1
		
	fi

	method="$methodType"
	profileSaveDir="$HOME/Documents/data/profile"
	appProfileSaveDir="$profileSaveDir/$app"
	userProfileSaveDir="$profileSaveDir/default"
	userProfile="$userProfileSaveDir/$app Profile.$saveExtension"
}

run() {	args "$@"; init || return; ${command}Command "${args[@]}"; }

CopyGlobalCommand()
{
	findGlobalProfile || return

	[[ ! -f "$userProfile" ]] && { EchoErr "profile: cannot access user profile \`$userProfile\`: No such file"; return 1; }
	cp "$userProfile" "$globalProfile" || return
}

findGlobalProfile()
{
	 globalProfileSaveDir="$(FindInstallFile "bootstrap/profile")" || return
	 globalProfile="$globalProfileSaveDir/$app Profile.$saveExtension"
}

dirCommand()
{
	case "$method" in
		file) echo "$profileDir";;
		program) start "$profileProgram";;
		registry) registry edit "$profileKey";;
	esac
}

SaveDirCommand()
{
	if [[ $global ]]; then
		findGlobalProfile || return
		echo "$globalProfileSaveDir"
	elif [[ -d "$appProfileSaveDir" ]]; then
		echo "$appProfileSaveDir"
	elif [[ -d "$profileSaveDir" ]]; then
		echo "$profileSaveDir"		
	else
		echo "The profile save directory ~/Documents/data/profile does not exist"
	fi
}

saveCommand()
{
	local src="$profileDir" dest="$appProfileSaveDir" file

	if [[ $profile ]]; then
		file="$profile.$saveExtension"
	else
		file="${COMPUTERNAME,,} $app Profile $(GetTimeStamp).$saveExtension"
	fi

	mkdir --parents "$dest" || return

	# save specified files to a zip file
	if [[ "$method" ==  "file" && -d "$src" ]]; then
		printf 'Backing up %s profile to "%s"...\n' "$app" "$file"
		pushd "$src" > /dev/null || return
		zip.exe -Sr "$(utw "$dest/$file")" $files || return
		popd > /dev/null || return

	# save using the specified import/export program		
	elif [[ "$method" == "program" ]]; then
		clipw "$(utw "$dest/$file")"
		echo "Export the profile to the filename contained in the clipboard"
		ask "Start $(GetFilename "$profileProgram")" && { start "$profileProgram" || return; }
		pause
		
	# save the registry
	elif [[ "$method" == "registry" ]]; then
		printf 'Backing up %s profile to "%s"...' "$file" "$app"
		registry export "$profileKey" "$(utw "$dest/$file")" || return
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

copyDefaultProfile()
{
	local src="$1" dest="$2" destDir

	GetPath "$dest" destDir || return
	[[ ! -d "$destDir" ]] && { MakeDir --parents "$destDir" || return; }

	printf "Copying profile to $destDir..."
	cp "$src" "$dest" || return
	echo "done"
}

restoreCommand()
{
	local globalDescription=" "
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

	[[ "$(GetExtension "$profile")" == "" ]] && profile+=".$saveExtension"
	[[ "$(GetPath "$profile")" == "" ]] && profile="$appProfileSaveDir/$profile"
	local filename; GetFilename "$profile" filename
	
	[[ ! -f "$profile" ]] && { EchoErr "profile: cannot access profile \`$filename\`: No such file"; return 1; }

	! ask "Restore $app$globalDescription profile \"$filename\"?" -dr n && return 0

	if [[ "$method" == "file" ]]; then
		local isRunning;
		AppIsRunning "$app" && { isRunning="true"; AppClose "$app" || return; }
		unzip.exe -o "$(utw "$profile")" -d "$(utw "$profileDir")" || return
		[[ $isRunning ]] && { AppStart "$app" || return; }

	elif [[ "$method" == "program" ]]; then
		clipw "$(utw "$profile")"
		echo "Import the profile using the filemame contained in the clipboard"
		ask "Start $(GetFilename "$profileProgram")" && { start "$profileProgram" || return; }
		pause

	elif [[ "$method" == "registry" ]]; then
		AppClose "$app" || return
		registry import "$profile" || return
		AppStart "$app" || return

	fi

	echo "$app profile \"$filename\" has been restored"

	return 0
}

run "$@"
