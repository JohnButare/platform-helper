#!/usr/bin/env bash
. "${BASH_SOURCE[0]%/*}/function.sh" script || exit

usage()
{
	ScriptUsage "$1" "\
Usage: os [COMMAND]... [OPTION]...
Operating system commands

	disk					[available|total](total)
	executable		executable information
	location			location information
	memory				[available|total](total)
	name					show or set the operating system name

	info|architecture|bits|build|CodeName|hardware|IsServer|mhz|release|version
	dark|environment|index|path|lock|preferences|store
	features|repair|security|virus"
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
	di --type ext2,ext3,ext4 --display-size g | grep "^/dev" | head -$disk | ${G}tail --lines=-1 | tr -s ' ' | cut -d" " -f 5
}

# diskTotalCommand [N](1) - disk N from space.    Disk 1 is the main disk, 2 is the next, etc.
diskTotalCommand()
{
	! InPath di && return; local disk="${1:-1}"
	di --type ext2,ext3,ext4 --display-size g | grep "^/dev" | head -$disk | ${G}tail --lines=-1 | tr -s ' ' | cut -d" " -f 3
}

# diskUsedCommand [N](1) - disk N from space.    Disk 1 is the main disk, 2 is the next, etc.
diskUsedCommand()
{
	! InPath di && return; local disk="${1:-1}"
	di --type ext2,ext3,ext4 --display-size g | grep "^/dev" | head -$disk | ${G}tail --lines=-1 | tr -s ' ' | cut -d" " -f 4
}

#
# executable command
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

executableIdArgs() { ScriptArgGet "file" -- "$@" && ScriptCheckFile "$file"; }

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

executableFindArgs() { ScriptArgGet "dir" -- "$@" && ScriptCheckDir "$dir"; }

executableFindCommand()
{
	local arch file

	# find an executable that supports the primary architecture
	arch="$(executableFormatCommand)" || return
	log2 "architecture=$arch"
	file="$(file "$dir"/* | sort -V | grep "$arch" | ${G}tail --lines=-1 | cut -d: -f1)"
	log2 "file=$file"
	file="${file% (for architecture $(architectureFileCommand))}" # remove suffix for mac universal binaries
	[[ $file ]] && { echo "$file"; return; }

	# see if we can find an executable the supports an alternate architecture if the platform supports one
	arch="$(alternateExecutableFormatCommand)"; [[ ! $arch ]] && return 1
	file="$(file "$dir"/* | sort -V | grep "$arch" | ${G}tail --lines=-1 | cut -d: -f1)"
	file="${file% (for architecture $(architectureFileCommand))}" # remove suffix for mac universal binaries
	[[ $file ]] && { echo "$file"; return; }

	return 1
}

#
# feature commands
#

featureUsage() { echot "Usage: os feature\n	Operating system features."; }
featureCommand() { RunPlatform feature; }
featureWin() { RunScript --elevate -- Dism.exe /Online /Get-Features; }

#
# location command
#

locationUsage() 
{
	echot "Usage: os location desktop|documents
Return platform operating system locations."
}

locationCommand() { usage; }

locationDesktopCommand()
{
	IsPlatform win && { wtu "$(powershell "[Environment]::GetFolderPath('Desktop')" | RemoveCarriageReturn)"; return; }
	echo "$HOME/Desktop"
}

locationDocumentsCommand()
{
	IsPlatform win && { wtu "$(powershell "[Environment]::GetFolderPath('MyDocuments')")" | RemoveCarriageReturn; return; }
	echo "$HOME/Documents"
}

#
# memory command
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
Usage: os name [get|set|alias|real](get) [HOST](localhost)
Show or set the operating system name."
}

nameArgStart() { unset name; }
nameArgs() { (( ! $# )) && return; ScriptArgGet "name" -- "$@"; }
nameCommand() { nameGetCommand; }

#
# name alias command
#

nameAliasUsage() { echot "Usage: os name alias HOST\nGet the alias of the host from the real name."; }

nameAliasCommand()
{
	local check="${name:-$HOSTNAME}"; check="$(RemoveDnsSuffix "${check,,}")"

	case "$check" in
		s1113731) echo "desktop";;
		s1114928) echo "laptop";;
		s1081454) echo "rack";;
		*) echo "$name";;

	esac	
}

#
# name get command
#

