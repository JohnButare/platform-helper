#!/usr/bin/env bash
. script.sh || exit

usage()
{
	ScriptUsage "$1" "\
Usage: os [COMMAND]... [OPTION]...
Operating system commands

	info|architecture|bits|build|CodeName|hardware|mhz|version		information
	disk					[available|total](total)
	environment|index|path|lock|preferences|store									control
	executable		executable information
	memory				[available|total](total)
	name					show or set the operating system name"
}

#
# commands
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
preferencesWin() { control.exe; }

storeCommand() { RunPlatform store; }
storeMac() { open "/System/Applications/App Store.app"; }
storeWin() { start "" "ms-windows-store://"; }

#
# Disk Command
#

diskUsage() 
{
	echot "Usage: os disk [available|total](total)
Return the total or available amount of system disk."
}

diskCommand() { diskTotalCommand; }

diskAvailableCommand()
{
	! InPath di && return
	di -d g | head -2 | tail -1 | tr -s ' ' | cut -d" " -f 5
}

diskTotalCommand()
{
	! InPath di && return
	di -d g | head -2 | tail -1 | tr -s ' ' | cut -d" " -f 3
}

memoryTotalCommand()
{ 
	if IsPlatform mac; then
		system_profiler SPHardwareDataType | grep "Memory:" | tr -s " " | cut -d" " -f 3
	else
		! InPath free && return
		local bytes="$(free --bytes | grep "Mem:" | tr -s " " | cut -d" " -f2)"
		local gbRoundedTwo="$(echo "scale=2; ($bytes / 1024 / 1024 / 1024) + .05" | bc)"; 
		local gbRounded="$(echo "($gbRoundedTwo + .5)/1" | bc)"
		echo "$gbRounded"
	fi
}

#
# Executable Command
#

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

executableArgStart() { unset name; }

executableCommand() { usage; }

executableFormatCommand()
{
	IsPlatform mac && { echo "Mach-O $(bitsCommand)-bit executable $(architectureFileCommand)"; return; }
	IsPlatform linux,win && { echo "ELF $(bitsCommand)-bit LSB .*, $(architectureFileCommand)"; return; }
	return 1
}

alternateExecutableFormatCommand()
{
	IsPlatform mac,arm && { echo "Mach-O $(bitsCommand)-bit executable $(alternateFileArchitectureCommand)"; return; }
	return 1
}

executableFindArgs() { ScriptArgGet "dir" -- "$@"; ScriptCheckDir "$dir"; shift; }

executableFindCommand()
{
	local arch file

	# find an executable that supports the machines primary architecture
	arch="$(executableFormatCommand)"
	file="$(file "$dir"/* | grep "$arch" | tail -1 | cut -d: -f1)"
	file="${file% (for architecture $(architectureFileCommand))}" # remove suffix for MacOS universal binaries
	[[ $file ]] && { echo "$file"; return; }

	# see if we can find an executable the supports an alternate architecture if the platform supports one
	arch="$(alternateExecutableFormatCommand)"; [[ ! $arch ]] && return 1
	file="$(file "$dir"/* | grep "$arch" | tail -1 | cut -d: -f1)"
	file="${file% (for architecture $(architectureFileCommand))}" # remove suffix for MacOS universal binaries
	[[ $file ]] && { echo "$file"; return; }

	return 1
}

#
# Memory Command
#

memoryUsage() 
{
	echot "Usage: os memory [available|total](total)
Return the total or available amount of system memory rounded up or down to the nearest gigabyte."
}

memoryCommand() { memoryTotalCommand; }

memoryAvailableCommand()
{
	if IsPlatform mac; then
		local pages="$(vm_stat | grep "^Pages free:" | tr -s " " | cut -d" " -f 3 | cut -d. -f 1)"
		local bytes="$(echo "$pages * 4 * 1024 * 1024 / 10" | bc)"
	elif InPath free; then
		local bytes="$(free --bytes | grep "Mem:" | tr -s " " | cut -d" " -f7)"
	else 
		return
	fi

	local gbRounded="$(echo "scale=2; ($bytes / 1024 / 1024 / 1024) + .05" | bc)"; 
	echo "$gbRounded"
}

memoryTotalCommand()
{ 
	if IsPlatform mac; then
		system_profiler SPHardwareDataType | grep "Memory:" | tr -s " " | cut -d" " -f 3
	else
		! InPath free && return
		local bytes="$(free --bytes | grep "Mem:" | tr -s " " | cut -d" " -f2)"
		local gbRoundedTwo="$(echo "scale=2; ($bytes / 1024 / 1024 / 1024) + .05" | bc)"; 
		local gbRounded="$(echo "($gbRoundedTwo + .5)/1" | bc)"
		echo "$gbRounded"
	fi
}

#
# Name Commands
#

nameUsage()
{
	echot "\
Usage: os hostname [set HOST]
	Show or set the operating system name"
}

nameArgStart() { unset name; }

