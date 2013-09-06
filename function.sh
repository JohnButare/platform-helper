# common functions for non-interactive scripts

shopt -s nocasematch

EvalVar() { r "${!1}" $2; } # EvalVar <variable> <var> - return the contents of the variable in variable, or set it to var
IsInteractive() { [[ "$-" == *i* ]]; }
pause() { read -n 1 -p "${*-Press any key when ready...}"; }
clipw() { printf "$1" > /dev/clipboard; }
clipr() { cat /dev/clipboard; }
echoerr() { echo "${@}" > /dev/stderr; }
r() { [[ $# == 1 ]] && echo "$1" || eval $2="\"$1\""; } # result <value> <var> - echo value or set var to value (faster)

#
# scripts
#
IsShellScript() { file "$1" | egrep "shell script" >& /dev/null; }
IsFunction() { declare -f "$1" >& /dev/null; } # IsFunction <function> - function is defined
ProperCase() { arg="${1,,}"; r "${arg^}" $2; }
ScriptName() { GetFilename $0; }
ScriptDir() { GetPath $0; }
ScriptCd() { [[ $# == 1 ]] && eval "$("$1" cd)" || eval "$("$@")"; } # ScriptCd <script> [arguments](cd) - run a script and change to the directory it outputs 
ScriptEval() { eval "$("$@")"; } # ScriptEval <script> [<arguments>] - run a script and evaluate it's output, typical variables to set using  printf "a=%q;b=%q;" "result a" "result b"

MissingOperand()
{
	echoerr "$(ScriptName): missing $1 operand"
	exit 1
}

ElevationRequired()
{
	IsElevated && return 0;
	echoerr "$(ScriptName): requires elevation";
	exit 1
}

#
# arrays
#

# FindIndex|IsIn <string> <values> - return 0 based index of string in the remaining arguments, usage a=(one two three); IsIn one "${a[@]}"
FindIndex() { local s="$1"; shift; for ((i=1; i<=$#; ++i)); do [[ "${!i}" == "$s" ]] && return $(( $i-1 )); done; return 255; } 
IsIn() { FindIndex "$@"; (($? != 255)); }

FindIndexArray() { local a="$2[@]"; FindIndex "$1" "${!a}"; } 
IsInArray() { FindIndexArray "$@"; (($? != 255)); }

#
# strings
#
IsInList() { [[ "$2" =~ (^| )$1($| ) ]]; } # IsInList <string> <space list>, for variables use  [[ s = @(${s/ /|}) ]]

#
# numbers
#
IsInteger() { [[ "$1" =~ ^[0-9]+$ ]]; }

#
# dates
#

TimerOn() { startTime="$(date -u '+%F %T.%N %Z')"; }
TimestampDiff () { printf '%s' $(( $(date -u +%s) - $(date -u -d"$1" +%s))); }
TimerOff() { s=$(TimestampDiff "$startTime"); printf "Elapsed %02d:%02d:%02d\n" $(( $s/60/60 )) $(( ($s/60)%60 )) $(( $s%60 )); }

#
# network
#

# IpAddress|DnsLookup <host> - perform IP Address lookup using default system name providers (Windows NodeType) or Dns
IpAddress() { [[ ! $1 ]] && return 1; IsIpAddress "$1" && { echo "$1"; return; }; ip="$(DnsLookup "$1")"; [[ $ip ]] && echo "$ip" || PingLookup "$1"; }
PingLookup() { [[ ! $1 ]] && return 1; IsIpAddress "$1" && { echo "$1"; return; }; ping -n 1 -w 0 "$1" | grep "^Pinging" | cut -d" " -f 3 | tr -d '[]'; }
DnsLookup() { IsIpAddress "$1" && echo "$1"; nslookup -srchlist=amr.corp.intel.com/hagerman.butare.net -timeout=1 "$1" |& grep "Address:" | tail -n +2 | cut -d" " -f 3; }

# IsIpAddress <string>
IsIpAddress()
{
  local ip="$1"
  [[ ! "$ip" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]] && return 1
	IFS='.' read -a ip <<< "$ip"
  (( ${ip[0]}<255 && ${ip[1]}<255 && ${ip[2]}<255 && ${ip[3]}<255 ))
}

# PingResponse <host> [<timeout>](200) - ping response time in milliseconds
PingResponse() 
{ 
	local host="$1" timeout="${2-200}"
	ping -n 1 -w "$timeout" "$host" | grep "^Reply from " | cut -d" " -f 5 | tr -d 'time=<ms';
}

# ConnectToPort <host> <port> [<timeout>](200)
ConnectToPort()
{
	local ip="$1" port="$2" timeout="${3-200}"
	! IsIpAddress "$ip" && ip="$(IpAddress $ip)"
	chkport-ip.exe "$ip" "$port" "$timeout" >& /dev/null
}

#
# display
#

[[ "$TABS" == "" ]] && TABS=2

echot() { echo -e "$*" | expand -t $TABS; } 			# EchoTab
catt() { cat $* | expand -t $TABS; } 							# CatTab
lesst() { less -x $TABS $*; } 										# LessTab

clear()
{
	local clear=''

	type -p clear >/dev/null && \
		clear=$(exec clear)
	[[ -z $clear ]] && type -p tput >/dev/null && \
		clear=$(exec tput clear)
	[[ -z $clear ]] && \
		clear=$'\e[H\e[2J'

	echo -en "$clear"

	eval "function clear { echo -en '$clear'; }"
}

#
# path: realpath, cygpath
#

FindInPath() { type -p "${1}"; }

GetPath() { r "${1%/*}" $2; }
GetFilename() { r "${1##*/}" $2; }
GetName() { local f="$1"; GetFilename "$1" f; r "${f%.*}" $2; }
GetExtension() { local f="$1"; GetFilename "$f" f; [[ "$f" == *"."* ]] && r "${f##*.}" $2 || r "" $2; }
GetFullPath() { cygpath -a "$@"; }

wtu() { cygpath -u "$*"; }
utw() { cygpath -aw "$*"; }

#
# process
#
IsElevated() { IsElevated.exe > /dev/null; }
OsArchitecture() { [[ -d "/cygdrive/c/Windows/SysWOW64" ]] && echo "x64" || echo "x86"; } # uname -m
SendKeys() { AutoItScript SendKeys "${@}"; } # SendKeys <class> <title|class> <keys>
sr() { ShellRun.exe "$(utw $*)"; }
tc() { "$P/JPSoft/TCMD13x64/tcc.exe" /c $*; }

start() # start [OPTION] <program> <arguments>, file arguments need quotes: \"$(utw <path>)\"
{
	local option; [[ "$1" == --* ]] && { option=$1; shift; } 
	local program="$1" ext
	
	[[ ! -f "$program" ]] && program="$(FindInPath "$1")"
	[[ ! -f "$program" ]] && { echoerr "Unable to start $1: file not found"; return 1; }
	GetExtension "$program" ext
	
	case "$ext" in
		js|vbs) cscript /NoLogo "$(utw "$program")" "${@:2}";;
		*) cygstart $option "$(utw "$program")" "${@:2}";;
	esac
} 

sudo() # sudo [command](mintty) - start a program as super user
{
	local program="mintty" hide ext prefix

	[[ "$1" == +(-h|--hide) ]] && { hide="/noconsole"; shift; }

	[[ $# > 0 ]] && { program="$1"; shift; }
	[[ ! -f "$program" ]] && program="$(FindInPath "$program")"
	[[ ! -f "$program" ]] && { echoerr "Unable to start $1: file not found"; return 1; }

	GetExtension "$program" ext
	[[ ! $ext ]] && IsShellScript "$program" && prefix="\"\"bash.exe\"\" --login "

	IsElevated && cygstart "$(utw "$program")" "${@}" ||
		cygstart hstart $hide /elevated "$prefix\"\"$(utw "$program")\"\" ${@}";
}

IsTaskRunning() # IsTaskRunng <task>
{
		local task="${1/\.exe/}"
		GetFilename "$task" task

		# ps -sW | cut -c 27- - full path, no extension for Cygwin processes
		# tasklist /nh /fo csv | cut -d, -f1 | grep -i "^\"$task\.exe\"$" > /dev/nul # no path, slower
		AutoItScript ProcessExists "${task}.exe"
}

# Process Commands
ProcessList() { ps -W | cut -c33-36,61- --output-delimiter="," | sed -e 's/^[ \t]*//' | grep -v "NPID,COMMAND"; }
ProcessClose() { local p="${1/.exe/}.exe"; GetFilename "$p" p; process.exe -q "$p" $2 | egrep -v "Command Line Process Viewer|Copyright\(C\) 2002-2003|^$"; }
ProcessKill() { local p="$1"; GetName "$p" p; pskill "$p"; }

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

AutoItScript() 
{
	local script="${1/\.au3/}.au3"
	[[ ! -f "$script" ]] && script="$(FindInPath "$script")"
	[[ ! "$script" ]] && { echo "Could not find AutoIt script $1"; return 1; }
	AutoIt.exe /ErrorStdOut "$(utw "$script")" "${@:2}"
}

TextEdit()
{
	local files=() program="$P64/Sublime Text 2/sublime_text.exe"
	for file in "$@"
	do
		[[ -f "$file" ]] && files+=("$(utw "$file")") || echo $(GetFilename "$file") does not exist
	done
	[[ $# == 0 || "${#files[@]}" > 0 ]] && start "$program" "${files[@]}"
}