nameGetUsage()
{
	echot "\
Usage: os name get HOST
Get the operating system name.

	-s|--ssh	use SSH to get the name instead of using DNS (slower)"
}

nameGetArgStart() { unset -v ssh; }
nameGetOpt()
{
	case "$1" in
		-s|--ssh) ssh="true";;
		*) return 1;;
	esac
}

nameGetCommand()
{
	IsLocalHost "$name" && { echo "$HOSTNAME"; return; }

	# check cache
	local actualName cache="os-name-$name"
	actualName="$(UpdateGet "$cache")" && [[ $actualName ]] && { echo "$actualName"; return; }

	# check
	if [[ $ssh ]]; then
		log3 "using SSH to get the name of '$host'"
		actualName="$(SshHelper --quiet connect "$name" -- hostname)"
	else
		log3 "using DNS to resolve the name of '$host'"
		actualName="$(DnsResolve "$name" --quiet "${globalArgs[@]}")"

		# check virtual host
		! [[ "$actualName" ]] && actualName="$(DnsResolve "$HOSTNAME-$name" --quiet  "${globalArgs[@]}")"

		# if the actual name is a superset of the DNS name use the full name
		# - this seems too broad, find the use case for this
		[[ "$name" =~ $actualName$ ]] && actualName="$name"	

	fi

	# if we could not find the actual name use the passed name
	[[ ! $name ]] && { log3 "could not find the actual name of '$host', using passed name"; actualName="$name"; }

	# cache
	UpdateSet "$cache" "$actualName"

	# return
	echo "$actualName"
}

#
# name set command
#

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
	sudov || return
	networksetup -setcomputername "$name" || return 2
	sudo scutil --set HostName "$name" || return 2
	sudo scutil --set LocalHostName "$name" || return 2
	sudo scutil --set ComputerName "$name" || return 2
	dscacheutil -flushcache
}

#
# name real command
#

nameRealUsage() { echot "Usage: os name real ALIAS\nGet the real name of the host from an alias."; }

nameRealCommand()
{
	local check="$(RemoveDnsSuffix "${name,,}")"

	case "$check" in
		desktop|mac) echo "s1113731";;
		laptop) echo "s1114928";;
		rack) echo "s1081454";;
		*) echo "$name";;
	esac	
}

#
# Information Commands
#