nameArgs()
{
	(( $# == 0 )) && return
	ScriptArgGet "name" -- "$@"; shift
}

nameCommand()
{
	IsLocalHost "$name" && { echo "$HOSTNAME"; return; }
	local resolvedName="$(DnsResolve "$name" --quiet)"

	# check for virtual host
	! [[ "$resolvedName" ]] && resolvedName="$(DnsResolve "$HOSTNAME-$name"  --quiet)"

	# if the resolved name is empty or a superset of the DNS name use the full name
	[[ "$name" =~ $resolvedName$ ]] && resolvedName="$name"

	echo "$resolvedName"

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

codenameCommand() { ! InPath lsb_release && return 1; lsb_release -a |& grep "Codename:" | cut -f 2-; }

architectureUsage() { echot "Usage: os architecture [MACHINE]\n	Show the architecture of the current machine or the specified machine."; }
architectureArgStart() { unset -v machine; }
architectureArgs() { (( $# == 0 )) && return; ScriptArgGet "machine" -- "$@"; }

architectureCommand()
{
	local m; m=${machine:-$(hardwareCommand)} || return

	case "$m" in
		arm64|armv7l|aarch64) echo "arm"; return;;
		mips|mips64) echo "mips"; return;;
		x86_64) echo "x86"; return;;
	esac

	[[ ! $quiet ]] && EchoErr "The architecture for machine '$m' is unknown"
	return 1
}

architectureFileUsage() { echot "Usage: os architecture file [MACHINE]\n	Show the architecture of the current machine or the specified machine returned by the file command."; }
architectureFileArgStart() { unset -v machine; }
architectureFileArgs() { (( $# == 0 )) && return; ScriptArgGet "machine" -- "$@"; }

architectureFileCommand()
{
	local m; m=${machine:-$(hardwareCommand)} || return

	case "$m" in
		arm64) echo "arm64"; return;; # MacOS M1 ARM Chip, from: file vault|...
		armv7l|aarch64) echo "ARM"; return;;
		mips|mip64) echo "MIPS"; return;;
		x86_64) IsPlatform mac && echo "x86_64" || echo "x86-64"; return;;
	esac

	[[ ! $quiet ]] && EchoErr "The architecture for machine '$m' is unknown"
	return 1
}

alternateFileArchitectureCommand()
{
	case "$(hardwareCommand)" in
		arm64) echo "x86_64";; # MacOS M1 ARM Chip supports x86_64 executables using Rosetta
	esac
}

bitsUsage() { echot "Usage: os bits [MACHINE]\n	Show the operating system bits of the current machine or the specified machine."; }
bitsArgStart() { unset -v machine; }
bitsArgs() { (( $# == 0 )) && return; ScriptArgGet "machine" -- "$@"; }

bitsCommand() # 32 or 64
{	
	# assume the OS bits from the specified machine
	if [[ $machine ]]; then
		case "$machine" in
			aarch64|arm64|mip64|x86_64) echo "64"; return;;
			armv7l|mips) echo "32"; return;;
		esac

		[[ ! $quiet ]] && EchoErr "The operating system bits for machine '$machine' is unknown"
		return 1
	fi

	# determine the current host oeprating system bits
	if InPath getconf; then { echo "$(getconf LONG_BIT)"; return; }
	elif InPath lscpu; then { lscpu | grep "CPU op-mode(s): 32-bit, 64-bit" >& /dev/null && echo "64" || echo "32"; return; }
	fi

	[[ ! $quiet ]] && EchoErr "Unable to determine the operating systems bits."
	return 1
}

buildCommand() { RunPlatform "build"; } 
buildWin() { registry get "HKEY_LOCAL_MACHINE/SOFTWARE/Microsoft/Windows NT/CurrentVersion/CurrentBuild" | RemoveCarriageReturn; }

mhzCommand()
{
	! InPath lscpu && return
	lscpu | grep "^CPU .* MHz:" | head -1 | awk '{print $NF}' | cut -d. -f 1 # CPU [max|min] MHZ:
}

# hardware - return the machine hardware, one of:
# arm64						ARM, 64 bit, macOS
# armv71|aarch64 	ARM, 32|64 bit, Raspberry Pi
# mips|mip64			MIPS, 32|64 bit
# x86_64 					x86_64 (Intel/AMD), 64 bit
hardwareCommand() ( uname -m; )

#
# info command
#

infoUsage()
{
	echot "\
Usage: $(ScriptName) info [HOST](localhost)
Show Operating System information.

	-d|--detail		show detailed information
	-m|--monitor	monitor information"
}

infoArgStart() { unset -v detail monitor; host="localhost"; }
infoArgs() { (( $# == 0 )) && return; ScriptArgGet "host" -- "$@"; }

infoOpt()
{
	case "$1" in
		-d|--detail) detail="--detail";;
		-m|--monitor) monitor="true";;
		*) return 1;;
	esac
}

infoCommand() 
{
	if [[ $monitor ]]; then 
		watch -n 1 os info $host $detail "${globalArgs[@]}"
	else
		if IsLocalHost "$host"; then infoLocal; else infoRemote; fi
	fi
}

infoRemote()
{
	# check for ssh
	! SshIsAvailable "$host" && { echo "$host Operating System information is not available"; return; }

	# destailed information - using the os command on the host
	SshInPath "$host" "os" && { SshHelper connect "$host" -- os info; return; }
	
	# basic information - using HostGetInfo vars command locally
	ScriptEval HostGetInfo vars "$host" || return
	[[ $_platform ]] && 		echo "    platform: $_platform"
	[[ $_platformLike ]] && echo "        like: $_platformLike"
	[[ $_platformId ]] &&   echo "          id: $_platformId"

	return 0
}

infoLocal()
{
	local w what=( model platform distribution kernel chroot vm file cpu architecture mhz memory disk switch other )
	for w in "${what[@]}"; do info${w^} || return; done
	
}

infoArchitecture()
{
	local architecture="$(architectureCommand)"
	[[ "$architecture" != "$(hardwareCommand)" ]] && architecture+=" ($(hardwareCommand))"
	echo "architecture: $architecture" 
}

infoChroot()
{
	[[ ! -f "/etc/debian_chroot" ]] && return
	echo "      chroot: $(cat "/etc/debian_chroot")"
}

infoCpu()
{
	! InPath lscpu && return

	local model count

	model="$(lscpu | grep "^Model name:" | cut -d: -f 2)"
	count="$(lscpu | grep "^CPU(s):" | cut -d: -f 2)"
	echo "         cpu: $(RemoveSpace "$model") ($(RemoveSpace "$count") CPU)"
}

infoDisk()
{
	! InPath di && return
	echo "        disk: $(diskAvailableCommand) GB available / $(diskTotalCommand) GB total" 
}

infoFile()
{
	[[ ! $detail ]] && return
	echo "file sharing: $(unc get protocols "$HOSTNAME")" || return
}

infoKernel()
{
	local bits="$(bitsCommand)"; [[ $bits ]] && bits=" ($bits bit)"
	echo "      kernel: $(uname -r)$bits"
}

infoMemory()
{
	echo "      memory: $(memoryAvailableCommand) GB available / $(memoryTotalCommand) GB total" 
}

infoMhz()
{
	local mhz; mhz="$(mhzCommand)"
	[[ ! $mhz ]] && return

	if [[ $detail ]] && IsPlatform PiKernel; then
		mhz+=" max / $(pi info mhz) current"
	fi

	echo "         mhz: $mhz" 
}

infoModel() 
{
	local model; model="$(RunPlatform infoModel)"; 
	[[ ! $model ]] && return
	echo "       model: $model"
}
infoModelPiKernel() { pi info model; }

infoOther() { RunPlatform infoOther; }
infoOtherPiKernel() { echo "    CPU temp: $(pi info temp)"; }

infoPlatform()
{
	echo "    platform: $(PlatformDescription)"
}

infoSwitch()
{
	local switch; switch="$(power status switch "$HOSTNAME")"
	[[ ! $switch ]] && return

	if [[ $detail ]]; then
		local watts; watts="$(power status watts "$HOSTNAME")"
		[[ $watts ]] && switch+=" ($watts watts)"
	fi

	echo "      switch: $switch" 
}

infoVm()
{
	! IsVm && return
	echo "          vm: $(VmType)"
}

# infoDistribution

infoDistribution()
{
	! InPath lsb_release && return

	local distributor version codename
	local release; release="$(lsb_release -a 2>1)" || return

	# Distributor - Debian|Raspbian|Ubuntu
	distributor="$(echo "$release" |& grep "Distributor ID:" | cut -f 2-)"
	IsPlatform pi && distributor+="/Debian"

	# Version - 10.4|20.04.1 LTS
	version="$(echo "$release" |& grep "Release:" | cut -f 2-)"
	if IsPlatform ubuntu; then version="$(echo "$release" |& grep "Description:" | cut -f 2- | sed 's/'$distributor' //')"
	elif [[ -f /etc/debian_version ]]; then version="$(cat /etc/debian_version)"
	fi

	# Code Name - buster|focal
	codename="$(echo "$release" | grep "Codename:" | cut -f 2- )"

	echo "distribution: $distributor $version ($codename)"
	RunPlatform "infoDistribution"
}

infoDistributionMac()
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

infoDistributionWin()
{	
	local r="HKEY_LOCAL_MACHINE/SOFTWARE/Microsoft/Windows NT/CurrentVersion"
	local releaseId="$(registry get "$r/ReleaseID" | RemoveCarriageReturn)"
	local ubr="$(HexToDecimal "$(registry get "$r/UBR" | RemoveCarriageReturn)")"
	local build="$(buildCommand)"

	echo "     windows: $releaseId (build $build.$ubr, WSL $(wsl get name))"
}

#
# helper
#

systemProperties()
{
	! IsPlatform win && return
	local tab=; [[ $1 ]] && tab=",,$1"; 
	rundll32.exe /d shell32.dll,Control_RunDLL SYSDM.CPL$tab
}

ScriptRun "$@"
