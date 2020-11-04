#!/usr/bin/env bash
. function.sh

run() {	args "$@"; ${command}Command "${args[@]}"; }

usage()
{
	echot "\
usage: os [environment|index|lock|store|SystemProperties]
	hostname|SetHostname [NAME]
	path [show|edit|editor|set [AllUsers]](editor)
	index: index [options|start|stop|demand](options)
	architecture|bits|hardware|version 			OS and machine information
	executable															OS executable information
		format 			returns the formmat of the executable (leading text returned by the \`find\` command
		find DIR		return the executables for the current machine in the target directory"
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
				[[ "$command" == @(CodeName|executable|hostname|path|update|SetHostName|SetWorkgroup) ]] && break
				UnknownOption "$1"
		esac
		shift
	done
	[[ ! $command ]] && usage 1
	args=("$@")
}

codeNameCommand() { InPath lsb_release && lsb_release -a |& grep "Codename:" | cut -f 2-; }
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
	IsLocalHost "$host" && host="$HOSTNAME"

	# reverse DNS lookup for IP Address
	if IsIpAddress "$host"; then
		name="$(nslookup $host |& grep "name =" | cut -d" " -f 3)"
		echo "${name:-$host}"; return
	fi

	# forward DNS lookup
	if InPath host; then
		name="$(host $host | grep " has address " | cut -d" " -f 1)"
		echo "${name:-$host}"; return
	fi

	# fallback on the name passed
	echo "$host"
}

setHostnameCommand() # 0=name changed, 1=name unchanged, 2=error
{
	local result

	local newName="$1"; [[ $newName ]] && shift
	[[ ! $newName ]] && { read -p "Enter new host name (current $HOSTNAME): " newName; }
	[[ ! $newName || "$newName" == "$HOSTNAME" ]] && return 1
	
	if IsPlatform pi; then sudo raspi-config nonint do_hostname "$newName" && return 0
	elif IsPlatform mac; then sudo scutil --set HostName "$newName" && return 0
	elif IsPlatform win; then RunScript --elevate -- powershell.exe Rename-Computer -NewName "$newName" && return 0
	elif IsPlatform linux; then
		InPath hostnamectl && { sudo hostnamectl set-hostname "$newName" >& /dev/null && return 0; }
		sudo hostname "$newName" && return 0
	fi

	return 2
}

#
# path 
#

pathCommand()
{
	command="show"
	[[ $# > 0 ]] && ProperCase "$1" s; IsFunction Path${s}Command && { command="$s"; shift; }
	[[ $command != @(editor) && $# != 0 ]] && UnknownOption "$1"
	Path${command}Command "$@"
}

PathEditCommand() { SystemPropertiesCommand 3; }

PathEditorCommand()
{ 
	if IsPlatform win; then
		start --elevate PathEditor.exe
	elif InPath vared; then
		vared PATH
	fi
}

#
# information
#

# architectureCommand - return the machine architecture, one of ARM, MIPS, or x86_64 (Intel/AMD)
architectureCommand()
{
	case "$(hardwareCommand)" in
		armv7l|aarch64) echo "ARM";;
		mips|mip64) echo "MIPS";;
		x86_64) echo "x86-64";;
	esac
}

bitsCommand() # 32 or 64
{
	local bits="32" # assume 32 bit operating system

	if InPath getconf; then bits="$(getconf LONG_BIT)"
	elif InPath lscpu; then lscpu | grep "CPU op-mode(s): 32-bit, 64-bit" >& /dev/null && bits="64"
	else return
	fi

	echo "$bits"
}

# hardware - return the machine hardware, one of:
# armv71|aarch64 	ARM, 32|64 bit
# mips|mip64			MIPS, 32|64 bit
# x86_64 					x86_64 (Intel/AMD), 64 bit
hardwareCommand() ( uname -m; )

#
# executable
#

executableCommand()
{
	local command; CheckSubCommand executable "$1"; shift
	$command "$@"
}

executableInfoCommand()
{
	[[ $# != 0 ]] && UnknownOption "$1"

	IsPlatform mac && { echo "Mach-O $(os bits)-bit $(architectureCommand)"; return; }
	IsPlatform linux,win && { echo "ELF $(os bits)-bit LSB executable, $(architectureCommand)"; return; }
	return 1
}

executableFindCommand()
{
	local dir="$1"; shift; [[ ! $dir ]] && MissingOperand "dir"; 
	[[ $# != 0 ]] && UnknownOption "$1"
	[[ ! -d "$dir" ]] && { ScriptErr "Specified path \`$dir\` does not exit."; }

	file "$dir"/* | grep "$(executableInfoCommand)" | cut -d: -f1
	return "${PIPESTATUS[1]}"
}

#
# version
#

versionCommand()
{
	echo "    platform: $(PlatformDescription)"

	versionDistribution	|| return
	IsPlatform mac && { versionDistributionMac || return; }
	IsPlatform win && { versionDistributionWin || return; }

	# Linux Kernel
	local bits="$(bitsCommand)"; [[ $bits ]] && bits=" ($bits bit)"
	echo "      kernel: $(uname -r)$bits"

	# hardware
	versionCpu || return
	local hardware="$(architectureCommand)"
	[[ "$hardware" != "$(hardwareCommand)" ]] && hardware+=" ($(hardwareCommand))"
	echo "    hardware: $hardware" 

	# chroot
	[[ -f "/etc/debian_chroot" ]] && echo "      chroot: $(cat "/etc/debian_chroot")"

	# Virtual Machine
	IsVm && echo "          vm: $(VmType)"

	RunPlatform version || return
}

versionCpu()
{
	! InPath lscpu && return

	local model count

	model="$(lscpu | grep "^Model name:" | cut -d: -f 2)"
	count="$(lscpu | grep "^CPU(s):" | cut -d: -f 2)"
	echo "         cpu: $(RemoveSpace "$model") ($(RemoveSpace "$count") CPU)"
}

versionDistribution()
{
	! InPath lsb_release && return

	local distributor version codename

	# Distributor - Debian|Raspbian|Ubuntu
	distributor="$(lsb_release -a |& grep "Distributor ID:" | cut -f 2-)"
	IsPlatform pi && distributor+="/Debian"

	# Version - 10.4|20.04.1 LTS
	version="$(lsb_release -a |& grep "Release:" | cut -f 2-)"
	if IsPlatform ubuntu; then version="$(lsb_release -a |& grep "Description:" | cut -f 2- | sed 's/'$distributor' //')"
	elif [[ -f /etc/debian_version ]]; then version="$(cat /etc/debian_version)"
	fi

	# Code Name - buster|focal
	codename="$(lsb_release -cs)"

	echo "distribution: $distributor $version ($codename)"
}

versionDistributionMac()
{
	local version="$(system_profiler SPSoftwareDataType | grep "System Version" | cut -f 10 -d" ")"
	local build="$(system_profiler SPSoftwareDataType | grep "System Version" | cut -f 11 -d" " | sed 's/(//' | sed 's/)//' )"
	local codeName

	case "$version" in
		10.15*) codeName="Mojave";;
		10.16*) codeName="Catalina";;
		*) codeName="unknown";;
	esac

	echo "distribution: macOS $version ($codeName build $build)"
}

versionDistributionWin()
{
	local r="HKEY_LOCAL_MACHINE/SOFTWARE/Microsoft/Windows NT/CurrentVersion"
	local releaseId="$(registry get "$r/ReleaseID" | RemoveCarriageReturn)"
	local ubr="$(HexToDecimal "$(registry get "$r/UBR" | RemoveCarriageReturn)")"
	local build="$(registry get "$r/CurrentBuild" | RemoveCarriageReturn)"

	echo "     windows: $releaseId (build $build.$ubr, WSL $(IsPlatform wsl1 && echo 1 || echo 2))"
}

versionPi()
{
	cpu=$(</sys/class/thermal/thermal_zone0/temp)
	echo "       model:$(cat /proc/cpuinfo | grep "^Model" | cut -d":" -f 2)"
	echo "    CPU temp: $((cpu/1000))'C"
}

run "$@"