architectureUsage() { echot "Usage: os architecture [bits] [MACHINE]\n	Show the architecture of the current machine or the specified machine.  Returns arm, mips, or x86."; }
architectureArgStart() { unset -v machine; }
architectureArgs() { (( ! $# )) && return; ScriptArgGet "machine" -- "$@"; }

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
architectureFileArgs() { (( ! $# )) && return; ScriptArgGet "machine" -- "$@"; }

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
bitsArgs() { (( ! $# )) && return; ScriptArgGet "machine" -- "$@"; }

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

	ScriptErrQuiet "Unable to determine the operating systems bits"
}

buildCommand() { RunPlatform "build"; } 
buildMac() { system_profiler SPSoftwareDataType | grep "System Version" | cut -f 11 -d" " | sed 's/(//' | sed 's/)//'; }
buildLinux() { versionCommand; }
buildWin() { registry get "HKEY_LOCAL_MACHINE/SOFTWARE/Microsoft/Windows NT/CurrentVersion/CurrentBuild" | RemoveCarriageReturn; }

codenameCommand()
{
	local name; name="$(RunPlatform "codeName")" && [[ $name ]] && { echo "$name"; return; }
	ScriptErrQuiet "unable to determine the code name"
}

codeNameWin() { codeNameLinux; }

codeNameLinux() # buster|focal|jammy
{
	if InPath lsb_release; then lsb_release -cs
	elif IsPlatform rhel && [[ -f "/etc/system-release" ]]; then cat "/etc/system-release" | cut -d"(" -f2 | cut -d")" -f1
	fi
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
		14.*) echo "Sonoma";;
		15.*) echo "Sequoia";;
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
		linux) [[ ! $XDG_CURRENT_DESKTOP ]];;
		mac) return 1;;
		win) CanElevate && registry get "$r/ProductName" | RemoveCarriageReturn | grep -q -i "server";;
	esac
}

releaseUsage() { ScriptUsageEcho "Usage: $(ScriptName) release [check]"; }
releaseCommand() { RunPlatform "release"; }
releaseDebian() { lsb_release -rs | ${G}grep -v "No LSB"; }
releaseRhel() { rpm --query redhat-release; }

releaseCheckUsage() { ScriptUsageEcho "Usage: $(ScriptName) release check EXPR\nCheck the version, where check is an expression to check the version against, i.e. release check '>= 23.10'."; }
releaseCheckArgStart() { unset -v check; }
releaseCheckArgs() { ScriptArgGet "check" -- "$@"; }
releaseCheckCommand() { (( $(echo "$(os release) $check" | bc --mathlib) )); }

versionCommand() { RunPlatform version; }
versionMac() { system_profiler SPSoftwareDataType | grep "System Version" | cut -f 10 -d" "; }
versionWin() { buildWin; }

versionLinux()
{
	if IsPlatform rhel; then ( eval "$(cat "/etc/os-release")"; echo "$VERSION_ID"; )
	elif IsPlatform ubuntu; then lsb_release -ds | cut -d" " -f2 # Ubuntu 20.04.5 LTS
	elif [[ -f "/etc/debian_version" ]]; then cat "/etc/debian_version"
	else lsb_release -rs
	fi
}

versionMajorCommand()
{
	if IsPlatform rhel; then versionCommand | cut -d"." -f1
	else versionCommand
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
	infoBasic=(model platform distribution kernel firmware chroot vm cpum architecture credential file network other update reboot)
	infoDetail=(cpu load mhz process memory disk package switch restart)
	infoOther=( disk_free disk_total disk_used memory_free memory_total memory_used)
	infoAll=( "${infoBasic[@]}" "${infoDetail[@]}" "${infoOther[@]}" )
}

infoArgs() { (( ! $# )) && return; ScriptArgGet "hostArg" -- "$@"; }
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
	[[ $_platformOs ]] &&	infoEcho       "    platform: $_platformOs"
	[[ $_platformIdMain ]] &&	infoEcho   "          id: $_platformIdMain"
	[[ $_platformIdLike ]] && infoEcho   "        like: $_platformIdLike"
	[[ $_platformIdDetail ]] && infoEcho "      detail: $_platformIdDetail"

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

infoCpum()
{
	! InPath lscpu && return

	local model count

	model="$(lscpu | grep "^Model name:" | cut -d: -f 2 | RemoveNewline | tr -s " " | RemoveSpaceTrim)" # Rock 5 has multiple different types of CPUs
	count="$(lscpu | grep "^CPU(s):" | cut -d: -f 2 | RemoveSpace)"
	infoEcho "   cpu model: $model ($count CPU)"
}

infoCpu()
{
	! InPath vmstat && return
	local cpu; cpu="$[100-$(vmstat 1 2| ${G}tail --lines=-1|awk '{print $15}')]%"
	infoEcho "         cpu: $cpu"
}

infoCredential()
{
	local name; name="$(credential manager name --quiet)"; [[ ! $name ]] && { infoEcho "  credential: none"; return; }
	local status; status="$(credential manager status | sed 's/.*(//' | cut -d')' -f1)"
	infoEcho "  credential: $name ($status)"
}

infoDisk()
{ 
 ! InPath di && return; local disks; disks="$(di --type ext2,ext3,ext4 | grep "^/dev" | wc -l)"
 infoEcho " system disk: $(infoDiskGet used 1)/$(infoDiskGet free 1)/$(infoDiskGet total 1) GB used/free/total"; 
 (( disks > 1 )) && infoEcho "   data disk: $(infoDiskGet used 2)/$(infoDiskGet free 2)/$(infoDiskGet total 2) GB used/free/total"; 
 return 0
}

infoDiskGet() { echo "$(StringPad "$(disk${1^}Command $2)" 6)"; } # infoDiskGet COMMAND DISK

infoDisk_free() { ! InPath di && return; infoEcho "   disk free: $(diskFreeCommand) GB"; }
infoDisk_total() { ! InPath di && return; infoEcho "  disk total: $(diskTotalCommand) GB"; }
infoDisk_used() { ! InPath di && return; infoEcho "   disk used: $(diskUsedCommand) GB"; }

infoFile()
{
	infoEcho "file sharing: $(unc get protocols "$HOSTNAME")" || return
}

infoFirmware() { RunPlatform infoFirmware; }

infoFirmwarePiKernel()
{
	IsPlatform cm4 && return
	infoEcho "    firmware: $(pi info firmware)"; 
}

infoKernel()
{
	local bits; bits="$(bitsCommand)"; [[ $bits ]] && bits=" ($bits bit)"
	infoEcho "      kernel: $(uname -r)$bits"
	RunPlatform infoKernel;
}

infoLoad()
{
	local load; load="$(uptime | cut -d' ' -f13 | RemoveEnd ",")"
	infoEcho "        load: $load"
}

infoMemory() { infoEcho "      memory: $(infoMemoryGet used)/$(infoMemoryGet free)/$(infoMemoryGet total 2) GB used/free/total"; }
infoMemoryGet() { echo "$(StringPad "$(memory${1^}Command)" ${2:-5})"; } # infoMemoryGet COMMAND [PAD](5)
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

infoNetwork()
{
	infoEcho "     network: mac=$(GetMacAddress)" || return
	if IsIpvSupported 4; then
		local ip; ip="$(GetIpAddress4)" || return
		local desc; [[ $detail ]] && IsIpvSupported 6 && desc+=" (IPv6 token=$(Ipv6Token "$ip"))"
		infoEcho "              IPv4=$ip$desc" || return
	fi

	if IsIpvSupported 6; then
		infoEcho "              IPv6=$(GetIpAddress6)" || return
	fi

	return 0
}

infoOther() { RunPlatform infoOther; }
infoOtherPiKernel() {	infoEcho "    CPU temp: $(pi info temp)"; }

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

infoUpdate()
{
	local date; date="$(UpdateDate "update-default" 2>&1)" || date="never"
	infoEcho " last update: $date"
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
	InPath lsb_release && { infoDistributionLsb; return; }
	IsPlatform rhel && { infoEcho "distribution: $(hostnamectl | grep "^[ ]*Operating System:" | cut -d":" -f2 | RemoveSpaceTrim)"; return; }
}

infoDistributionLsb()
{
	# primary
	local suffix; IsPlatform CasaOs,pi && suffix="/Debian"
	local codeName="$(quiet="--quiet" codenameCommand)"
	local primary; primary="$(distributorLinux)$suffix $(versionLinux) (${codeName:-unknown})"

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
# repair commands
#

repairUsage() { echot "Usage: os repair\n	Repair the operating system."; }
repairCommand() { RunPlatform repair; }

repairWin()
{
	ask "Fix from known good copies" && { sfc.exe /scannow || return; }
	ask "Repair known good copies" && { DISM.exe /Online /Cleanup-Image /RestoreHealth || return; }
	return 0
}

#
# security commands
#

securityUsage() { echot "Usage: os security gui|tray\n	Security commands."; }
securityCommand() { usage; }

securityGuiCommand() { RunPlatform securityGui; }
securityGuiWin() { start "windowsdefender://"; }

securityTrayCommand() { RunPlatform securityTray; }
securityTrayWin() { cmd.exe /c start "SecurityHealthSystray.exe" >& /dev/null; }

#
# virus commands
#

virusUsage() { echot "Usage: os virus enable|gui|run|status\n	Virus scanner commands."; }
virusArgStart() { services=(Sense WdBoot WdFilter WdNisDrv WdNisSvc WinDefend); }
virusCommand() { usage; }

virusEnableCommand() { RunPlatform virusEnable; }
virusEnableWin() { service disable "Sense" && service boot "WdBoot" && service boot "WdFilter" && service demand "WdNisDrv" && service demand "WdNisSvc" && service auto "WinDefend"; }

virusGuiCommand() { RunPlatform virusGui; }
virusGuiWin() { start "windowsdefender://threat"; }

virusRunUsage() { virusRunCli; }
virusRunArgStart() { virusArgs=(-Scan -ScanType 1); }
virusRunArgs() { (( ! $# )) && return; virusArgs=("$@"); shift+="$#"; }
virusRunCommand() { RunPlatform virusRun; }
virusRunWin() { virusRunCli "${virusArgs[@]}" "${otherArgs[@]}"; }

virusRunCli() { RunPlatform virusRunCli; }
virusRunCliWin() { "$P/Windows Defender/MpCmdRun.exe" "$@"; }

virusStatusCommand()
{
	[[ $verbose ]] && { for service in "${services[@]}"; do service detail $service; done; return; }
	for service in "${services[@]}"; do service status $service; done
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
