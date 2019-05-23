# function.sh: common functions for non-interactive scripts

#
# Configuration
#

InitializeBash()
{
	local file="${BASH_SOURCE[0]%/*}/bash.bashrc" 
	[[ ! $SUDO_USER && $PS1 ]] && echo "WARNING: $file was not sourced in /etc/bash.bashrc"
	[[ -f "$file" ]] && . "$file"
}

[[ ! $BIN ]] && InitializeBash

FUNCTIONS="true"
shopt -s nocasematch extglob 

#
# Platform
# 
# PLATFORM=linux|win|mac
# PLATFORM_LIKE=cygwin|debian|openwrt|synology
# PLATFORM_ID=dsm|srm|raspian|ubiquiti|ubuntu

[[ "$PLATFORM" == "win" ]] && . function.win.sh

# GetPlatform [host](local) - get platform, platformLike, and platformId for the host
# testing:  sf; time GetPlatform nas1 && echo "success: $platform-$platformLike-$platformId"
function GetPlatform() 
{
	local results host="$1" cmd='echo platform=$(uname); echo kernel=\"$(uname -r)\"; [[ -f /etc/os-release ]] && cat /etc/os-release; [[ -f /var/sysinfo/model ]] && echo ubiquiti=true; [[ -f /proc/syno_platform ]] && echo synology=true && [[ -f /bin/busybox ]] && echo busybox=true'

	if [[ $host ]]; then
		#HostUtil available $host || { EchoErr "$host is not available"; return 1; } # adds .5s
		results="$(ssh ${host,,} "$cmd")" ; (( $? > 1 )) && return 1
	else
		results="$(eval $cmd)"
	fi

	results="$(
		eval $results
		case "$platform" in 
			CYGWIN*) platform="win"; ID_LIKE=cygwin;;
			Darwin)	platform="mac";;
			Linux) platform="linux";;
			MinGw*) platform="win"; ID_LIKE=mingw;;
		esac
		[[ $kernel =~ .*-Microsoft ]] && platform="win" # Windows Subsytem for Linux
		[[ $ID_LIKE =~ openwrt ]] && ID_LIKE="openwrt"
		[[ $ubiquiti ]] && ID="ubiquiti"
		[[ $synology ]] && { ID_LIKE="synology"; ID="dsm"; [[ $busybox ]] && ID="srm"; }
		echo platform="$platform"
		echo platformLike="$ID_LIKE"
		echo platformId="$ID"
	)"

	eval $results
	return 0
}
[[ "$PLATFORM_ID" && "$PLATFORM_LIKE" && "$PLATFORM_ID" ]] || { GetPlatform; PLATFORM="$platform" PLATFORM_ID="$platformId" PLATFORM_LIKE="$platformLike"; unset platform platformId platformLike; }

# IsPlatform platform[,platform,...] [platform platformLike PlatformId](PLATFORM PLATFORM_LIKE PLATFORM_ID)
function IsPlatform()
{
	local checkPlatforms="$1" platforms p
	local platform="${2:-$PLATFORM}" platformLike="${3:-$PLATFORM_LIKE}" platformId="${4:-$PLATFORM_ID}"

	for p in ${checkPlatforms//,/ }; do
		case "$p" in 
			win|mac|linux) [[ "$p" == "$platform" ]] && return 0;;
			wsl) [[ "$platform" == "win" && "$platformLike" == "debian" ]] && return 0;; # Windows Subsystem for Linux
			cygwin|debian|mingw|openwrt|synology) [[ "$p" == "$platformLike" ]] && return 0;;
			dsm|srm|raspbian|ubiquiti|ubuntu) [[ "$p" == "$platformId" ]] && return 0;;
			busybox) InPath busybox && return 0;;

			# package management
			apt) InPath apt && return 0;;
			ipkg) InPath ipkg && return 0;;
			opkg) InPath opkg && return 0;;
		esac
	done

	return 1
}

function RunPlatform()
{
	local function="$1"

	RunFunction $function $PLATFORM_ID || return
	RunFunction $function $PLATFORM_LIKE || return
	RunFunction $function $PLATFORM || return
	IsPlatform wsl && { RunFunction $function wsl || return; }
	IsPlatform cygwin && { RunFunction $function cygwin || return; }
	return 0
}

package() { sudo apt-get install -y "$@" || return; }

#
# Other
#

EvalVar() { r "${!1}" $2; } # EvalVar <variable> <var> - return the contents of the variable in variable, or set it to var
IsUrl() { [[ "$1" =~ http[s]?://.* ]]; }
IsInteractive() { [[ "$-" == *i* ]]; }
r() { [[ $# == 1 ]] && echo "$1" || eval "$2=""\"${1//\"/\\\"}\""; } # result VALUE VAR - echo value or set var to value (faster), r "- '''\"\"\"-" a; echo $a

clipw() 
{ 
	case "$PLATFORM" in 
		linux) { [[ "$DISPLAY" ]] && InPath xclip; } && { echo -n "$@" | xclip -sel clip; };;
		mac) echo -n "$@" | pbcopy;; 
		win) IsPlatform cygwin && echo -n "$@" > /dev/clipboard || echo -n "$@" | clip.exe;;
	esac
}

clipr() 
{ 
	case "$PLATFORM" in
		linux) InPath xclip && xclip -o -sel clip;;
		mac) pbpaste;;
		win) IsPlatform cygwin && cat /dev/clipboard;;
	esac
}

