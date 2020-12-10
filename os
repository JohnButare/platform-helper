#!/usr/bin/env bash
. script.sh || exit

run() {	init && args "$@" && "${command}Command" "${args[@]}"; }

init() { :; }

usage()
{
	ScriptUsage "$1" "\
Usage: os [OPTION]... [COMMAND]...
Operating system commands

	architecture|bits|CodeName|hardware|version 			OS information
	environment|index|path|lock|preferences|store			OS control
	executable		OS executable information
	name					show or set the operating system name"
}

args()
{
	unset -v command

	# commands
	ScriptCommand "$@" || return

	# options
	set -- "${args[@]}"; args=()
	while (( $# != 0 )); do		
		case "$1" in "") : ;;
			-h|--help) usage 0;;
			*) ScriptOption "$@";;
		esac
		shift "$shift"; shift=1
	done
	set -- "${args[@]}"

	# arguments
	ScriptArgs "$@" || return; shift "$shift"
	[[ $@ ]] && usage
	return 0
}

#
# Commands
#

environmentCommand() { RunPlatform environment; }
environmentWin() { systemProperties 3; }

indexCommand() { RunPlatform index; }
indexWin() { coproc rundll32.exe shell32.dll,Control_RunDLL srchadmin.dll,Indexing Options; }

lockCommand() { RunPlatform lock; }
lockMac() { pmset displaysleepnow; }

pathCommand()
{ 
	if InPath "PathEditor.exe"; then
		start --elevate PathEditor.exe
	elif IsPlatform win; then
		systemProperties 3
	elif InPath vared; then
		vared PATH
	fi
}

preferencesCommand() { RunPlatform preferences; }
preferencesMac() { open "/System/Applications/System Preferences.app"; }
proferencesWin() { control.exe; }

storeCommand() { RunPlatform store; }
storeMac() { open "/System/Applications/App Store.app"; }
storeWin() { start "" "ms-windows-store://"; }

#
# Executable Command
#

executableInit() { unset name; }

executableUsage()
{
	echot "\
Usage: os executable format|find
OS executable information
	format 			returns the executable formats supported by the system.  The text will match
								the output of the \`file\` command.  Possible values are:
									ELF 32|64-bit LSB executable
									Mach-O 64-bit x86_64|arm64e
	find DIR		return the executables for the current machine in the target directory"
}

executableCommand() { usage; }

executableFormatCommand()
{
	IsPlatform mac && { echo "Mach-O $(bitsCommand)-bit executable $(fileArchitectureCommand)"; return; }
	IsPlatform linux,win && { echo "ELF $(bitsCommand)-bit LSB executable, $(fileArchitectureCommand)"; return; }
	return 1
}

alternateExecutableFormatCommand()
{
	IsPlatform mac,arm && { echo "Mach-O $(bitsCommand)-bit executable $(alternateFileArchitectureCommand)"; return; }
	return 1
}

executableFindArgs() { ScriptGetArg "dir" "$1"; ScriptCheckDir "$dir"; shift; }

executableFindCommand()
{
	local arch file

	# find an executable that supports the machines primary architecture
	arch="$(executableFormatCommand)"
	file="$(file "$dir"/* | grep "$arch" | tail -1 | cut -d: -f1)"
	file="${file% (for architecture $(fileArchitectureCommand))}" # remove suffix for MacOS universal binaries
	[[ $file ]] && { echo "$file"; return; }

	# see if we can find an executable the supports an alternate architecture if the platform supports one
	arch="$(alternateExecutableFormatCommand)"; [[ ! $arch ]] && return 1
	file="$(file "$dir"/* | grep "$arch" | tail -1 | cut -d: -f1)"
	file="${file% (for architecture $(fileArchitectureCommand))}" # remove suffix for MacOS universal binaries
	[[ $file ]] && { echo "$file"; return; }

	return 1
}

#
# Name Commands
#

nameInit() { unset name; }

nameUsage()
{
	echo "\
Usage: os hostname [set HOST]
	Show or set the operating system name"
}

nameArgs()
{
	(( $# == 0 )) && return
	ScriptGetArg "name" "$1"; shift
}

nameCommand()
{
	IsLocalHost "$name" && { echo "$HOSTNAME"; return; }
	DnsResolve "$name"
}

nameSetCommand() # 0=name changed, 1=name unchanged, 2=error
{
	[[ ! $name ]] && { read -p "Enter new operating system name (current $HOSTNAME): " name; }
	[[ ! $name || "$name" == "$HOSTNAME" ]] && return 1
	RunPlatform setHostname
}

setHostnamePi() { sudo raspi-config nonint do_hostname "$name" || return 2; }
setHostnameWin() { RunScript --elevate -- powershell.exe Rename-Computer -NewName "$name" || return 2; }

setHostnameLinux()
{
	IsPlatform pi && return
	InPath hostnamectl && { sudo hostnamectl set-hostname "$name" >& /dev/null && return 0 || return 2; }
	sudo hostname "$name" || return 2
}

setHostnameMac()
{
	sudo scutil --set HostName "$name" || return 2
	sudo scutil --set LocalHostName "$name" || return 2
	sudo scutil --set ComputerName "$name" || return 2
	dscacheutil -flushcache
}

#
# Information Commands
#

codeNameCommand() { InPath lsb_release && lsb_release -a |& grep "Codename:" | cut -f 2-; }

architectureCommand()
{
	case "$(hardwareCommand)" in
		arm64|armv7l|aarch64) echo "ARM";;
		mips|mip64) echo "MIPS";;
		x86_64) echo "x86";;
	esac
}

# fileArchitectureCommand - return the machine architecture used by the file command
fileArchitectureCommand()
{
	case "$(hardwareCommand)" in
		arm64) echo "arm64e";; # MacOS M1 ARM Chip
		armv7l|aarch64) echo "ARM";;
		mips|mip64) echo "MIPS";;
		x86_64) IsPlatform mac && echo "x86_64" || echo "x86-64";;
	esac
}

alternateFileArchitectureCommand()
{
	case "$(hardwareCommand)" in
		arm64) echo "x86_64";; # MacOS M1 ARM Chip supports x86_64 executables using Rosetta
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
# arm64						ARM, 64 bit, macOS
# armv71|aarch64 	ARM, 32|64 bit, Raspberry Pi
# mips|mip64			MIPS, 32|64 bit
# x86_64 					x86_64 (Intel/AMD), 64 bit
hardwareCommand() ( uname -m; )

#
# Version Command
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

#
# Helper
#

systemProperties()
{
	! IsPlatform win && return
	local tab=; [[ $1 ]] && tab=",,$1"; 
	rundll32.exe /d shell32.dll,Control_RunDLL SYSDM.CPL$tab
}

run "$@"
