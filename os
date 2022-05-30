#!/usr/bin/env bash
. script.sh || exit

usage()
{
	ScriptUsage "$1" "\
Usage: os [COMMAND]... [OPTION]...
Operating system commands

	info|architecture|bits|build|CodeName|hardware|mhz|release|version		information
	disk					[available|total](total)
	environment|index|path|lock|preferences|store													control
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
	echot "Usage: os disk [free|total|used](total)
Return the total or available amount of system disk."
}

diskCommand() { diskTotalCommand; }

diskFreeCommand()
{
	! InPath di && return
	di --type ext4 --display-size g | head -2 | tail -1 | tr -s ' ' | cut -d" " -f 5
}

diskTotalCommand()
{
	! InPath di && return
	di --type ext4 --display-size g | head -2 | tail -1 | tr -s ' ' | cut -d" " -f 3
}

diskUsedCommand()
{
	! InPath di && return
	di --type ext4 --display-size g | head -2 | tail -1 | tr -s ' ' | cut -d" " -f 4
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

	# find an executable that supports the primary architecture
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
	echot "Usage: os memory [available|total|used](total)
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

memoryUsedCommand()
{ 
	if IsPlatform mac; then
		local pages="$(vm_stat | grep "^Pages active:" | tr -s " " | cut -d" " -f 3 | cut -d. -f 1)"
		local bytes="$(echo "$pages * 4 * 1024 * 1024 / 10" | bc)"
	elif InPath free; then
		local bytes="$(free --bytes | grep "Mem:" | tr -s " " | cut -d" " -f3)"
	else 
		return
	fi

	local gbRounded="$(echo "scale=2; ($bytes / 1024 / 1024 / 1024) + .05" | bc)"; 
	echo "$gbRounded"
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
	RunPlatform setHostname && UpdateSet "hostname" "$name"
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

releaseCommand() { RunPlatform "release"; }
releaseUbuntu() { lsb_release -rs; }


#
# info command
#

infoUsage()
{
	EchoWrap "\
Usage: $(ScriptName) info [HOSTS|all](localhost)
Show Operating System information.

	-d|--detail			show detailed information
	   --dynamic		show dynamic information
	-m|--monitor		monitor dynamic information
	-p|--prefix			prefix each line with the hostname
	-s|--skip LIST	comma separated list of items to skip
	-w|--what LIST	comma separated list of items to show

Items (basic): ${infoBasic[@]}
     (detail): ${infoDetail[@]}
     (other): ${infoOther[@]}

Examples:
os info -w=disk_free pi11,pi2		# free disk space for specified hosts
os info -w=disk_free all				# free disk space for all hosts"
}

infoArgStart() 
{ 
	unset -v detail monitor prefix
	hostArg="localhost" what=() skip=()
	infoBasic=(model platform distribution kernel chroot vm cpu architecture mhz file package switch other)
	infoDetail=(mhz memory process disk package switch)
	infoOther=( disk_free disk_total disk_used memory_total )
	infoAll=( "${infoBasic[@]}" "${infoDetail[@]}" "${infoOther[@]}" )
}

infoArgs() { (( $# == 0 )) && return; ScriptArgGet "hostArg" -- "$@"; }
infoArgEnd() { infoSetRemoteArgs; }

infoOpt()
{
	case "$1" in
		-d|--detail) detail="--detail";;
		--dynamic) dynamic="--dynamic";;
		-m|--monitor) monitor="--monitor";;
		-p|--prefix) prefix="--prefix";;
		-s|--skip|-s=*|--skip=*) ScriptArgItems "skip" "infoAll" "$@" || return;;
		-w|--what|-w=*|--what=*) ScriptArgItems "what" "infoAll" "$@" || return;;
		*) return 1;;
	esac
}

infoCommand() { [[ $monitor ]] && { infoMonitor; return; } || infoHosts; }
infoHost() { if IsLocalHost "$host"; then infoLocal; else infoRemote; fi; }
infoMonitor() { watch -n 1 os info $hostArg --dynamic "${remoteArgs[@]}"; }
infoSetRemoteArgs() { remoteArgs=( $detail $prefix "${skipArg[@]}" "${whatArg[@]}" "${globalArgs[@]}" ); }