#
# scripts
#

IsInstalled() { type "$1" >& /dev/null && command "$1" IsInstalled; }
FilterShellScript() { egrep "shell script|bash.*script|Bourne-Again shell script|\.sh:|\.bash.*:"; }
IsShellScript() { file "$1" | FilterShellScript >& /dev/null; }
IsOption() { [[ "$1" =~ ^-.* ]]; }
IsWindowsOption() { [[ "$1" =~ ^/.* ]]; }
UnknownOption() {	EchoErr "$(ScriptName): unknown option \`$1\`"; EchoErr "Try \`$(ScriptName) --help\` for more information";	exit 1; }
MissingOperand() { EchoErr "$(ScriptName): missing $1 operand"; exit 1; }
IsDeclared() { declare -p "$1" >& /dev/null; } # IsDeclared NAME - NAME is a declared variable
IsFunction() { declare -f "$1" >& /dev/null; } # IsFunction NAME - NAME is a function
GetFunction() { declare -f | egrep -i "^$1 \(\) $" | sed "s/ () //"; return ${PIPESTATUS[1]}; } # GetFunction NAME - get function NAME case-insensitive

# RunFunction NAME SUFFIX - call a function with the specified suffix
RunFunction()
{ 
	local method="$1" suffix="$2"
	[[ $suffix ]] && IsFunction $method${suffix^} && { $method${suffix^}; return; }
	return 0
}

IsAlias() { type "-t $1" |& grep alias > /dev/null; } # IsAlias NAME - NAME is an alias
GetAlias() { local a=$(type "$1"); a="${a#$1 is aliased to \`}"; echo "${a%\'}"; }

CheckCommand() 
{	
	[[ ! $1 ]]  && MissingOperand "command"
	IsFunction "${1,,}Command" && { command="${1,,}"; return 0; } ; 
	EchoErr "$(ScriptName): unknown command \`$1\`"
	EchoErr "Try \`$(ScriptName) --help\` for valid commands"
	exit 1
} 

CheckSubCommand() 
{	
	local sub="$1"; command="$2"; 
	[[ ! $command ]]  && MissingOperand "$sub command"
	ProperCase "$sub" sub; ProperCase "$command" command; 
	IsFunction "${sub}${command}Command" && { command="$command"; return 0; }
	EchoErr "$(ScriptName): unknown $1 command \`$2\`"
	EchoErr "Try \`$(ScriptName) $1 --help\` for valid commands"
	exit 1
} 

ScriptName() { GetFileName $0; }
ScriptCd() { local dir; dir="$("$@" | ${G}head --lines=1)" && { echo "cd $dir"; cd "$dir"; }; }  # ScriptCd <script> [arguments](cd) - run a script and change the directory returned, does not work with aliases
ScriptEval() { local result; result="$("$@")" || return; eval "$result"; } # ScriptEval <script> [<arguments>] - run a script and evaluate it's output, typical variables to set using  printf "a=%q;b=%q;" "result a" "result b", does not work with aliases

ScriptReturn() # ScriptReturns [-s|--show] <var>...
{
	local var avar fmt="%q" arrays export
	[[ "$1" == @(-s|--show) ]] && { fmt="\"%s\""; shift; }
	[[ "$1" == @(-e|--export) ]] && { export="export "; shift; }

	# cache array lookup for performance
	arrays="$(declare -p "$@" |& grep "^declare -a" 2> /dev/null)"

	for var in "$@"; do
		check=".*declare -a ${var}=.*"
		if [[ "$arrays" =~ $check ]]; then
			avar="$var[@]"
			printf "$var=("
			for value in "${!avar}"; do printf "$fmt " "$value"; done; 
			echo ") "
		else
			printf "$export$var=$fmt\n" "${!var}"
		fi
	done;		
}

#
# File System
#

