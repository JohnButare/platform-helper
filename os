#!/usr/bin/env bash
. script.sh || exit

usage()
{
	ScriptUsage "$1" "\
Usage: os [COMMAND]... [OPTION]...
Operating system commands

	info|architecture|bits|build|CodeName|hardware|IsServer|mhz|release|version
	disk					[available|total](total)
	dark|environment|index|path|lock|preferences|store
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
# dark command
#

darkUsage() { echot "Usage: os dark on|off\nTurn dark mode on or off."; }
darkCommand(){ usage; }
darkOnCommand() { RunPlatform darkOn; }
darkOffCommand() { RunPlatform darkOff; }

darkOnWin() { registry set "$(darkKey)/AppsUseLightTheme" 0 && registry set "$(darkKey)/SystemUsesLightTheme" 0 && RestartExplorer; }
darkOffWin() { registry set "$(darkKey)/AppsUseLightTheme" 1 && registry set "$(darkKey)/SystemUsesLightTheme" 1 && RestartExplorer; }
darkKey() { echo "HKEY_CURRENT_USER/Software/Microsoft/Windows/CurrentVersion/Themes/Personalize"; }

#
# Disk Command
#

diskUsage() 
{
	echot "Usage: os disk [free|total|used](total)
Return the total or available amount of system disk."
}

diskCommand() { diskTotalCommand; }

# diskFreeCommand [N](1) - disk N free space.    Disk 1 is the main disk, 2 is the next, etc.
diskFreeCommand()
{	
	! InPath di && return; local disk="${1:-1}"
	di --type ext4 --display-size g | grep "^/dev" | head -$disk | tail -1 | tr -s ' ' | cut -d" " -f 5
}

# diskTotalCommand [N](1) - disk N from space.    Disk 1 is the main disk, 2 is the next, etc.
diskTotalCommand()
{
	! InPath di && return; local disk="${1:-1}"
	di --type ext4 --display-size g | grep "^/dev" | head -$disk | tail -1 | tr -s ' ' | cut -d" " -f 3
}

# diskUsedCommand [N](1) - disk N from space.    Disk 1 is the main disk, 2 is the next, etc.
diskUsedCommand()
{
	! InPath di && return; local disk="${1:-1}"
	di --type ext4 --display-size g | grep "^/dev" | head -$disk | tail -1 | tr -s ' ' | cut -d" " -f 4
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
Usage: os executable format|find|id
OS executable information
	format 			returns the executable formats supported by the system.  The text will match
							the output of the \`file\` command.  Possible values are:
									ELF 32|64-bit LSB executable
									Mach-O 64-bit x86_64|arm64e
	find DIR		return the executables for the current machine in the target directory
	id FILE			return a unique identifier for the specified executable file, one of 
							linux|mac|win_arm32|arm64|x86|x64|universal"
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

executableIdArgs() { ScriptArgGet "file" -- "$@"; ScriptCheckFile "$file"; shift; }

executableIdCommand()
{
	local desc="$(command file "$file")" || return
	local id

	# lower case description
	desc="${desc,,}"

	# platform
	if [[ "$desc" =~ mach-o ]]; then id="mac_"
	elif [[ "$desc" =~ elf ]]; then id="linux_"
	elif [[ "$desc" =~ pe32|pe32+ ]]; then id="win_"
	else ScriptErrQuiet "unable to determine the platform of '$(FileToDesc "$file")'"; return 1
	fi

	# architecture
	if [[ "$desc" =~ universal ]]; then id+="universal"
	elif [[ "$desc" =~ arm && "$desc" =~ 64-bit ]]; then id+="arm64"
	elif [[ "$desc" =~ arm && "$desc" =~ 32-bit ]]; then id+="arm32"
	elif [[ "$desc" =~ x86-64|x86_64 ]]; then id+="x64"
	elif [[ "$desc" =~ 80386 ]]; then id+="x86"
	else ScriptErrQuiet "unable to determine the architecture of '$(FileToDesc "$file")'"; return 1
	fi

	echo "$id"
}

executableFindArgs() { ScriptArgGet "dir" -- "$@"; ScriptCheckDir "$dir"; shift; }

executableFindCommand()
{
	local arch file

	# find an executable that supports the primary architecture
	arch="$(executableFormatCommand)" || return
	file="$(file "$dir"/* | sort -V | grep "$arch" | tail -1 | cut -d: -f1)"
	file="${file% (for architecture $(architectureFileCommand))}" # remove suffix for mac universal binaries
	[[ $file ]] && { echo "$file"; return; }

	# see if we can find an executable the supports an alternate architecture if the platform supports one
	arch="$(alternateExecutableFormatCommand)"; [[ ! $arch ]] && return 1
	file="$(file "$dir"/* | sort -V | grep "$arch" | tail -1 | cut -d: -f1)"
	file="${file% (for architecture $(architectureFileCommand))}" # remove suffix for mac universal binaries
	[[ $file ]] && { echo "$file"; return; }

	return 1
}

#
# Memory Command
#

memoryUsage() 
{
	echot "Usage: os memory [free|total|used](total)
Return system memory information rounded up or down to the nearest gigabyte."
}

memoryCommand() { memoryTotalCommand; }

memoryFreeCommand()
{
	if IsPlatform mac; then
		local pages; pages="$(vm_stat | grep "^Pages free:" | tr -s " " | cut -d" " -f 3 | cut -d. -f 1)"
		local bytes; bytes="$(echo "$pages * 4 * 1024 * 1024 / 10" | bc)"
	elif InPath free; then
		local bytes; bytes="$(free --bytes | grep "Mem:" | tr -s " " | cut -d" " -f7)"
	else 
		return
	fi

	local gbRounded; gbRounded="$(echo "scale=2; ($bytes / 1024 / 1024 / 1024) + .05" | bc)"; 
	echo "$gbRounded"
}

memoryTotalCommand()
{ 
	if IsPlatform mac; then
		system_profiler SPHardwareDataType | grep "Memory:" | tr -s " " | cut -d" " -f 3
	else
		! InPath free && return
		local bytes; bytes="$(free --bytes | grep "Mem:" | tr -s " " | cut -d" " -f2)"
		local gbRoundedTwo; gbRoundedTwo="$(echo "scale=2; ($bytes / 1024 / 1024 / 1024) + .05" | bc)"; 
		local gbRounded; gbRounded="$(echo "($gbRoundedTwo + .5)/1" | bc)"
		echo "$gbRounded"
	fi
}

memoryUsedCommand()
{ 
	if IsPlatform mac; then
		local pages; pages="$(vm_stat | grep "^Pages active:" | tr -s " " | cut -d" " -f 3 | cut -d. -f 1)"
		local bytes; bytes="$(echo "$pages * 4 * 1024 * 1024 / 10" | bc)"
	elif InPath free; then
		local bytes; bytes="$(free --bytes | grep "Mem:" | tr -s " " | cut -d" " -f3)"
	else 
		return
	fi

	local gbRounded; gbRounded="$(echo "scale=2; ($bytes / 1024 / 1024 / 1024) + .05" | bc)"; 
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
	local resolvedName cache="os-name-$name"

	IsLocalHost "$name" && { echo "$HOSTNAME"; return; }

	# check cache
	if [[ ! $force ]]; then
		resolvedName="$(UpdateGet "$cache")"
		[[ $resolvedName ]] && { echo "$resolvedName"; return; }
	fi

	# check DNS
	resolvedName="$(DnsResolve "$name" --quiet)"

	# check virtual host
	! [[ "$resolvedName" ]] && resolvedName="$(DnsResolve "$HOSTNAME-$name"  --quiet)"

	# if the resolved name is empty or a superset of the DNS name use the full name
	[[ "$name" =~ $resolvedName$ ]] && resolvedName="$name"

	# cache
	UpdateSet "$cache" "$resolvedName"

	# return
	echo "$resolvedName"
}

nameSetCommand() # 0=name changed, 1=name unchanged, 2=error
{
	[[ ! $name ]] && { read -p "Enter new operating system name (current $HOSTNAME): " name; }
	[[ ! $name || "$name" == "$HOSTNAME" ]] && return 1 # 1=name unchanged
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

architectureUsage() { echot "Usage: os architecture [bits] [MACHINE]\n	Show the architecture of the current machine or the specified machine.  Returns arm, mips, or x86."; }
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

architectureBitsUsage() { echot "Usage: os architecture bits\n	Show the architecture with memory bits of the current machine.  Returns arm, arm64, x86, or x64."; }

architectureBitsCommand()
{
	if IsPlatformAll arm,64; then echo "arm64"
	elif IsPlatformAll x86,64; then echo "x64"
	elif IsPlatformAll arm,32; then echo "arm"
	elif IsPlatformAll x86,32; then echo "x86"
	else return 1;
	fi
}

architectureFileUsage() { echot "Usage: os architecture file [MACHINE]\n	Show the architecture of the current machine or the specified machine returned by the file command."; }
architectureFileArgStart() { unset -v machine; }
architectureFileArgs() { (( $# == 0 )) && return; ScriptArgGet "machine" -- "$@"; }

architectureFileCommand()
{
	local m; m=${machine:-$(hardwareCommand)} || return

	case "$m" in
		arm64) echo "arm64"; return;; # mac M1 ARM Chip, from: file vault|...
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
		arm64) echo "x86_64";; # mac M1 ARM Chip supports x86_64 executables using Rosetta
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
buildMac() { system_profiler SPSoftwareDataType | grep "System Version" | cut -f 11 -d" " | sed 's/(//' | sed 's/)//'; }
buildLinux() { versionCommand; }
buildWin() { registry get "HKEY_LOCAL_MACHINE/SOFTWARE/Microsoft/Windows NT/CurrentVersion/CurrentBuild" | RemoveCarriageReturn; }

codenameCommand() { RunPlatform "codeName"; }

codeNameLinux() # buster|focal
{
	! InPath lsb_release && return; lsb_release -cs; 
}

codeNameMac()
{
	# https://www.macworld.com/article/672681/list-of-all-macos-versions-including-the-latest-macos.html
	case "$(versionCommand)" in
		10.15*) echo "Mojave";;
		10.16*) echo "Catalina";;
		11.*) echo "Big Sur";;
		12.*) echo "Monterey";;
		13.*) echo "Ventura";;
		*) echo "unknown";;
	esac
}

distributorCommand() { RunPlatform "distributor"; }
distributorMac() { echo "Apple"; }
distributorWin() { echo "Microsoft"; }

distributorLinux() # CasaOS|Debian|Raspbian|Ubuntu
{
	IsPlatform CasaOs && { echo "CasaOS"; return; }
	! InPath lsb_release && return
	lsb_release -is
}

mhzCommand()
{
	! InPath lscpu && return
	lscpu | grep "^CPU .* MHz:" | head -1 | awk '{print $NF}' | cut -d. -f 1 # CPU [max|min] MHZ:
}

# hardware - return the machine hardware, one of:
# arm64						ARM, 64 bit, mac
# armv71|aarch64 	ARM, 32|64 bit, Raspberry Pi
# mips|mip64			MIPS, 32|64 bit
# x86_64 					x86_64 (Intel/AMD), 64 bit
hardwareCommand() ( uname -m; )

isServerCommand()
{
	case "$PLATFORM_OS" in
		linux) IsPlatform debian && [[ ! $XDG_CURRENT_DESKTOP ]];;
		mac) return 1;;
		win) CanElevate && registry get "$r/ProductName" | RemoveCarriageReturn | grep -q -i "server";;
	esac
}

releaseUsage() { ScriptUsageEcho "Usage: $(ScriptName) release [check]"; }
releaseCommand() { RunPlatform "release"; }
releaseDebian() { lsb_release -rs; }

releaseCheckUsage() { ScriptUsageEcho "Usage: $(ScriptName) release check EXPR\nCheck the version, where check is an expression to check the version against, i.e. release check '>= 23.10'."; }
releaseCheckArgStart() { unset -v check; }
releaseCheckArgs() { ScriptArgGet "check" -- "$@"; }
releaseCheckCommand() { (( $(echo "$(os release) $check" | bc --mathlib) )); }

versionCommand() { RunPlatform version; }
versionMac() { system_profiler SPSoftwareDataType | grep "System Version" | cut -f 10 -d" "; }
versionWin() { buildWin; }

versionLinux()
{
	if IsPlatform ubuntu; then lsb_release -ds | cut -d" " -f2 # Ubuntu 20.04.5 LTS
	elif [[ -f "/etc/debian_version" ]]; then cat "/etc/debian_version"
	else lsb_release -rs
	fi
}

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
	   --status			provide status (periods) on standard error
	-w|--what LIST	comma separated list of items to show

Items (basic): ${infoBasic[*]}
	 (detail): ${infoDetail[*]}
	 (other): ${infoOther[*]}

Examples:
os info -w=disk_free pi11,pi2		# free disk space for specified hosts
os info -w=disk_free all				# free disk space for all hosts"
}

infoArgStart() 
{ 
	unset -v detail monitor prefix status
	hostArg="localhost" what=() skip=()
	infoBasic=(model platform distribution kernel firmware chroot vm cpu architecture credential file other update reboot)
	infoDetail=(mhz memory process disk package switch restart)
	infoOther=( disk_free disk_total disk_used memory_free memory_total memory_used)
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
		--status) status="--status";;
		-w|--what|-w=*|--what=*) ScriptArgItems "what" "infoAll" "$@" || return;;
		*) return 1;;
	esac
}

infoCommand() { [[ $monitor ]] && { infoMonitor; return; } || infoHosts; }
infoHost() { if IsLocalHost "$host"; then infoLocal; else infoRemote; fi; }
infoMonitor() { watch -n 1 os info "$hostArg" --dynamic "${remoteArgs[@]}"; }
infoSetRemoteArgs() { remoteArgs=( $detail $prefix "${skipArg[@]}" "${whatArg[@]}" "${globalArgs[@]}" ); }

infoHosts()
{
	local host hosts; GetHosts || return
	(( ${#hosts[@]} > 1 )) && { prefix="--prefix"; infoSetRemoteArgs; }
	local errors=0

	for host in "${hosts[@]}"; do
		infoHost || (( ++errors ))
		[[ $status ]] && PrintErr "."
	done

	return $errors
}

infoEcho()
{
	[[ $prefix ]] && printf "$HOSTNAME "
	echo "$1"
}

infoPrint()
{
	[[ $prefix ]] && printf "%s" "$HOSTNAME "
	printf "%s" "$1"
}

infoRemote()
{
	# check for ssh
	! SshIsAvailablePort "$host" && { infoEcho "$host Operating System information is not available"; return; }

	# get detailed information using the os command on the host if possible
	# - switch information requires credential
	SshInPath "$host" "os" && { RunLog SshHelper connect "$host" --credential --hashi "${globalArgsLessVerbose[@]}" -- os info "${remoteArgs[@]}"; return; }
	
	# othereise, get basic information using HostGetInfo vars command locally
	ScriptEval HostGetInfo vars "$host" || return
	[[ $_platformOs ]] &&		infoEcho "    platform: $_platformOs"
	[[ $_platformLike ]] && infoEcho "        like: $_platformLike"
	[[ $_platformId ]] &&		infoEcho "          id: $_platformId"

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
		"info${w^}" || return
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

	model="$(lscpu | grep "^Model name:" | cut -d: -f 2 | RemoveNewline | tr -s " " | RemoveSpaceTrim)" # Rock 5 has multiple different types of CPUs
	count="$(lscpu | grep "^CPU(s):" | cut -d: -f 2 | RemoveSpace)"
	infoEcho "         cpu: $model ($count CPU)"
}

infoCredential()
{
	local name; name="$(credential manager name)"
	local status; status="$(credential manager status | sed 's/.*(//' | cut -d')' -f1)"
	infoEcho "  credential: $name ($status)"
}

infoDisk()
{ 
 ! InPath di && return; local disks; disks="$(di --type ext4 | grep "^/dev" | wc -l)"
 infoEcho " system disk: $(infoDiskGet used 1)/$(infoDiskGet free 1)/$(infoDiskGet total 1) GB used/free/total"; 
 (( disks > 1 )) && infoEcho "   data disk: $(infoDiskGet used 2)/$(infoDiskGet free 2)/$(infoDiskGet total 2) GB used/free/total"; 
 return 0
}

infoDiskGet() { echo "$(StringPad "$(disk${1^}Command $2)" 6)"; } # infoDiskGet COMMAND DISK

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

infoFirmware() { RunPlatform infoFirmware; }
infoFirmwarePiKernel() { infoEcho "    firmware: $(pi info firmware)"; }

infoKernel()
{
	local bits; bits="$(bitsCommand)"; [[ $bits ]] && bits=" ($bits bit)"
	infoEcho "      kernel: $(uname -r)$bits"
	RunPlatform infoKernel;
}

infoMemory() { infoEcho "      memory: $(infoMemoryGet used)/$(infoMemoryGet free)/$(infoMemoryGet total 2) GB used/free/total"; }
infoMemoryGet() { echo "$(StringPad "$(memory${1^}Command)" ${2:-5})"; } # infoDiskGet COMMAND DISK
infoMemory_free() { infoEcho "memory free: $(memoryFreeCommand) GB"; }
infoMemory_total() { infoEcho "memory total: $(memoryTotalCommand) GB"; }
infoMemory_used() { infoEcho "memory used: $(memoryUsedCommand) GB"; }

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

infoUpdate()
{
	local date; date="$(UpdateDate "update-default" 2>&1)" || date="never"
	infoEcho " last update: $date"
}

infoReboot()
{
	local detail status="no"; RunPlatform "infoReboot" || status="yes"
	[[ ! $ran ]] && return
	infoEcho "needs reboot: ${status}${detail}"
}

infoRebootDebian()
{
	ran="true"

	# packages
	local file="/var/run/reboot-required.pkgs"
	if [[ -f "$file" ]]; then
		local packages; IFS=$'\n' packages=( $(cat "$file") )
		detail=" (${packages[@]})"
		return 1
	fi

	# other
	[[ -f "/var/run/reboot-required" ]] && return 1

	return 0
}

infoRestart()
{
	local detail ran status="no"; RunPlatform "infoRestart" || status="yes"
	[[ ! $ran ]] && return
	infoEcho "     restart: ${status}${detail}"
}

infoRestartDebian()
{
	! InPath needrestart && return
	ran="true"

	# setup sudo - run outside of subshell so stdout is available
	sudov "${globalArgsLessVerbose[@]}" || return

	# get result
	local result; result="$(sudo needrestart -b)"

	# parse result
	local kernel services containers sessions
	kernel="$(echo "$result" | grep "^NEEDRESTART-KSTA:" | cut -d":" -f2 | RemoveSpaceTrim)"; (( kernel == 1 )) && kernel=0
	services="$(echo "$result" | grep "^NEEDRESTART-SVC:" | wc -l | RemoveSpaceTrim)"
	sessions="$(echo "$result" | grep "^NEEDRESTART-SESS:" | wc -l | RemoveSpaceTrim)"
	containers="$(echo "$result" | grep "^NEEDRESTART-CONT:" | wc -l | RemoveSpaceTrim)"

	# nothing requires a restart, return 0
	(( kernel == 0 && services == 0 && sessions == 0 && containers == 0 )) && return

	# build detail of what needs a restart, i.e. kernel ABI, 4 sessions, 2 services
	detail=" ("
	(( kernel != 0 && kernel == 2 )) && detail+="kernel ABI, "
	(( kernel != 0 && kernel == 3 )) && detail+="kernel, "
	(( services != 0 )) && detail+="$services services, "
	(( sessions != 0 )) && detail+="$sessions sessions, "
	(( containers != 0 )) && detail+="$containers containers, "
	detail="$(RemoveEnd "$detail" ", "))"

	# restarts required, return 1
	return 1
}

infoVm()
{
	! IsVm && return
	infoEcho "          vm: $(VmType)"
}

# infoDistribution
infoDistribution() { RunPlatform "infoDistribution"; }

infoDistributionLinux() # distributor version (CodeName)
{
	! InPath lsb_release && return

	# primary
	local suffix; IsPlatform CasaOs,pi && suffix="/Debian"
	local primary; primary="$(distributorLinux)$suffix $(versionLinux) ($(codeNameLinux))"

	# secondary
	local secondary;
	if IsPlatform DebianLike && ! IsPlatform CasaOs,pi; then
		local version; version="$(cat "/etc/debian_version")"
		local codeName; codeName="$(debianVersionToCodeName "$version")"
		IsPlatform ubuntu && codeName="$version" version="$(debianCodeNameToVersion "$version")" 
		secondary+="Debian $version ($codeName)"
	fi

	# use primary and secondary distributions if they are distinct
	local distribution="$primary"
	[[ $secondary && "$primary" != "$secondary" ]] && distribution+=" / $secondary"
	
	infoEcho "distribution: $distribution"
}

infoDistributionMac()
{
	infoEcho "distribution: macOS $(versionCommand) ($(codenameCommand), build $(buildCommand))"
}

infoDistributionWin()
{	
	local build; build="$(buildCommand)"
	local ubr; ubr="$(HexToDecimal "$(registry get "HKEY_LOCAL_MACHINE/SOFTWARE/Microsoft/Windows NT/CurrentVersion/UBR" | RemoveCarriageReturn)")" # UBR (Update Build Revision)
	local version="11"; (( $(os build) < 22000 )) && version="10" # 10|11
	infoDistributionLinux && infoEcho "              Windows $version (build $build.$ubr, wsl $(wsl get version), wslg $(wsl get version wslg))"
}

#
# helper
#

debianCodeNameToVersion()
{
	# https://en.wikipedia.org/wiki/Debian_version_history 
	case "$(echo "$1" | cut -d"/" -f1)" in # remove /sid, sid=rolling release
		jessie) echo "8";;
		stretch) echo "9";;
		buster) echo "10";;
		bullseye) echo "11";;
		bookworm) echo "12";;
		trixie) echo "13";;
		forky) echo "14";;
		*) echo "unknown";;
	esac
}

debianVersionToCodeName()
{
	# https://en.wikipedia.org/wiki/Debian_version_history
	case "$(echo "$1" | cut -d"." -f1)" in
		8) echo "jessie";;
		9) echo "stretch";;
		10) echo "buster";;
		11) echo "bullseye";;
		12) echo "bookworm";;
		13) echo "trixie";;
		14) echo "forky";;
	esac
}

systemProperties()
{
	! IsPlatform win && return
	local tab=; [[ $1 ]] && tab=",,$1"; 
	rundll32.exe /d "shell32.dll,Control_RunDLL SYSDM.CPL$tab"
}

ScriptRun "$@"
