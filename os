#!/usr/bin/env bash
. function.sh

usage()
{
	echot "\
usage: os <command>[environment|index|lock|store|SystemProperties|version]
	HostName|SetHostName
	path [show|edit|editor|set [AllUsers]](editor)
	index: index [options|start|stop|demand](options)"
	exit $1
}

args()
{
	command=""
	
	while [ "$1" != "" ]; do
		case "$1" in
			-h|--help) IsFunction "${command}Usage" && ${command}Usage 0 || usage 0;;		
	 		SystemProperties) command="SystemProperties";;
			SetHostName) command="SetHostname";;
			*) 
				IsFunction "${1,,}Command" && { command="${1,,}"; shift; continue; }
				[[ "$command" == @(hostname|path|update) ]] && break
				UnknownOption "$1"
		esac
		shift
	done
	[[ ! $command ]] && usage 1
	args=("$@")
}

run() {	args "$@"; ${command}Command "${args[@]}"; }

environmentCommand() { SystemPropertiesCommand 3; }

indexCommand()
{
	case "$PLATFORM" in
		win) rundll32.exe shell32.dll,Control_RunDLL srchadmin.dll,Indexing Options &;;
	esac
}

lockCommand()
{
	case "$PLATFORM" in
		mac) "/System/Library/CoreServices/Menu Extras/User.menu/Contents/Resources/CGSession" -suspend;;
	esac
}

storeCommand()
{ 
	case "$PLATFORM" in
		win) start "" "ms-windows-store://";;
	esac
}	

SystemPropertiesCommand()
{
	case "$PLATFORM" in
		win)
			local tab=; [[ $1 ]] && tab=",,$1"; 
			rundll32.exe /d shell32.dll,Control_RunDLL SYSDM.CPL$tab
			;;
	esac
}

#
# hostname
#

hostnameCommand()
{
	local host="$1" name

	# use HOSTNAME for localhost
	IsLocalHost "$host" && { echo "$HOSTNAME"; return 0; }

	# use reverse DNS lookup for IP Address
	if IsIpAddress "$host"; then
		name="$(RemoveDnsSuffix $(nslookup $host |& grep "name =" | cut -d" " -f 3))"
		[[ $name ]] && { echo "$name"; return ; }
	fi

	# cached names for speed
	case "$host" in
		nas1) echo "nas1"; return 0;; 
		nas2) echo "nas2"; return 0;; 
		nas3) echo "nas3"; return 0;; 
	esac

	# ssh port 608
	if IsAvailablePort $host 608 1; then
		name="$(RemoveSpace $(RemoveDnsSuffix $(ssh -p 608 $host hostname)))"
		[[ $name ]] && { echo "$name"; return ; }
	fi

	# ssh port 22
	if IsAvailablePort $host 22 1; then
		name="$(RemoveSpace $(RemoveDnsSuffix $(ssh -p 22 $host hostname)))"
		[[ $name ]] && { echo "$name"; return ; }
	fi

	# fallback on the name passed
	[[ ! $name ]] && name="$host"

	echo "$name"	
}

SetHostnameCommand()
{
	local newName
	read -p "Enter computer name: " newName; echo
	[[ ! $newName ]] && return

	if IsPlatform raspbian; then sudo raspi-config nonint do_hostname $newName
	elif IsPlatform mac; then sudo scutil --set HostName $newName
	elif IsPlatform win; then elevate RunScript --pause-error "$WINDIR/system32/WindowsPowerShell/v1.0/powershell.exe" Rename-Computer -NewName "$newName"
	elif InPath hostnamectl; then sudo hostnamectl set-hostname $newName
	elif IsPlatform linux; then sudo hostname -s $newName
	fi
}

#
# path 
#

PathEditCommand() { SystemPropertiesCommand 3; }
PathEditorCommand() { start --elevate PathEditor; }

pathCommand()
{
	command="show"
	[[ $# > 0 ]] && ProperCase "$1" s; IsFunction Path${s}Command && { command="$s"; shift; }
	[[ $command != @(editor) && $# != 0 ]] && UnknownOption "$1"
	Path${command}Command "$@"
}

#
# os version
#

versionCommand() {  RunPlatform version || return; }

versionMac()
{
	local version="$(system_profiler SPSoftwareDataType | grep "System Version" | cut -f 10 -d" ")"
	local build="$(system_profiler SPSoftwareDataType | grep "System Version" | cut -f 11 -d" " | sed 's/(//' | sed 's/)//' )"
	local codeName

	case "$version" in
		"10.15") codeName="Mojave";;
		"10.16") codeName="Catalina";;
		*) codeName="?";;
	esac

	echo "macOS $version ($codeName build $build)"
}

versionDebian()
{
	local platform="$PLATFORM $PLATFORM_LIKE $PLATFORM_ID"

	if ! InPath lsb_release; then
		echo "$platform"
		return 0
	fi

	local release="$(lsb_release -a |& grep Description | cut -f 2- | sed 's/ (buster)//')"
	local codeName="$(lsb_release -a |& grep Codename | cut -f 2-)"

	! IsPlatform ubuntu && codeName+=" $(cat /etc/debian_version)"

	echo "$release ($codeName, $platform)"
}

versionRaspbian()
{
	cpu=$(</sys/class/thermal/thermal_zone0/temp)
	echo "CPU Temperature $((cpu/1000))'C"
}

versionWin()
{
	local r="HKEY_LOCAL_MACHINE/SOFTWARE/Microsoft/Windows NT/CurrentVersion"
	local releaseId="$(registry get "$r/ReleaseID" | RemoveCarriageReturn)"
	local ubr="$(HexToDecimal "$(registry get "$r/UBR" | RemoveCarriageReturn)")"
	local build="$(registry get "$r/CurrentBuild" | RemoveCarriageReturn)"

	echo "Windows Version $releaseId (OS Build $build.$ubr, WSL $(IsWsl2 && echo 2 || echo 1) $PLATFORM_LIKE-$PLATFORM_ID)"
}

run "$@"
