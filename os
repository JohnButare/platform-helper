#!/usr/bin/env bash
. function.sh

run() {	args "$@"; ${command}Command "${args[@]}"; }

usage()
{
	echot "\
usage: os [environment|index|lock|store|SystemProperties|version]
	hostname|SetHostname
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
	 		CodeName) command="codeName";; SystemProperties) command="systemProperties";; SetHostname) command="setHostname";;
			*) 
				IsFunction "${1,,}Command" && { command="${1,,}"; shift; continue; }
				[[ "$command" == @(CodeName|hostname|path|update|SetWorkgroup) ]] && break
				UnknownOption "$1"
		esac
		shift
	done
	[[ ! $command ]] && usage 1
	args=("$@")
}

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

systemPropertiesCommand()
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

	# reverse DNS lookup for IP Address
	if IsIpAddress "$host"; then
		name="$(RemoveDnsSuffix $(nslookup $host |& grep "name =" | cut -d" " -f 3))"
		[[ $name ]] && { echo "$name"; return ; }
	fi

	# forward DNS lookup
	InPath host && name=$(host $host | grep " has address ") && { echo "$(RemoveDnsSuffix $name)"; return; }

	# fallback on the name passed
	echo "$(RemoveDnsSuffix $host)"
}

setHostnameCommand()
{
	local newName
	read -p "Enter computer name: " newName; echo
	[[ ! $newName ]] && return

	if IsPlatform raspbian; then sudo raspi-config nonint do_hostname $newName
	elif IsPlatform mac; then sudo scutil --set HostName $newName
	elif IsPlatform win; then elevate RunScript --pause-error powershell Rename-Computer -NewName "$newName"
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

codeNameCommand() { InPath lsb_release && lsb_release -a |& grep "Codename:" | cut -f 2-; }

versionDebian()
{
	local platform="$(PlatformDescription)" distributor version codename hardware

	if ! InPath lsb_release; then
		echo "$platform"
		return 0
	fi

	# Distributor
	distributor="$(lsb_release -a |& grep "Distributor ID:" | cut -f 2-)"
	IsPlatform raspbian && distributor+="/Debian"

	# Version
	version="$(codeNameCommand)"
	IsPlatform ubuntu && version="$(lsb_release -a |& grep "Description:" | cut -f 2- | sed 's/'$distributor' //')"
	IsPlatform raspbian && [[ -f /etc/debian_version ]] && version="$(cat /etc/debian_version)"
	
	# Code Name
	codename="$(lsb_release -a |& grep "Codename:" | cut -f 2-)"

	# hardware
	# uname -m: armv71, x86_64, mips, mip64
	# dpkg --print-architecture: amd64, armhf
	hardware="$(uname -m)" 
	InPath dpkg && hardware+=" ($(dpkg --print-architecture))"

	echo "distribution: $distributor $version ($codename)"
	echo "    platform: $platform"
	echo "      kernel: $(uname -r)"
	echo "    hardware: $hardware" 
	[[ -f "/etc/debian_chroot" ]] && echo "      chroot: $(cat "/etc/debian_chroot")"
	IsVm && echo "          vm: $(VmType)"
	return 0
}

versionRaspbian()
{
	cpu=$(</sys/class/thermal/thermal_zone0/temp)
	echo "    CPU temp: $((cpu/1000))'C"
}

versionWin()
{
	local r="HKEY_LOCAL_MACHINE/SOFTWARE/Microsoft/Windows NT/CurrentVersion"
	local releaseId="$(registry get "$r/ReleaseID" | RemoveCarriageReturn)"
	local ubr="$(HexToDecimal "$(registry get "$r/UBR" | RemoveCarriageReturn)")"
	local build="$(registry get "$r/CurrentBuild" | RemoveCarriageReturn)"

	echo "     windows: $releaseId (build $build.$ubr, WSL $(IsPlatform wsl1 && echo 1 || echo 2))"
}

run "$@"
