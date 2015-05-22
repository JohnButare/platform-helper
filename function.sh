# common functions for non-interactive scripts

FUNCTIONS="true"

# sytem-wide configuration - if we were not run from a login shell
[[ ! $BIN ]] && [[ -f "/usr/local/data/bin/bash.bashrc" ]] && . "/usr/local/data/bin/bash.bashrc"

#
# configuration
# 

shopt -s nocasematch extglob 

#
# other
#

EvalVar() { r "${!1}" $2; } # EvalVar <variable> <var> - return the contents of the variable in variable, or set it to var
IsUrl() { [[ "$1" =~ http[s]?://.* ]]; }
IsInteractive() { [[ "$-" == *i* ]]; }
pause() { local response; read -n 1 -s -p "${*-Press any key when ready...}"; echo; }
clipw() { case "$PLATFORM" in "mac") echo -n "$@" | pbcopy;; "win") echo -n "$@" > /dev/clipboard;; esac; }
clipr() { case "$PLATFORM" in "mac") pbpaste;; "win") cat /dev/clipboard;; esac; }
EchoErr() { echo "$@" > /dev/stderr; }
PrintErr() { printf "$@" > /dev/stderr; }
ShowErr() { eval "$@" 2> >(sed 's/^/stderr: /') 1> >(sed 's/^/stdout: /'); }
r() { [[ $# == 1 ]] && echo "$1" || eval "$2=""\"${1//\"/\\\"}\""; } # result VALUE VAR - echo value or set var to value (faster)
# r "- '''\"\"\"-" a; echo $a

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
ElevationRequired() { IsElevated && return 0;	EchoErr "$(ScriptName): requires elevation"; exit 1; }

IsDeclared() { declare -p "$1" >& /dev/null; } # IsDeclared NAME - NAME is a declared variable
IsFunction() { declare -f "$1" >& /dev/null; } # IsFunction NAME - NAME is a function
GetFunction() { declare -f | egrep -i "^$1 \(\) $" | sed "s/ () //"; return ${PIPESTATUS[1]}; } # GetFunction NAME - get function NAME case-insensitive

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
# files and directories
#

FindInPath() { type -P "${1}"; }
fpc() { local arg; [[ $# == 0 ]] && arg="$PWD" || arg="$(${G}realpath "$1")"; echo "$arg"; clipw "$arg"; } # full path to clipboard
pfpc() { local arg; [[ $# == 0 ]] && arg="$PWD" || arg="$(${G}realpath "$1")"; clipw "$(utw "$arg")"; } # full path to clipboard in platform specific format
GetBatchDir() { GetFilePath "$0"; }
GetFileSize() { [[ ! -e "$1" ]] && return 1; local size="${2-MB}"; [[ "$size" == "B" ]] && size="1"; s="$(${G}du --apparent-size --summarize -B$size "$1" |& cut -f 1)"; echo "${s%%*([[:alpha:]])}"; } # FILE [SIZE]
GetFilePath() { local gfp="${1%/*}"; [[ "$gfp" == "$1" ]] && gfp=""; r "$gfp" $2; }
GetFileName() { r "${1##*/}" $2; }
GetFileNameWithoutExtension() { local gfnwe="$1"; GetFileName "$1" gfnwe; r "${gfnwe%.*}" $2; }
GetFileExtension() { local gfe="$1"; GetFileName "$gfe" gfe; [[ "$gfe" == *"."* ]] && r "${gfe##*.}" $2 || r "" $2; }
GetFullPath() { local gfp="$(cygpath -a "$1")" || return; r "$gfp" $2; }
GetDriveLabel() { local gdl="$(cmd /c vol "$1": |& head -1 | sed -e '/^Ma/d')"; r "${gdl## Volume in drive ? is }" $2; }
HideFile() { [[ -e "$1" ]] && attrib.exe +h "$(utw "$1")"; }
IsWindowsLink() { [[ "$PLATFORM" != "win" ]] && return 1; lnWin -s "$1" >& /dev/null; }
RemoveTrailingSlash() { r "${1%%+(\/)}" $2; }

# (Man)PathAdd <path> [front], front adds to front and drops duplicates in middle
PathAdd() {	[[ ! -d "$1" ]] && return; if [[ "$2" == "front" ]]; then PATH=$1:${PATH//:$1:/:}; elif [[ ! $PATH =~ (^|:)$1(:|$) ]]; then PATH+=:$1; fi; } 
ManPathAdd() { [[ ! -d "$1" ]] && return; if [[ "$2" == "front" ]]; then MANPATH=$1:${MANPATH//:$1:/:}; elif [[ ! $MANPATH =~ (^|:)$1(:|$) ]]; then MANPATH+=:$1; fi; }

# Path conversion
wtu() { [[ "$PLATFORM" == "win" ]] && cygpath -u "$*" || echo "$@"; } # WinToUnix
utw() { [[ "$PLATFORM" == "win" ]] && cygpath -aw "$*" || echo "$@"; } # UnixToWin
ptw() { echo "${1////\\}"; } # PathToWin

DirCount() { command ls "$1" | wc -l; return "${PIPESTATUS[0]}"; }

explore() # explorer DIR - explorer DIR in GUI program
{
	local dir="$1"; [[ ! $dir ]] && dir="$PWD"
	case "$PLATFORM" in
		mac) open "$dir" ;;
		win) start explorer "$dir";;
	esac
}

GetDisks() # GetDisks ARRAY
{
	local getDisks;

	case "$PLATFORM" in
		mac) IFS=$'\n' getDisks=( $(df | egrep "/dev/" | cut -c 103- | egrep -v '^/$') );;
		win) for disk in /cygdrive/*; do getDisks+=( "$disk" ); done;;
	esac
	CopyArray getDisks "$1"
}

# MakeShortcut FILE LINK
MakeShortcut() 
{ 
	local suppress; [[ "$1" == @(-s|--suppress) ]] && { suppress="true"; shift; }
	(( $# < 2 )) && { EchoErr "usage: MakeShortcut TARGET NAME ..."; return 0; }
	local t="$1"; [[ ! -e "$t" ]] && t="$(FindInPath "$1")"
	[[ ! -e "$t" && $suppress ]] && { return 0; }
	[[ ! -e "$t" ]] && { EchoErr "MakeShortcut: could not find target $1"; return 1; }
	mkshortcut "$t" -n="$2" "${@:3}";
}

CopyDir()
{
	[[ "$PLATFORM" == "win" ]] && { CopyDirWin "$@"; return; }
	local cp o=( --progress ); cp="$(FindInPath acp)" || { cp="${G}cp"; o=( --verbose ); } 

	for arg in "$@"; do
		#[[ $1 == @(-r|--recursive) ]] && { o+=( --recursive ); shift; continue; }
		[[ $1 == @(-m|--mirror) ]] && { shift; continue; }
		[[ $1 == @(-q|--quiet) ]] && { shift; continue; }
		[[ $1 == @(--retry) ]] && { shift; continue; }
		[[ $1 == @(-xd|-xf) ]] && { shift; while (( $# != 0 )) && ! IsOption "$1"; do shift; done; continue; }
		o+=( "$1" ); shift
	done

	# cp dir1 dir2 will not copy the top level directory, need a way to copy only top level directory
	"$cp" --recursive "${o[@]}"
}

CopyDirWin()
{
	[[ $1 == @(--help) ]]	&& { EchoErr "usage: CopyDir SRC DEST [FILES] [OPTIONS]
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
		[[ $1 == @(-g|--progress|--progress-bar) ]] && { shift; continue; } # for compatibility with amv and acp
		IsOption "$1" && { o+=( "/${1:1}" ); shift; continue; }
		! IsOption "$1" && [[ ! $src ]] && { src="$(utw "$1")"; shift; continue; }
		! IsOption "$1" && [[ ! $dest ]] && { dest="$(utw "$1")"; shift; continue; }
		o+=( "$1" ); shift
	done
	[[ $quiet && ! $mirror ]] && o+=( /xx )

	robocopy "$src" "$dest" "${o[@]}"
	(( $? < 8 )) # http://support.microsoft.com/kb/954404
}

# FileCommand mv|cp|ren|hide SOURCE... DIRECTORY - mv or cp ignoring files that do not exist
FileCommand() 
{ 
	local args command="$1" dir="${@: -1}" file files=0 n
	[[ "$command" == "hide" ]] && n=$(($#-1)) || n=$(($#-2))

	for arg in "${@:2:$n}"; do
		IsOption "$arg" && args+=( "$arg" )
		[[ -e "$arg" ]] && { args+=( "$arg" ); (( ++files )); }
	done
	(( files == 0 )) && return 0

	case "$command" in
		hide) for file in "${args[@]}"; do attrib +h "$(utw "$file")" || return; done;;
		HideAndSystem) for file in "${args[@]}"; do attrib +h +s "$(utw "$file")" || return; done;;
		ren) mv "${args[@]}" "$dir";;
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
# arrays
#

#CopyArray() { eval "$2=$(GetArrayDefinition "$1")"; }
CopyArray() { local ca; GetArrayDefinition "$1" ca; eval "$2=$ca"; }
DelimitArray() { (local get="$2[*]"; IFS=$1; echo "${!get}")} # DelimitArray DELIMITER ARRAY_VAR
GetArrayDefinition() { local gad="$(declare -p $1)"; gad="${gad#*=\'}"; r "${gad%\'}" $2; }
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

#
# strings
#

IsWild() { [[ "$1" =~ .*\*|\?.* ]]; }
IsInList() { [[ $1 =~ (^| )$2($| ) ]]; }
ProperCase() { arg="${1,,}"; r "${arg^}" $2; }

GetWord() 
{ 
	(( $# < 2 || $# > 3 )) && { EchoErr "usage: GetWord STRING WORD [DELIMITER]"; return 1; }
	local word=$(( $2 + 1 )); IFS=${3:- }; set -- $1; 
	(( $# >= word )) && echo "${!word}" || return 1; 
}


#
# numbers
#

IsInteger() { [[ "$1" =~ ^[0-9]+$ ]]; }

#
# dates
#

GetDateStamp() { ${G}date '+%Y%m%d'; }
GetTimeStamp() { ${G}date '+%Y%m%d_%H%M%S'; }
ShowTime() { ${G}date '+%F %T.%N %Z' -d "$1"; }
ShowSimpleTime() { ${G}date '+%D %T' -d "$1"; }

GetSeconds() # GetSeconds [<date string>](current time) - seconds from 1/1/1970 to specified time
{
	[[ $1 ]] && { ${G}date +%s.%N -d "$1"; return; }
	[[ $# == 0 ]] && ${G}date +%s.%N; # only return default date if no argument is specified
}
CompareSeconds() { local a="$1" op="$2" b="$3"; (( ${a%.*}==${b%.*} ? 1${a#*.} $op 1${b#*.} : ${a%.*} $op ${b%.*} )); }

TimerOn() { startTime="$(${G}date -u '+%F %T.%N %Z')"; }
TimestampDiff () { ${G}printf '%s' $(( $(${G}date -u +%s) - $(${G}date -u -d"$1" +%s))); }
TimerOff() { s=$(TimestampDiff "$startTime"); printf "Elapsed %02d:%02d:%02d\n" $(( $s/60/60 )) $(( ($s/60)%60 )) $(( $s%60 )); }

#
# account
#

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

PublicPictures() { [[ "$PLATFORM" == "win" ]] && cygpath -F 54 || echo "$PUB/Pictures"; }
PublicVideos() { [[ "$PLATFORM" == "win" ]] && cygpath -F 55 || echo "$PUB/Videos"; }
UserPictures() { [[ "$PLATFORM" == "win" ]] && cygpath -F 39 || echo "$HOME/Pictures"; }
UserVideos() { [[ "$PLATFORM" == "win" ]] && cygpath -F 14 || echo "$HOME/Videos"; }

#
# network
#

IsInDomain() { [[ "$USERDOMAIN" != "$COMPUTERNAME" ]]; }

GetPrimaryIpAddress() # INTERFACE
{
	case "$PLATFORM" in
		mac) ifconfig $1 | grep inet | egrep -v 'inet6|127.0.0.1' | head -n 1 | cut -d" " -f 2;; 
		win) ipconfig | grep "   IPv4 Address" | head -n 1 | cut -d: -f2 | tr -d " ";; 
	esac
}

GetIpAddress() # [HOST]
{
	[[ ! $1 ]] && { GetPrimaryIpAddress; return; }
	IsIpAddress "$1" && { echo "$1"; return; }
	case "$PLATFORM" in
		mac) host "$1" | grep "has address" | cut -d" " -f 4; return ${PIPESTATUS[0]};;
		win) ping -n 1 -w 0 "$1" | grep "^Pinging" | cut -d" " -f 3 | tr -d '[]'; return ${PIPESTATUS[1]};;
	esac
}

IsIpAddress() # IP
{
  local ip="$1"
  [[ ! "$ip" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]] && return 1
	IFS='.' read -a ip <<< "$ip"
  (( ${ip[0]}<255 && ${ip[1]}<255 && ${ip[2]}<255 && ${ip[3]}<255 ))
}

PingResponse() # HOST [TIMEOUT](200) - ping response time in milliseconds
{ 
	local host="$1" timeout="${2-200}"
	case "$PLATFORM" in
		mac) fping -r 1 -t "$timeout" -e "$host" |& grep " is alive " | cut -d" " -f 4 | tr -d '('; return ${PIPESTATUS[0]};;
		win) ping -n 1 -w "$timeout" "$host" | grep "^Reply from " | cut -d" " -f 5 | tr -d 'time=<ms'; return ${PIPESTATUS[1]};;
	esac
}

ConnectToPort() # ConnectToPort HOST PORT [TIMEOUT](200)
{
	local host="$1" port="$2" timeout="${3-200}"
	case "$PLATFORM" in
		mac) echo | ncat -C "$host" "$port" >& /dev/null;;
		win) 
			! IsIpAddress "$host" && { host="$(GetIpAddress $host)" || return; }
			chkport-ip.exe "$host" "$port" "$timeout" >& /dev/null;;
	esac
}

#
# UNC Shares - \\SERVER\SHARE\DIRS
#

IsUncPath() { [[ "$1" =~ //.* ]]; }
GetUncServer() { local gus="${1#*( )//}"; gus="${gus#*@}"; r "${gus%%/*}" $2; } # //USER@SERVER/SHARE/DIRS
GetUncShare() { local gus="${1#*( )//*/}"; r "${gus%%/*}" $2; }
GetUncDirs() { local gud="${1#*( )//*/*/}"; [[ "$gud" == "$1" ]] && gud=""; r "$gud" $2; }

#
# display
#

[[ "$TABS" == "" ]] && TABS=2

clear() { echo -en $'\e[H\e[2J'; }
catt() { cat $* | expand -t $TABS; } 							# CatTab
echot() { echo -e "$*" | expand -t $TABS; } 			# EchoTab
lesst() { less -x $TABS $*; } 										# LessTab
printfp() { local stdin; read -d '' -u 0 stdin; printf "$@" "$stdin"; } # printf pipe: cat file | printf -v var

#
# platform
#

# console PROGRAM ARGS - attach PROGRAM to a hidden Windows console (powershell, nuget, python, chocolatey), alternative run outside of mintty in a regular console (Start, Run, bash --login)
console() { start --direct proxywinconsole.exe "$@"; } 

IsMobile() { [[ "$(HostInfo info "$COMPUTERNAME" mobile)" == "yes" ]]; }
IsVm() { [[ "$PLATFORM" != "win" ]] && return 0; ! vmchk > /dev/null; }
OsArchitecture() { [[ -d "/cygdrive/c/Windows/SysWOW64" ]] && echo "x64" || echo "x86"; } # uname -m

#
# process
#
# NOTE: piping ps output can be slow in Windows

IsElevated() { [[ "$PLATFORM" == "win" ]] && IsElevated.exe > /dev/null || whoami | grep root; }
SendKeys() { AutoItScript SendKeys "${@}"; } # SendKeys [TITLE|class CLASS] KEYS

# start [--direct|--files] [OPTION...] <program> <arguments> - start a Windows program
# --direct		start the program directly without using cygstart (which is for ShellRun API), usually for console programs
# --files 		assume arguments which match files the current directory are files, not arguments
# OPTION  		start arguments
start() 
{
	local direct; [[ "$1" == @(--direct) ]] && { direct="true"; shift; }
	local files; [[ "$1" == @(--files) ]] && { files="true"; shift; }

	if [[ "$PLATFORM" == "mac" ]]; then
		type -a "$1" >& /dev/null && { "$@"; return; } || { open "$@"; return; }
	fi

	local options; while IsOption "$1"; do options+=( "$1" ); shift; done
	local program="$1" args=( "${@:2}" ) qargs; 

	for arg in "${args[@]}"; do 
		[[ ( ! "$arg" =~ .*\\.* && "$arg" =~ .*/.* && -e "$arg" ) || ( $files && -e "$arg" ) ]] && { arg="$(utw "$arg")"; } # convert POSIX path to Windows format
		[[ ! $direct && "$arg" =~ ( ) ]] && qargs+=( "\"$arg\"" ) || qargs+=( "$arg" ); # cygstart requires arguments with spaces be quoted
	done
	
	#printf "wait=$wait\noptions="; ShowArray options; printf "program=$program\nqargs="; ShowArray qargs; return

	[[ -d "$program" ]] && { cygstart "$program"; return; }
	IsUrl "$program" && { cygstart "$program"; return; }

	[[ ! -f "$program" ]] && program="$(FindInPath "$1")"

	[[ ! -f "$program" ]] && { EchoErr "Unable to start $1: file not found"; return 1; }
	GetFileExtension "$program" ext
	
	case "$ext" in
		cmd) cmd /c $(utw "$program") "${@:2}";;
		js|vbs) cscript /NoLogo "$(utw "$program")" "${@:2}";;
		*) if [[ $direct ]]; then "$program" "${qargs[@]}"; 
			 else cygstart "${options[@]}" "$program" "${qargs[@]}"; fi;;
	esac
} 

sudo() # sudo [command](mintty) - start a program as super user
{
	local program="mintty" hstartOptions cygstartOptions ext standard direct hold="error"

	while IsOption "$1"; do
		if [[ "$1" == +(-s|--standard) ]]; then standard="true"; hstartOptions+=( /nonelevated );
		elif [[ "$1" == +(-h|--hide) ]]; then hstartOptions+=( /noconsole );
		elif [[ "$1" == +(-w|--wait) ]]; then hstartOptions+=( /wait ); cygstartOptions+=( --wait ); hold="always";
		elif [[ "$1" == +(-d|--direct) ]]; then direct="--direct";
		else cygstartOptions+=( "$1" ); fi
		shift
	done
	[[ ! $standard ]] && hstartOptions+=( /elevated )

	[[ $# > 0 ]] && { program="$1"; shift; }
	! type -P "$program" >& /dev/null && { EchoErr "start: $program: command not found"; return 1; }

	program="$(FindInPath "$program")" # IsShellScript requires full path

	# determine if hstart is not needed to change contexts
	local elevated; IsElevated && elevated="true"

	if [[ (! $elevated && $standard) || ($elevated && ! $standard) ]]; then
		if IsShellScript "$program"; then
			"$program" "$@"
		else
			start $direct "${cygstartOptions[@]}" "$program" "$@"
		fi
		return
	fi

	if IsShellScript "$program"; then
		cygstart "${cygstartOptions[@]}" hstart "${hstartOptions[@]}" "\"\"mintty.exe\"\" --hold $hold bash.exe -l \"\"$program\"\" $@";
	else
		program="$(utw "$program")"
		cygstart "${cygstartOptions[@]}" hstart "${hstartOptions[@]}" "\"\"$program\"\" $@";
	fi
}
[[ "$PLATFORM" != "win" ]] && unset -f sudo

IsTaskRunning() # IsTaskRunng EXE
{
	local task="${1/\.exe/}"
		
	case "$PLATFORM" in
		mac) ps -A | grep "$task" | grep -v "grep $task" >& /dev/null;;
		win) GetFileName "$task" task; AutoItScript ProcessExists "${task}.exe";;
	esac
}

# Process Commands
ProcessList() 
{ 
	case $PLATFORM in
		win) tasklist | awk '{ print $2 "," $1 }';;
		*) ps -W | cut -c33-36,61- --output-delimiter="," | sed -e 's/^[ \t]*//' | grep -v "NPID,COMMAND";;
	esac
}

ProcessClose() { local p="${1/.exe/}.exe"; GetFileName "$p" p; process.exe -q "$p" $2 | grep "has been closed successfully." > /dev/null; } #egrep -v "Command Line Process Viewer|Copyright\(C\) 2002-2003|^$"; }
ProcessKill() { local p="$1"; GetFileNameWithoutExtension "$p" p; pskill "$p" >& /dev/null ; }

# Window Commands - Win [class] <title|class>, Au3Info.exe to get class
WinActivate() { AutoItScript WinActivate "${@}"; }
WinClose() { AutoItScript WinClose "${@}"; }
WinList() { join -a 2 -e EMPTY -j 1 -t',' -o '2.1,1.2,2.2,2.3' <(ProcessList | sort -t, -k1) <(AutoItScript WinList | sort -t, -k1); }
WinGetState() {	AutoItScript WinGetState "${@}"; }
WinGetTitle() {	AutoItScript WinGetTitle "${@}"; }
WinSetState() { AutoItScript WinSetState "${@}"; }

WinExists() { WinGetState "${@}"; (( $? & 1 )); }
WinVisible() { WinGetState "${@}"; (( $? & 2 )); }
WinEnabled() { WinGetState "${@}"; (( $? & 4 )); }
WinActive() { WinGetState "${@}"; (( $? & 8 )); }
WinMinimized() { WinGetState "${@}"; (( $? & 16 )); }
WinMaximized() { WinGetState "${@}"; (( $? & 32)); }

#
# Applications
#

if [[ "$PLATFORM" == "win" ]]; then
	WinShell() { WIN_VARS=true SET_PWD="$PWD" start bash -l; }
	NpmShell() { intel IsIntelHost && ScriptEval intel SetProxy; WinShell; }
	npm() { APPDATA="$(utw $APPDATA)" "$P/nodejs/npm" "$@"; }
	alias ns="NpmShell"
fi

AutoItScript() 
{
	local script="${1/\.au3/}.au3"
	[[ ! -f "$script" ]] && script="$(FindInPath "$script")"
	[[ ! "$script" ]] && { echo "Could not find AutoIt script $1"; return 1; }
	AutoIt.exe /ErrorStdOut "$(utw "$script")" "${@:2}"
}

TextEdit()
{
	local file files=() p=""
	local wait; [[ "$1" == +(-w|--wait) ]] && { wait="pause"; shift; }
	local options; while IsOption "$1"; do options+=( "$1" ); shift; done
	
	case "$PLATFORM" in
		mac) p="$P/Sublime Text.app/Contents/SharedSupport/bin/subl"
			[[ ! -f "$p" ]] && p="open -a TextEdit";;
		win) p="$P/Sublime Text 3/sublime_text.exe"
			[[ ! -f "$p" ]] && p="$P/Sublime Text 2/sublime_text.exe"
			[[ ! -f "$p" ]] && p="$P32/Notepad++/notepad++.exe"
			[[ ! -f "$p" ]] && p="notepad";;
	esac

	for file in "$@"; do
		[[ -f "$file" ]] && files+=( "$file" ) || EchoErr "$(GetFileName "$file") does not exist"
	done
	if [[ $# == 0 || "${#files[@]}" > 0 ]]; then { start --files "${options[@]}" "$p" "${files[@]}"; $wait; } else return 1; fi
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
