# common functions for non-interactive scripts

shopt -s nocasematch

r() { [[ $# == 1 ]] && echo "$1" || eval $2="$1"; } # result <value> <var> - echo value or set var to value (faster)
IsInteractive() { [[ "$-" == *i* ]]; }
IsFunction() { declare -f "$1" >& /dev/null; }
pause() { read -n 1 -p "${*-Press any key when ready...}"; }
clipw() { printf "$1" > /dev/clipboard; }
clipr() { cat /dev/clipboard; }
echoerr() { echo "${@}" > /dev/stderr; }

#
# strings
#
IsInList() { [[ $1 =~ (^| )$2($| ) ]]; }

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

wtu() { cygpath -u "$*"; }
utw() { cygpath -aw "$*"; }

#
# process
#

# start <program> <arguments>, file arguments need quotes: "\"$(utw <path>)\""
start() 
{
	local program="$1"
	[[ ! -f "$program" ]] && program="$(FindInPath "$1")"
	[[ ! -f "$program" ]] && { echoerr "Unable to start $1: file not found"; return 1; }
	cygstart "$(utw "$program")" "${@:2}";
} 
starto() { cygstart $1 "$(utw $2)" "${@:3}"; } # starto <option> <program>, i.e. startto --showmaximized notepad

sudo() 
{
	local program="mintty"
	[[ $# > 0 ]] && { program="$1"; shift; }
	[[ ! -f "$program" ]] && program="$(FindInPath "$program")"
	[[ ! -f "$program" ]] && { echoerr "Unable to start $1: file not found"; return 1; }
	IsElevated && cygstart "$(utw "$program")" "${@}" ||
		cygstart hstart /elevated "\"\"$(utw "$program")\"\" ${@}";
}

tc() { tcc.exe /c $*; }
sr() { ShellRun.exe "$(utw $*)"; }
IsElevated() { IsElevated.exe > /dev/null; }

# SendKeys <class> <title|class> <keys>
SendKeys() { AutoItScript SendKeys "${@}"; }

IsTaskRunning()
{
		local task="${1/\.exe/}"
		GetFilename "$task" task

		# ps -sW | cut -c 27- - full path, no extension for Cygwin processes
		# tasklist /nh /fo csv | cut -d, -f1 | grep -i "^\"$task\.exe\"$" > /dev/nul # no path, slower
		AutoItScript ProcessExists "${task}.exe"
}

ProcessClose() 
{
	local task="$1"; 
	[[ ! -f "$task" ]] && { echo "Could not find executable $task"; return 1; }
	GetFilename "$task" task
	process.exe -q "$task"
}

# Win [class] <title|class>, Au3Info.exe to get class
WinSetState() { AutoItScript WinSetState "${@}"; }
WinGetState() {	AutoItScript WinGetState "${@}"; }
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
	local files=""
	local program="$P64/Sublime Text 2/sublime_text.exe"
	#local program="$P32/Notepad++/notepad++.exe" # requires --show to not resize if using half screen with win-L or win-R

	for file in "$@"
	do
		for file in $(eval echo $file)
		do
			file=$(utw $file)
			if [[ -f "$file" ]]
			then
				files="$files \"$file\""
			else
				echo $(basename "$file") does not exist
			fi
		done
	done
	[[ "$files" != "" ]] && start "$program" $files
}