infoHosts()
{
	local host hosts; getHosts || return
	(( ${#hosts[@]} > 1 )) && { prefix="--prefix"; infoSetRemoteArgs; }
	for host in "${hosts[@]}"; do infoHost || return; done
}

infoEcho()
{
	[[ $prefix ]] && printf "$HOSTNAME "
	echo "$1"
}

infoPrint()
{
	[[ $prefix ]] && printf "$HOSTNAME "
	printf "$1"
}

infoRemote()
{
	# check for ssh
	! SshIsAvailable "$host" && { infoEcho "$host Operating System information is not available"; return; }

	# get detailed information using the os command on the host if possible
	SshInPath "$host" "os" && { SshHelper connect "$host" --pseudo-terminal -- os info "${remoteArgs[@]}"; return; }
	
	# othereise, get basic information using HostGetInfo vars command locally
	ScriptEval HostGetInfo vars "$host" || return
	[[ $_platform ]] && 		infoEcho "    platform: $_platform"
	[[ $_platformLike ]] && infoEcho "        like: $_platformLike"
	[[ $_platformId ]] &&   infoEcho "          id: $_platformId"

	return 0
}

infoLocal()
{
	# what default
	if [[ ! $what ]]; then
		what=()
  	[[ ! $dynamic ]] && what+=( "${infoBasic[@]}" )
 		[[ $detail || $dynamic ]] && what+=( "${infoDetail[@]}" )
 	fi

 	# show information
 	local w
	for w in "${what[@]}"; do
		IsInArray "$w" skip && continue
		info${w^} || return
	done	
}

infoArchitecture()
{
	local architecture="$(architectureCommand)"
	[[ "$architecture" != "$(hardwareCommand)" ]] && architecture+=" ($(hardwareCommand))"
	infoEcho "architecture: $architecture" 
}

infoChroot()
{
	[[ ! -f "/etc/debian_chroot" ]] && return
	infoEcho "      chroot: $(cat "/etc/debian_chroot")"
}

infoCpu()
{
	! InPath lscpu && return

	local model count

	model="$(lscpu | grep "^Model name:" | cut -d: -f 2)"
	count="$(lscpu | grep "^CPU(s):" | cut -d: -f 2)"
	infoEcho "         cpu: $(RemoveSpace "$model") ($(RemoveSpace "$count") CPU)"
}

infoDisk()
{
	! InPath di && return
	infoEcho "        disk: $(diskUsedCommand)/$(diskAvailableCommand)/$(diskTotalCommand) GB used/available/total" 
}

infoDisk_free() { ! InPath di && return; infoEcho "   disk free: $(diskFreeCommand) GB"; }
infoDisk_total() { ! InPath di && return; infoEcho "  disk total: $(diskTotalCommand) GB"; }
infoDisk_used() { ! InPath di && return; infoEcho "   disk used: $(diskUsedCommand) GB"; }

infoPackage()
{
	infoPrint "     package: $(PackageManager)" || return
	RunFunction infoPackage "$(PackageManager)"
}

infoPackageApt()
{
	local upgradeable="$(PackageUpgradable)"
	{ ! IsInteger "$upgradeable" || (( upgradeable == 0 )); } && { echo; return; }
	echo " ($upgradeable upgradeable)" || return
}

infoProcess()
{
	infoEcho "   processes: $(pscount)" || return
}

infoFile()
{
	infoEcho "file sharing: $(unc get protocols "$HOSTNAME")" || return
}

infoKernel()
{
	local bits="$(bitsCommand)"; [[ $bits ]] && bits=" ($bits bit)"
	infoEcho "      kernel: $(uname -r)$bits"
	RunPlatform infoKernel;
}
infoKernelPi() { infoEcho "    firmware: $(pi info firmware)"; }

infoMemory() { infoEcho "      memory: $(memoryUsedCommand)/$(memoryAvailableCommand)/$(memoryTotalCommand) GB used/available/total"; }
infoMemory_total() { infoEcho "memory total: $(memoryTotalCommand) GB"; }

infoMhz()
{
	local mhz; mhz="$(mhzCommand)"
	[[ ! $mhz ]] && return

	if IsPlatform PiKernel; then
		mhz+=" max / $(pi info mhz) current"
	fi

	infoEcho "         mhz: $mhz" 
}

infoModel() 
{
	local model; model="$(RunPlatform infoModel)"; 
	[[ ! $model ]] && return
	infoEcho "       model: $model"
}
infoModelPiKernel() { pi info model; }

infoOther() { RunPlatform infoOther; }
infoOtherPiKernel() {	infoEcho "    CPU temp: $(pi info temp)"; }
infoPlatform() {	infoEcho "    platform: $(PlatformDescription)"; }

infoSwitch()
{
	local switch; switch="$(power status switch "$HOSTNAME")"
	[[ ! $switch ]] && return

	if [[ $detail || $dynamic ]]; then
		local watts; watts="$(power status watts "$HOSTNAME")"
		[[ $watts ]] && switch+=" ($watts watts)"
	fi

	infoEcho "      switch: $switch" 
}

infoVm()
{
	! IsVm && return
	infoEcho "          vm: $(VmType)"
}

# infoDistribution

infoDistribution()
{
	! InPath lsb_release && return

	local distributor version codename
	local release; release="$(lsb_release -a 2>&1)" || return

	# Distributor - Debian|Raspbian|Ubuntu
	distributor="$(infoEcho "$release" |& grep "Distributor ID:" | cut -f 2-)"
	IsPlatform pi && distributor+="/Debian"

	# Version - 10.4|20.04.1 LTS
	version="$(infoEcho "$release" |& grep "Release:" | cut -f 2-)"
	if IsPlatform ubuntu; then version="$(infoEcho "$release" |& grep "Description:" | cut -f 2- | sed 's/'$distributor' //')"
	elif [[ -f /etc/debian_version ]]; then version="$(cat /etc/debian_version)"
	fi

	# Code Name - buster|focal
	codename="$(infoEcho "$release" | grep "Codename:" | cut -f 2- )"

	infoEcho "distribution: $distributor $version ($codename)"
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

	infoEcho "distribution: macOS $version ($codeName build $build)"
}

infoDistributionWin()
{	
	local r="HKEY_LOCAL_MACHINE/SOFTWARE/Microsoft/Windows NT/CurrentVersion"
	local releaseId="$(registry get "$r/ReleaseID" | RemoveCarriageReturn)"
	local ubr="$(HexToDecimal "$(registry get "$r/UBR" | RemoveCarriageReturn)")"
	local build="$(buildCommand)"

	local wslVersion="$(wsl get version)"
	local wslgVersion="$(wsl get version wslg)"
	local wslExtra; [[ $wslVersion ]] && wslExtra+=" v$wslVersion WSLg v$wslgVersion"

	infoEcho "     windows: $releaseId (build $build.$ubr, WSL$wslExtra $(wsl get name))"
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
