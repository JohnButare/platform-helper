#!/bin/bash
. app.sh || exit

usage()
{
	echot "\
usage: profile [backup|restore|dir|SaveDir](dir)
	Profile services for batch files
	backup|restore [profile](default)
	-a|--app NAME					name of the application
	-f|--files FILE...		for directory profiles, file patterns in the profile
	-m|--method	<dir>|<program>|<key>
	-se|--save-extension  for program profiles, the profile extension used by the program"
	exit $1
}

args()
{
	unset app files method profile saveExtension
	while (( $# != 0 )); do
		case "$1" in
			-a|--app) app="$2"; shift;;
			-f|--files) files="$2"; shift;;
			-m|--method) method="$2"; shift;;
			-se|--save-extension) saveExtension="$2"; shift;;
			-h|--help) IsFunction "${command}Usage" && ${command}Usage || usage 0;;
			SaveDir) command="SaveDir";;
			*)
				[[ ! $command ]] && IsFunction "${1,,}Command" && { command="${1,,}"; shift; continue; }
				! IsOption "$1" && [[ ! $profile &&  "${command}" == @(backup|restore) ]] && { profile="$1"; shift; continue; }
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
		
		[[ ! $saveExtension ]] && { EchoErr "The profile save extension was not specified"; return 2; }
		
	# Registry profile - profile contains registry entries
	elif registry IsKey "$method";  then
		methodType="registry"
	  profileKey="$method"
		saveExtension=reg
		
	else
		echo "Unknown profile method $method"
		return 2
		
	fi

	method="$methodType"
	userProfileDir="$HOME/Documents/data/profile"
	defaultProfileDir="$userProfileDir/default"
	profileSaveDir="$userProfileDir/$app"
	replicateProfile="$defaultProfileDir/$app Profile.$saveExtension"
}

run() {	args "$@"; init || return; ${command}Command "${args[@]}"; }

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
	if [[ -d "$profileSaveDir" ]]; then
		echo "$profileSaveDir"
	elif [[ -d "$userProfileDir" ]]; then
		echo "$userProfileDir"		
	else
		echo "The profile save directory ~/Documents/data/profile does not exist"
	fi
}

backupCommand()
{
	local src="$profileDir" dest="$profileSaveDir" file

	if [[ $profile ]]; then
		file="$profile.$saveExtension"
	else
		file="${COMPUTERNAME,,} $app Profile $(GetTimeStamp).$saveExtension"
	fi

	mkdir --parents "$dest" || return

	# backup specified files to a zip file
	if [[ "$method" ==  "file" && -d "$src" ]]; then
		printf 'Backing up %s profile to "%s"...\n' "$app" "$file"
		pushd "$src" > /dev/null || return
		! zip.exe -Sr "$(utw "$dest/$file")" $files || return
		popd > /dev/null || return

	# Backup using the specified import/export program		
	elif [[ "$method" == "program" ]]; then
		clipw "$(utw "$dest/$file")"
		echo "Export the profile to the filename contained in the clipboard"
		ask "Start $(GetFilename "$profileProgram")" && { start "$profileProgram" || return; }
		pause
		
	# Backup the registry
	elif [[ "$method" == "registry" ]]; then
		printf 'Backing up %s profile to "%s"...' "$file" "$app"
		registry export "$profileKey" "$(utw "$dest/$file")" || return
		echo "done"
		
	fi
		
	# Copy the default profile to the replicate directory
	if [[ "$file" == "default.$saveExtension" && -f "$dest/$file" && -d "$defaultProfileDir" ]]; then
		printf "Copying the default profile..."
		cp "$dest/$file" "$replicateProfile" || return
		echo "done"
	fi
}

restoreCommand()
{
	[[ ! $profile || "$profile" == "default" ]] && profile="$replicateProfile"

	[[ "$(GetExtension "$profile")" == "" ]] && profile+=".$saveExtension"
	[[ "$(GetPath "$profile")" == "" ]] && profile="$profileSaveDir/$profile"
	local filename; GetFilename "$profile" filename
	
	[[ ! -f "$profile" ]] && { EchoErr "The profile \"$filename\" does not exist"; return 2; }

	! ask "Do you want to restore $app profile \"$filename\"?" -dr n && return 0

	if [[ "$method" == "file" ]]; then
		AppClose "$app" || return
		unzip.exe -o "$(utw "$profile")" -d "$(utw "$profileDir")" || return
		AppStart "$app" || return

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