fpc() { local arg; [[ $# == 0 ]] && arg="$PWD" || arg="$(${G}realpath -m "$1")"; echo "$arg"; clipw "$arg"; } # full path to clipboard
pfpc() { local arg; [[ $# == 0 ]] && arg="$PWD" || arg="$(${G}realpath -m "$1")"; clipw "$(utw "$arg")"; } # full path to clipboard in platform specific format
GetBatchDir() { GetFilePath "$0"; }
GetFileSize() { [[ ! -e "$1" ]] && return 1; local size="${2-MB}"; [[ "$size" == "B" ]] && size="1"; s="$(${G}du --apparent-size --summarize -B$size "$1" |& cut -f 1)"; echo "${s%%*([[:alpha:]])}"; } # FILE [SIZE]
GetFilePath() { local gfp="${1%/*}"; [[ "$gfp" == "$1" ]] && gfp=""; r "$gfp" $2; }
GetFileName() { r "${1##*/}" $2; }
GetFileNameWithoutExtension() { local gfnwe="$1"; GetFileName "$1" gfnwe; r "${gfnwe%.*}" $2; }
GetFileExtension() { local gfe="$1"; GetFileName "$gfe" gfe; [[ "$gfe" == *"."* ]] && r "${gfe##*.}" $2 || r "" $2; }
GetDriveLabel() { local gdl="$(cmd /c vol "$1": |& head -1 | sed -e '/^Ma/d')"; r "${gdl## Volume in drive ? is }" $2; }
HideFile() { [[ -e "$1" ]] && attrib.exe +h "$(utw "$1")"; }
IsWindowsLink() { [[ "$PLATFORM" != "win" ]] && return 1; lnWin -s "$1" >& /dev/null; }
RemoveTrailingSlash() { r "${1%%+(\/)}" $2; }
InPath() { which "$1" >& /dev/null; }

FindInPath()
{
	type -P "${1}" && return
	IsPlatform wsl && { type -P "${1}.exe" && return; }
	return 1
}

GetFullPath() 
{ 
	local gfp="$(realpath -m "${@/#\~/$HOME}")"; r "$gfp" $2; # replace ~ with $HOME so we don't lost spaces in expanstion
}

HideAll()
{
	! IsPlatform win && return

	for f in $('ls' -A | egrep '^\.'); do
		attrib.exe +h "$f"
	done
}

# (Man)PathAdd <path> [front], front adds to front and drops duplicates in middle
PathAdd() {	[[ ! -d "$1" ]] && return; if [[ "$2" == "front" ]]; then PATH=$1:${PATH//:$1:/:}; elif [[ ! $PATH =~ (^|:)$1(:|$) ]]; then PATH+=:$1; fi; } 
ManPathAdd() { [[ ! -d "$1" ]] && return; if [[ "$2" == "front" ]]; then MANPATH=$1:${MANPATH//:$1:/:}; elif [[ ! $MANPATH =~ (^|:)$1(:|$) ]]; then MANPATH+=:$1; fi; }

# Path conversion - ensure symbolic links are dereferenced for use in Windows
[[ "$PLATFORM_LIKE" == "cygwin" ]] && wslpath() { cygpath "$@"; }

wtu() # WinToUnix
{
	[[ ! "$@" || "$PLATFORM" != "win" ]] && { echo "$@"; return 1; }
  wslpath -u "$*"
}

utw() # UnixToWin
{ 
	[[ ! "$@" || "$PLATFORM" != "win" ]] && { echo "$@"; return 1; }
	wslpath -w "$(realpath -m "$@")"
} 

utwq() { utw "$@" | QuoteBackslashes; } # UnixToWinQuoted

ptw() { echo "${1////\\}"; } # PathToWin

DirCount() { command ls "$1" | wc -l; return "${PIPESTATUS[0]}"; }

explore() # explorer DIR - explorer DIR in GUI program
{
	local dir="$1"; [[ ! $dir ]] && dir="."
	
	if [[ "$PLATFORM" == "mac" ]]; then
		open "$dir"
	elif [[ "$PLATFORM" == "win" ]]; then
		explorer.exe "$(utw "$dir")"
	elif [[ "$PLATFORM_LIKE" == "debian" ]] && InPath nautilus; then
		start nautilus "$dir"
	else
		EchoErr "The $PLATFORM_ID platform does not have a file explorer"
		return 1
	fi
}

GetDisks() # GetDisks ARRAY
{
	local getDisks disk;

	case "$PLATFORM" in
		linux) 
			for disk in /mnt/hgfs/*; do getDisks+=( "$disk" ); done # VMware host
			for disk in /media/psf/*; do getDisks+=( "$disk" ); done # Parallels hosts
			;;
		mac) IFS=$'\n' getDisks=( $(df | egrep "^/dev/" | gawk '{print $9}' | egrep -v '^/$|^/$') );;
		win) for disk in /cygdrive/*; do getDisks+=( "$disk" ); done;;
	esac

	CopyArray getDisks "$1"
}

CopyDir()
{
	local prefix="" cp="gcp" recursive="" o=(--force --preserve=timestamps) f=( );
		
	IsPlatform mac && { cp="acp"; o=(--progress); }
	
	# gcp requires an X display on some platforms, as a work around run with dbus-launch
	[[ ! "$DISPLAY" ]] && IsPlatform wsl,raspbian && { DbusSetup; prefix="dbus-launch"; }

	for arg in "$@"; do
		[[ ! $1 ]] && { shift; continue; } 										# ignore empty options
		[[ $1 == @(-r|--recursive) ]] && { o+=(--recursive); recursive="true"; shift; continue; }
		[[ $1 == @(-m|--mirror) ]] && { shift; continue; } 		# ignore --mirror (win only)
		[[ $1 == @(-q|--quiet) ]] && { shift; continue; }			# ignore --quiet (win only)
		[[ $1 == @(--retry) ]] && { shift; continue; }				# ignore --retry (win only)
		[[ $1 == @(-xd|-xf) ]] && { shift; while (( $# != 0 )) && ! IsOption "$1"; do shift; done; continue; } # ignore -xd and -xf (win only)
		f+=($1); shift
	done

	#o+=("--verbose")
	# cp dir1 dir2 will not copy the top level directory, need a way to copy only top level directory
	#dbus-launch gcp --recursive --force --preserve timestamps,mode --verbose /home/jjbutare/Volumes/public/documents/data/platform/linux/ /usr/local/data/platform/linux/ --recursive

	if [[ $recursive ]]; then
		$prefix $cp "${o[@]}" "${f[@]}" || return
	else
		# for non-recursive copies the source must be files and the destination directory must exist
		local src="${f[0]}"
		local dest="${f[1]}" made=""; [[ ! -d "$dest" ]] && { made="true"; mkdir --parents "$dest" || return; }
		$prefix $cp "${o[@]}" "$src"/* "$dest" || { [[ $made ]] && rm - fr "$dest"; return 1; }
	fi
}

if IsPlatform cygwin; then
	CopyDir()
	{
		[[ $1 == @(-h|--help) ]]	&& { echot "usage: CopyDir SRC DEST [FILES] [OPTIONS]
	-m, --mirror			remove extra files in DEST
	-q, --quiet				minimize logging
	-r, --recursively	copy directories recursively
	--retry 			retry copy on failure
	-v, --verbose			maximize logging
	-xd DIRS					exclude files matching the name/path/wildcard
	-xf FILES					exclude files matching the name/path/wildcard"; return 1; }

		local o=( /COPY:DAT /ETA ) mirror quiet src dest # /DCOPY:DAT requires newer robocopy

		for arg in "$@"; do
			[[ $1 == @(-m|--mirror) ]] && { mirror="true"; o+=( /mir ); shift; continue; }
			[[ $1 == @(-q|--quiet) ]] && { quiet="true"; o+=( /njh /njs /ndl ); shift; continue; }
			[[ $1 == @(-r|--recursive) ]] && { o+=( /E ); shift; continue; }
			[[ $1 == @(--retry) ]] && { o+=( /R:3 /W:2 ); shift; continue; }
			[[ $1 == @(-v|--verbose) ]] && { o+=( /V ); shift; continue; }
			IsOption "$1" && { o+=( "/${1:1}" ); shift; continue; }
			! IsOption "$1" && [[ ! $src ]] && { src="$(utw "$1")"; shift; continue; }
			! IsOption "$1" && [[ ! $dest ]] && { dest="$(utw "$1")"; shift; continue; }
			o+=( "$1" ); shift
		done
		[[ $quiet && ! $mirror ]] && o+=( /xx )

		robocopy "$src" "$dest" "${o[@]}"
		(( $? < 8 )) # http://support.microsoft.com/kb/954404
	}
fi

# FileCommand mv|cp|ren|hide SOURCE... DIRECTORY - mv or cp ignoring files that do not exist
FileCommand() 
{ 
	local args command="$1" dir="${@: -1}" file files=0 n
	[[ "$command" == "hide" ]] && n=$(($#-1)) || n=$(($#-2))

	[[ "$PLATFORM" != "win" && "$command" == @(hide|HideAndSystem) ]] && return 0
	
	for arg in "${@:2:$n}"; do
		IsOption "$arg" && args+=( "$arg" )
		[[ -e "$arg" ]] && { args+=( "$arg" ); (( ++files )); }
	done
	(( files == 0 )) && return 0

	case "$command" in
		hide) for file in "${args[@]}"; do attrib.exe +h "$(utw "$file")" || return; done;;
		HideAndSystem) for file in "${args[@]}"; do attrib +h +s "$(utw "$file")" || return; done;;
		ren) 'mv' "${args[@]}" "$dir";;
		*)
			[[ ! -d "$dir" ]] && { EchoErr "FileCommand: accessing \`$dir\`: No such directory"; return 1; }
			"$command" -t "$dir" "${args[@]}";;
	esac
}

# MoveAll SRC DEST - move contents of SRC to DEST including hidden files and folders
MoveAll() { [[ ! $1 || ! $2 ]] && { EchoErr "usage: MoveAll SRC DEST"; return 1; }; shopt -s dotglob nullglob; mv "$1/"* "$2" && rmdir "$1"; }

CpProgress()
{
	local src dest size=100 fileName
	[[ $# == 0 || $1 == @(--help) ]]	&& { EchoErr "usage: CpProgress FILE DIR
  -s, --size SIZE		show progress for files larger than SIZE MB"; return 1; }

	while (( $# != 0 )); do
		[[ "$1" == @(-s|--size) ]] && { size="$2"; shift; shift; continue; }
		! IsOption "$1" && [[ ! $src ]] && { src="$1"; shift; continue; }
		! IsOption "$1" && [[ ! $dest ]] && { dest="$1"; shift; continue; }
		EchoErr "CopyFile: unknown option `$1`"; return 1;
	done

	[[ ! -f "$src" ]] && { EchoErr "CopyFile: cannot access \`$src\`: No such file"; return 1; }
	[[ ! -d "$dest" ]] && { EchoErr "CopyFile: cannot access \`$dest\`: No such directory"; return 1; }		
	GetFileName "$src" fileName || return
	GetFilePath "$(GetFullPath "$src")" src || return

	local fileSize="$(GetFileSize "$src/$fileName" MB)" || return
	(( fileSize < size )) && 
		cp "$src/$fileName" "$dest" ||
		CopyDir "$src" "$dest" "$fileName" --quiet
} 

#
# Data Types
#

# array
CopyArray() { local ca; GetArrayDefinition "$1" ca; eval "$2=$ca"; }
DelimitArray() { (local get="$2[*]"; IFS=$1; echo "${!get}")} # DelimitArray DELIMITER ARRAY_VAR
GetArrayDefinition() { local gad="$(declare -p $1)"; gad="(${gad#*\(}"; r "${gad%\'}" $2; }
IsArray() {  [[ "$(declare -p "$1" 2> /dev/null)" =~ ^declare\ \-a.* ]]; }
ShowArray() { local var array="$1[@]"; printf -v var ' "%s"' "${!array}"; echo "${var:1}"; }
ShowArrayDetail() { declare -p "$1"; }
ShowArrayKeys() { local var getKeys="!$1[@]"; eval local keys="( \${$getKeys} )"; ShowArray keys; }
StringToArray() { IFS=$2 read -a $3 <<< "$1"; } # StringToArray STRING DELIMITER ARRAY_VAR

# IsInArray [-w|--wild] [-aw|--awild] STRING ARRAY_VAR - return 0 if string is in the
# array and set isInIndex , handles sparse arrays, the contents or the array can contain wild cards
IsInArray() 
{ 
	local wild; [[ "$1" == @(-w|--wild) ]] && { wild="true"; shift; }
	local awild; [[ "$1" == @(-aw|--array-wild) ]] && { awild="true"; shift; }
	local s="$1" getIndexes="!$2[@]"; eval local indexes="( \${$getIndexes} )"

	for isInIndex in "${indexes[@]}"; do
		local getValue="$2[$isInIndex]"; local value="${!getValue}"
		if [[ $wild ]]; then [[ "$value" == $s ]] && return 0;
		elif [[ $awild ]]; then [[ "$s" == $value ]] && return 0;
		else [[ "$s" == "$value" ]] && return 0; fi
	done;

	return 1
}

# date

CompareSeconds() { local a="$1" op="$2" b="$3"; (( ${a%.*}==${b%.*} ? 1${a#*.} $op 1${b#*.} : ${a%.*} $op ${b%.*} )); }
GetDateStamp() { ${G}date '+%Y%m%d'; }
GetFileDateStamp() { date '+%Y%m%d' -d "$(stat --format="%y" "$1")"; }
GetTimeStamp() { ${G}date '+%Y%m%d_%H%M%S'; }

GetSeconds() # GetSeconds [<date string>](current time) - seconds from 1/1/1970 to specified time
{
	[[ $1 ]] && { ${G}date +%s.%N -d "$1"; return; }
	[[ $# == 0 ]] && ${G}date +%s.%N; # only return default date if no argument is specified
}

# integer
IsInteger() { [[ "$1" =~ ^[0-9]+$ ]]; }

# string
IsInList() { [[ $1 =~ (^| )$2($| ) ]]; }
IsWild() { [[ "$1" =~ .*\*|\?.* ]]; }
ProperCase() { arg="${1,,}"; r "${arg^}" $2; }
QuoteBackslashes() { sed 's/\\/\\\\/g'; }
RemoveBackslash() { echo "${@//\\/}"; }
RemoveCarriageReturn()  { sed 's/\r//g'; }

GetWord() 
{ 
	(( $# < 2 || $# > 3 )) && { EchoErr "usage: GetWord STRING WORD [DELIMITER]"; return 1; }
	local word=$(( $2 + 1 )); IFS=${3:- }; set -- $1; 
	(( $# >= word )) && echo "${!word}" || return 1; 
}

# time
ShowTime() { ${G}date '+%F %T.%N %Z' -d "$1"; }
ShowSimpleTime() { ${G}date '+%D %T' -d "$1"; }
TimerOn() { startTime="$(${G}date -u '+%F %T.%N %Z')"; }
TimestampDiff () { ${G}printf '%s' $(( $(${G}date -u +%s) - $(${G}date -u -d"$1" +%s))); }
TimerOff() { s=$(TimestampDiff "$startTime"); printf "%02d:%02d:%02d" $(( $s/60/60 )) $(( ($s/60)%60 )) $(( $s%60 )); }

#
# ssh
#

IsSsh() { [[ "$SSH_TTY" ]]; }
RemoteServer() { echo "${SSH_CONNECTION%% *}"; }
PuttyAgent() { RunInDir pageant "$(utw "$HOME/.ssh/id_rsa.ppk")"; }

#
# account
#

ActualUser() { echo "${SUDO_USER-$USER}"; }

FullName() 
{ 
	case "$USER" in jjbutare|ad_jjbutare) echo John; return;; esac; 
	local s
	case "$PLATFORM" in
		win) s="$(net user "$USER" |& grep -i "Full Name")"; s="${s:29}";;
		mac)  s="$(dscl . -read /Users/$USER RealName | tail -n 1)"; s="${s:1}";;
	esac
	echo ${s:-$USER}; 
}

#
# network
#
IsInDomain() { [[ "$USERDOMAIN" != "$HOSTNAME" ]]; }
GetInterface() { ifconfig | head -1 | cut -d: -f1; }

GetPrimaryIpAddress() # GetPrimaryIpAddres [INTERFACE] - get default network adapter
{
	if IsPlatform cygwin; then 
		# default route (0.0.0.0 destination) with lowest metric
		route -4 print | grep ' 0.0.0.0 ' | sort -k5 --numeric-sort | head -1 | tr -s " " | cut -d " " -f 5
	else
		ifconfig $1 | grep inet | egrep -v 'inet6|127.0.0.1' | head -n 1 | awk '{ print $2 }'
	fi
}

GetIpAddress() # [HOST]
{
	[[ ! $1 ]] && { GetPrimaryIpAddress; return; }
	IsIpAddress "$1" && { echo "$1"; return; }
	if IsPlatform cygwin; then 
		ping -n 1 -w 0 "$1" | grep "^Pinging" | cut -d" " -f 3 | tr -d '[]'; return ${PIPESTATUS[1]}
	else
		host "$1" | grep "has address" | cut -d" " -f 4; return ${PIPESTATUS[0]}
	fi
}

IsIpAddress() # IP
{
  local ip="$1"
  [[ ! "$ip" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]] && return 1
	IFS='.' read -a ip <<< "$ip"
  (( ${ip[0]}<255 && ${ip[1]}<255 && ${ip[2]}<255 && ${ip[3]}<255 ))
}

PingResponse() # HOST [TIMEOUT](200ms) - returns ping response time in milliseconds
{ 
	local host="$1" timeout="${2-200}"

	if IsPlatform cygwin; then
		ping -n 1 -w "$timeout" "$host" | grep "^Reply from " | cut -d" " -f 5 | tr -d 'time=<ms'
		return ${PIPESTATUS[1]}
	fi

	if InPath fping; then
		fping -r 1 -t "$timeout" -e "$host" |& grep " is alive " | cut -d" " -f 4 | tr -d '('
		return ${PIPESTATUS[0]}
	fi

	ping -c 1 -W 1 "$host" |& grep "time=" | cut -d" " -f 7 | tr -d 'time=' # -W timeoutSeconds
	return ${PIPESTATUS[0]}
}

ConnectToPort() # ConnectToPort HOST PORT [TIMEOUT](200)
{
	local host="$1" port="$2" timeout="${3-200}"

	if IsPlatform cygwin; then	
		! IsIpAddress "$host" && { host="$(GetIpAddress $host)" || return; }
		chkport-ip.exe "$host" "$port" "$timeout" >& /dev/null
	else
		echo | ncat -C "$host" "$port" >& /dev/null
	fi
}

#
# UNC Shares - \\SERVER\SHARE\DIRS
#

IsUncPath() { [[ "$1" =~ //.* ]]; }
GetUncServer() { local gus="${1#*( )//}"; gus="${gus#*@}"; r "${gus%%/*}" $2; } # //USER@SERVER/SHARE/DIRS
GetUncShare() { local gus="${1#*( )//*/}"; r "${gus%%/*}" $2; }
GetUncDirs() { local gud="${1#*( )//*/*/}"; [[ "$gud" == "$1" ]] && gud=""; r "$gud" $2; }

#
# Console
#

[[ "$TABS" == "" ]] && TABS=2

clear() { echo -en $'\e[H\e[2J'; }
EchoErr() { echo "$@" > /dev/stderr; }
pause() { local response; read -n 1 -s -p "${*-Press any key when ready...}"; echo; }
PrintErr() { printf "$@" > /dev/stderr; }
#ShowErr() { eval "$@" 2> >(sed 's/^/stderr: /') 1> >(sed 's/^/stdout: /'); } # error under Synology DSM

# display tabs
catt() { cat $* | expand -t $TABS; } 							# CatTab
echot() { echo -e "$*" | expand -t $TABS; } 			# EchoTab
lesst() { less -x $TABS $*; } 										# LessTab
printfp() { local stdin; read -d '' -u 0 stdin; printf "$@" "$stdin"; } # printf pipe: cat file | printf -v var

#
# Windows
#

WindowInfo() { IsPlatform win && start --run-in-dir Au3Info.exe; }
SendKeys() { IsPlatform win && AutoItScript SendKeys "${@}"; } # SendKeys [TITLE|class CLASS] KEYS

#
# Process
#

console() { start --direct proxywinconsole.exe "$@"; } # console PROGRAM ARGS - attach PROGRAM to a hidden Windows console (powershell, nuget, python, chocolatey), alternative run outside of mintty in a regular console (Start, Run, bash --login)

IsExecutable()
{
	local p="$@"; [[ ! $p ]] && { EchoErr "usage: IsExecutable PROGRAM"; return 1; }

	# executable file - realpath resolves symbolic links, use -m so directory existence is not checked (which can error out for mounted network volumes)
	[[ -f "$p" ]] && { file "$(realpath -m "$p")" | egrep "executable|ELF" > /dev/null; return; }

	# alias, builtin, or function
	type -a "$p" >& /dev/null
}

IsRoot() { IsPlatform cygwin && { IsElevated.exe > /dev/null; return; } || [[ $SUDO_USER ]]; }
IsTaskRunning() { ProcessList | egrep -i ",$(utwq "$1")" >& /dev/null; }

ProcessClose() 
{ 
	local p="${1/.exe/}.exe"; GetFileName "$p" p

	if [[ "$PLATFORM" == "win" ]]; then
		# Process.exe only runs from the current directory in wsl
		pushd "$PBIN" >& /dev/null || return
		./Process.exe -q "$p" $2 | grep "has been closed successfully." > /dev/null
		popd >& /dev/null || return
	else
		pkill "$p" > /dev/null
	fi
}

ProcessIdExists() { kill -0 $1 >& /dev/null; } # fast

ProcessKill()
{
	local p="$1"

	if [[ "$PLATFORM" == "win" ]]; then
		RunInDir pskill.exe "$p" > /dev/null
	else
		GetFileNameWithoutExtension "$p" p
		pkill "$p" > /dev/null
	fi
}

ProcessList() # PID,NAME - show operating system native process ID and executable name with a full path
{ 
	case $PLATFORM in
		win) wmic.exe process get Name,ExecutablePath,ProcessID /format:csv | RemoveCarriageReturn | awk -F"," '{ print $4 "," ($2 == "" ? $3 : $2) }';;
		linux) ps -ef | awk '{ print $2 "," substr($0,index($0,$8)) }';;
		mac) ps -ef | ${G}cut -c7-11,50- --output-delimiter="," | sed -e 's/^[ \t]*//' | grep -v "NPID,COMMAND";;
	esac
}

ProcessResource() { IsPlatform win && { RunInDir handle.exe "$@"; return; } || echo "Not Implemented"; }; alias handle='ProcessResource'

# ProcessType console|gui|windows windows: true if the executable requires windows paths (c:\...) instead of POSIX paths (/...)
ProcessType() 
{
	local command="$1" file="$2"; 

	[[ "$#" != 2 ]] && { EchoErr "ProcessType console|gui|windows FILE"; return 1; }
	[[ ! -f  "$file" ]] && { EchoErr "$file does not exist"; return 1; }

	case "$command" in

		console|gui) 
			IsPlatform win && { file "$file" | egrep -i $command > /dev/null; return; } || return 0;;
			
		windows) 
			if IsPlatform cygwin; then 
				utw "$file" | egrep -iv cygwin > /dev/null; return;
			elif IsPlatform win; then 
				file "$file" | grep PE32 > /dev/null; return;
			else
				return 1
			fi
			;;
	esac
}

# start [-rid|--run-in-dir] [-e|--elevate] [-w|--wait] FILE ARGUMENTS - start a program converting file arguments for the platform as needed
start() 
{
	[[ $1 == @(-h|--help) ]]	&& { echot "usage: start [-e|--elevate] [-w|--wait] [-rid|--run-in-dir] FILE ARGUMENTS
	Start a program converting file arguments for the platform as needed"; return 1; }

	# file - executable (GUI|console)
	local runInDir; [[ "$1" == @(-rid|--run-in-dir) ]] && { runInDir="RunInDir"; shift; }
	local elevate; [[ "$1" == @(-e|--elevate) ]] && { ! IsElevated && elevate="true"; shift; }
	local wait; [[ "$1" == @(-w|--wait) ]] && { wait="--wait"; shift; }
	local file="$1" origFile="$1" args=( "${@:2}" ) open win

	# default to bash if elevating
	[[ $elevate && ! $file ]] && file="bash"

	# find open program
	if IsPlatform mac; then open="open"
	elif IsPlatform cygwin; then open="cygstart"
	elif IsPlatform win; then open="cmd.exe /c start"
	elif InPath xdg-open; then open="xdg-open"; fi

	# start directories and URL's
	( [[ -d "$file" ]] || IsUrl "$file" ) && { start $open "$file"; return; }

	# verify file	
	[[ ! -f "$file" ]] && file="$(FindInPath "$file")"
	[[ ! -f "$file" ]] && { EchoErr "Unable to find $origFile"; return 1; }

	# extension specific execution
	case "$(GetFileExtension "$file")" in
		cmd) start $open "$file" "${args[@]}"; return;;
		js|vbs) start cscript.exe /NoLogo "$file" "${args[@]}"; return;;
	esac

	# open the file if we cannot execute it directly
	! IsExecutable "$file" && { start $open "$file" "${args[@]}"; return; }

	# massage arguments
	ProcessType windows "$file" && win="true"
	for (( i=0 ; i < ${#args[@]} ; ++i )); do 
		local a="${args[$i]}"	

		# convert POSIX paths to Windows format for windows exectuable
		if [[ $win && ( -e "$a" || ( ! "$a" =~ .*\\.* && "$a" =~ .*/.* && -e "$a" )) ]]; then
			args[$i]="$(utw "$a")"			
		fi

		# cygstart requires arguments with spaces be quoted
		#[[ "$a" =~ ( ) ]] && args[i]="\"$a\""; 
	done	
	#printf "wait=$wait\nprogram=$program\nargs="; ShowArray args; return

	# run elevated
	if [[ "$PLATFORM" == "win" && $elevate ]]; then
		[[ $wait ]] && wait="/WAIT"

		if [[ $win ]]; then
			RunInDir hstart64.exe /NOUAC $wait "$(utw "$file") ${args[*]}"
		else
			RunInDir hstart64.exe /NOUAC $wait "wsl.exe $*"
		fi
		return
	fi
 
	if [[ $wait ]]; then
		(
			nohup $runInDir "$file" "${args[@]}" >& /dev/null &
			wait $!
		)
	elif [[ $runInDir ]]; then
		($runInDir "$file" "${args[@]}" >& /dev/null &)
	else
		(nohup "$file" "${args[@]}" >& /dev/null &)
	fi
} 

SudoPreserve="sudo --preserve-env=PATH"; IsPlatform raspbian && SudoPreserve="sudo --preserve-env"
sudop() { $SudoPreserve env "$@"; } # sudo preserve - run sudo with the existing path (less secure)
sudoa() { $SudoPreserve --askpass "$@"; } # sudo ask password and preserve - prompt for sudo password
sudoc() { SUDO_ASKPASS="$BIN/SudoAskPass" $SudoPreserve --askpass env "$@"; } # sudo password from credential store and preserve

#
# Applications
#

GetTextEditor()
{
	p="$P/sublime_text/sublime_text"; [[ -f "$p" ]] && { echo "$p"; return 0; }
	p="$P/Sublime Text.app/Contents/SharedSupport/bin/subl"; [[ -f "$p" ]] && { echo "$p"; return 0; }
	p="$P/Sublime Text 3/sublime_text.exe"; [[ -f "$p" ]] && { echo "$p"; return 0; }
	p="$P/Notepad++/notepad++.exe"; [[ -f "$p" ]] && { echo "$p"; return 0; }
	InPath geany && { echo "geany"; return 0; }
	InPath gedit && { echo "gedit"; return 0; }
	InPath nano && { echo "nano"; return 0; }
	InPath vi && { echo "vi"; return 0; }
	EchoErr "No text editor found"; return 1;
}

TextEdit()
{
	local file files=() p=""
	local wait; [[ "$1" == +(-w|--wait) ]] && { wait="--wait"; shift; }
	local options; while IsOption "$1"; do options+=( "$1" ); shift; done
	local p="$(GetTextEditor)"; [[ ! $p ]] && { EchoErr "No text editor found"; return 1; }

	for file in "$@"; do
		[[ -e "$file" ]] && files+=( "$file" ) || EchoErr "$(GetFileName "$file") does not exist"
	done
	
	[[ $# == 0 || "${#files[@]}" > 0 ]] && start $wait "${options[@]}" "$p" "${files[@]}"
}

VimHelp() { echot "VIM: http://www.lagmonster.org/docs/vi.html
	I - insert before cursor, 	ctrl-shift-v / context-edit-paste - paste
	escape - command mode
	x/dd - delete character/line
	:w - write, :q! - quit" ;}

# Git - git for Windows is faster, but older than Cygwin git
unset -f git
unset GIT_PYTHON_GIT_EXECUTABLE
if [[ -f "$P/Git/cmd/git.exe" ]]; then
	export GIT_PYTHON_GIT_EXECUTABLE="$P/Git/cmd/git.exe"
	#git() { "$P/Git/cmd/git.exe" "$@"; }
fi

IsVm() { IsVmwareVm; }
IsVmwareVm() { [[ -d "$P/VMware/VMware Tools" ]]; }
