# function.sh: common functions for non-interactive scripts

IsBash() { [[ $BASH_VERSION ]]; }
IsZsh() { [[ $ZSH_VERSION ]]; }

IsBash && { shopt -s nocasematch extglob expand_aliases;  PLATFORM_SHELL="bash"; whence() { type "$@"; }; }
IsZsh && { setopt EXTENDED_GLOB KSH_GLOB NO_NO_MATCH; PLATFORM_SHELL="zsh"; }

[[ ! $BIN ]] && { BASHRC="${BASH_SOURCE[0]%/*}/bash.bashrc"; [[ -f "$BASHRC" ]] && . "$BASHRC"; }

#
# Other
#

alias GetArgs='[[ $# == 0 ]] && set -- "$(cat)"' # get arguments from standard input if not specified on command line

EvalVar() { r "${!1}" $2; } # EvalVar <variable> <var> - return the contents of the variable in variable, or set it to var
IsUrl() { [[ "$1" =~ ^(file|http[s]?|ms-windows-store)://.* ]]; }
IsInteractive() { [[ "$-" == *i* ]]; }
r() { [[ $# == 1 ]] && echo "$1" || eval "$2=""\"${1//\"/\\\"}\""; } # result VALUE VAR - echo value or set var to value (faster), r "- '''\"\"\"-" a; echo $a

# update - temporary file location
UpdateInit() { updateDir="${1:-$DATA/update}"; [[ -d "$updateDir" ]] && return; mkdir --parents "$updateDir"; }
UpdateNeeded() { [[ $force || ! -f "$updateDir/$1" || "$(GetDateStamp)" != "$(GetFileDateStamp "$updateDir/$1")" ]]; }
UpdateDone() { touch "$updateDir/$1"; }
UpdateGet() { cat "$updateDir/$1"; }
UpdateSet() { printf "$2" > "$updateDir/$1"; }

clipok()
{ 
	case "$PLATFORM" in 
		linux) [[ "$DISPLAY" ]] && InPath xclip;;
		mac) InPath pbcopy;; 
		win) InPath clip.exe paste.exe;;
	esac
	
}

# clipboard
clipw() 
{ 
	! clipok && return 1;

	case "$PLATFORM" in 
		linux) printf "%s" "$@" | xclip -sel clip;;
		mac) printf "%s" "$@" | pbcopy;; 
		win) ( cd /; printf "%s" "$@" | clip.exe );; # cd / to fix WSL 2 error running from network share
	esac
}

clipr() 
{ 
	! clipok && return 1;
	
	case "$PLATFORM" in
		linux) xclip -o -sel clip;;
		mac) pbpaste;;
		win) paste.exe | tail -n +2;;
	esac
}

# logging
InitColor() { GREEN=$(printf '\033[32m'); RB_BLUE=$(printf '\033[38;5;021m') RB_INDIGO=$(printf '\033[38;5;093m') RESET=$(printf '\033[m'); }
header() { InitColor; printf "${RB_BLUE}*************** ${RB_INDIGO}$1${RB_BLUE} ***************${RESET}\n"; }
hilight() { InitColor; printf "${GREEN}$1${RESET}\n"; }

#
# Account
#

ActualUser() { echo "${SUDO_USER-$USER}"; }
UserExists() { getent passwd "$1" >& /dev/null; }

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

GetLoginShell()
{
	local r

	if InPath dscl; then # mac
		echo "$(dscl . -read $HOME UserShell | cut -d" " -f2)"
	elif [[ -f /etc/passwd ]]; then
		echo "$(grep $USER /etc/passwd | cut -d: -f7)"
	else
		EchoErr "GetCurrentShell: cannot determine current shell"
		return 1
	fi
}

SetLoginShell() # SetCurrentShell SHELL
{
	local shell; shell="$(FindLoginShell "$1")" || return

	[[ "$(GetLoginShell)" == "$shell" ]] && return 0

	if InPath chsh; then
		sudoc chsh -s "$shell" $USER
	elif InPath usermod; then
		sudoc usermod --shell "$shell" $USER
	elif [[ -f /etc/passwd ]]; then
		clipw "$shell" || { echo "Change the $USER login shell (after last :) to $shell"; pause; }
		sudoedit "/etc/passwd"
	else
		EchoErr "SetLoginShell: unable to change login shell to $1"
	fi
}

FindLoginShell() # FindShell SHELL - find the path to a valid login shell
{
	local shell shells="/etc/shells"

	[[ ! $1 ]] && { MissingOperand "shell" "FindLoginShell"; return; }

	if [[ -f "$shells" ]]; then
		shell="$(grep "/$1" /etc/shells | tail -1)" # assume the last shell is the newest
	else
		shell="$(which shell)" # no valid shell file, assume it is valid and search for it in the path
	fi

	[[ ! -f "$shell" ]] && { EchoErr "FindLoginShell: $1 is not a valid default shell"; return 1; }
	echo "$shell"
}

#
# Applications
#

i() # invoke the installer script (inst) saving the INSTALL_DIR
{ 
	local find force noRun select

	if [[ "$1" == "--help" ]]; then echot "\
usage: i [APP*|bak|cd|dir|force|info|select]
  Install applications
	-f,  --force		force installation even if a minimal install is selected
  -nr, --no-run 	do not find or run the installation program
  -f,  --force		check for a new installation location
  -s,  --select		select the install location"
	return 0
	fi

	[[ "$1" == @(--force|-f) ]] && { force="--force"; shift; }
  [[ "$1" == @(--no-run|-nr) ]] && { noRun="$1"; shift; }
	[[ "$1" == @(--select|-s) ]] && { select="--select"; shift; }
	[[ "$1" == @(select) ]] && { select="--select"; }
	[[ "$1" == @(force) ]] && { force="true"; }

	if [[ ! $noRun && ($force || $select || ! $INSTALL_DIR || ! -d "$INSTALL_DIR") ]]; then
		ScriptEval FindInstallFile --eval $select || return
		export INSTALL_DIR="$installDir"
		unset installDir file
	fi

	case "${1:-cd}" in
		bak) InstBak;;
		cd) cd "$INSTALL_DIR";;
		dir) echo "$INSTALL_DIR";;
		force|select) return 0;;
		info) echo "The installation directory is $INSTALL_DIR";;
		*) inst --hint "$INSTALL_DIR" $noRun $force "$@";;
	esac
}

powershell() 
{ 
	local files=( "A$P/PowerShell/7/pwsh.exe" "$WINDIR/system32/WindowsPowerShell/v1.0/powershell.exe" )

	[[ "$1" == @(--version|-v) ]] && { powershell -Command '$PSVersionTable'; return; }
	
	FindInPath Apowershell.exe && { powershell.exe "$@"; }
	for f in "${files[@]}"; do
		[[ -f "$f" ]] && { "$f" "$@"; return; }
	done
	
	EchoErr "Could not find powershell"; return 1;
}

store()
{
	IsPlatform win && { cmd.exe /c start ms-windows-store: >& /dev/null; }
	InPath gnome-software && { coproc gnome-software; }
	InPath snap-store && { coproc snap-store; }
	return 0
}

#
# Console
#

clear() { echo -en $'\e[H\e[2J'; }
pause() { local response m="${@:-Press any key when ready...}"; ReadChars "" "" "$m"; }

# ReadChars N [SECONDS] [MESSAGE] - silently read N characters into the response variable optionally waiting SECONDS
# - mask the differences between the read commands in bash and zsh
ReadChars() 
{ 
	local result n="${1:-1}" t m="$3"; [[ $2 ]] && t=( -t $2 ) # must be an array in zsh

	[[ $m ]] && printf "%s" "$m"

	if IsZsh; then # single line statement fails in zsh
		read -s -k $n ${t[@]} "response"
	else
		read -n $n -s ${t[@]} response
	fi
	result="$?"

	[[ $m ]] && echo

	return "$result"
}

SleepStatus()
{
	local i message seconds=5

	case "$#" in
		0) :;;
		1) IsInteger "$1" && seconds="$1" || message="$1";;
		2) message="$1"; seconds=$2;;
		*) EchoErr "usage: SleepStatus [MESSAGE](Waiting for n seconds) [SECONDS](5)"
	esac
	[[ ! $message ]] && message="Waiting for $seconds seconds"

	printf "$message..."
	for (( i=1; i<=$seconds; ++i )); do
 		ReadChars 1 1 && { echo "cancelled after $i seconds"; return 1; }
		printf "."
	done

	echo "done"
}

EchoErr() { printf "$@\n" >&2; }
PrintErr() { printf "$@" >&2; }

# printf pipe: read input for printf from a pipe, ex: cat file | printfp -v var
printfp() { local stdin; read -d '' -u 0 stdin; printf "$@" "$stdin"; }

# display tabs
[[ "$TABS" == "" ]] && TABS=2
catt() { cat $* | expand -t $TABS; } 							# CatTab
echot() { echo -e "$*" | expand -t $TABS; } 			# EchoTab
lesst() { less -x $TABS $*; } 										# LessTab

#
# Data Types
#

GetDef() { local gd="$(declare -p $1)"; gd="${gd#*\=}"; gd="${gd#\(}"; r "${gd%\)}" $2; } # get definition
GetDefs() { for gda in "$@"; do printf "$(GetDef $gda)"; done; } # get all definitions

# AppendArray VAR1 VAR2 ... - combine arrays into first array
AppendArray()
{
	local car="$1"; shift # combine array result
	for ca in "$@"; do eval "$car+=( $(GetDef $ca) )"; done
} 

# CopyArray SRC_VAR TARGET_VAR - copy source array variable to target array variable
CopyArray() { declare -g $(GetType $1) $2; eval "$2=( $(GetDef $1) )"; }

if IsBash; then
	GetType() { local gt="$(declare -p $1)"; gt="${gt#declare }"; r "${gt%% *}" $2; } # get type
	DelimitArray() { local -n delimitArray="$2"; IFS=$1; printf "${delimitArray[*]}"; } # DelimitArray DELIMITER ARRAY_VAR
	IsArray() { [[ "$(declare -p "$1" 2> /dev/null)" =~ ^declare\ \-a.* ]]; }
	ListArray() { local -n listArray="$1"; printf '%s\n' "${listArray[@]}"; }
	ShowArrayKeys() { local var getKeys="!$1[@]"; eval local keys="( \${$getKeys} )"; ShowArray keys; }
	StringToArray() { IFS=$2 read -a $3 <<< "$1"; } # StringToArray STRING DELIMITER ARRAY_VAR

	# ShowArray	ARRAY [DELIMITER]( )
	ShowArray()
	{
		local result delimiter="${2:- }"
		local -n showArray="$1"
		printf -v result '"%s"'"$delimiter" "${showArray[@]}"
		printf "%s\n" "${result%$delimiter}"
	}

	RemoveFromArray() # VALUE ARRAY_VAR
	{
		local i value="$1"; local -n removeFromArray="$2"; 

		for i in "${!removeFromArray[@]}"; do
			[[ "${removeFromArray[$i]}" == "$value" ]] && unset removeFromArray[$i]
		done
	}

else
	GetType() { local gt="$(declare -p $1)"; gt="${gt#typeset }"; r "${gt%% *}" $2; } # get type
	DelimitArray() { (local get="$2[*]"; IFS=$1; printf "${(P)get}")} # DelimitArray DELIMITER ARRAY_VAR
	IsArray() { [[ "$(eval 'echo ${(t)'$1'}')" == "array" ]]; }
	ListArray() { printf '%s\n' "${${(P)1}[@]}"; }
	ShowArray() { local var showArray="$1"; printf -v var ' "%s"' "${${(P)showArray}[@]}"; printf "%s\n" "${var:1}"; }
	ShowArrayKeys() { local var; eval 'local getKeys=( "${(k)'$1'[@]}" )'; ShowArray getKeys; }
	StringToArray() { IFS=$2 read -A $3 <<< "$1"; } # StringToArray STRING DELIMITER ARRAY_VAR

	RemoveFromArray() # VALUE ARRAY_VAR - remove all values from an array
	{
		local i value="$1" removeFromArray="$2"; 

		for (( i=1; i<=${#${(P)removeFromArray}}; i++ )) do
			[[ "${${(P)removeFromArray}[$i]}" == "$value" ]] && eval $removeFromArray'['$i']=()'
		done
	}

fi

# IsInArray [-w|--wild] [-aw|--awild] STRING ARRAY_VAR
IsInArray() 
{ 
	local wild; [[ "$1" == @(-w|--wild) ]] && { wild="true"; shift; }						# value contain glob patterns
	local awild; [[ "$1" == @(-aw|--array-wild) ]] && { awild="true"; shift; }	# array contains glob patterns
	local s="$1" a=() value

	IsBash && { local -n isInArray="$2"; a=( "${isInArray[@]}" ); } || { isInArray="$2"; a=( "${${(P)isInArray}[@]}" ); }
	
	for value in "${a[@]}"; do
		if [[ $wild ]]; then [[ "$value" == $s ]] && return 0;
		elif [[ $awild ]]; then [[ "$s" == $value ]] && return 0;
		else [[ "$s" == "$value" ]] && return 0; fi
	done;

	return 1
}

# date
CompareSeconds() { local a="$1" op="$2" b="$3"; (( ${a%.*}==${b%.*} ? 1${a#*.} $op 1${b#*.} : ${a%.*} $op ${b%.*} )); }
GetDateStamp() { ${G}date '+%Y%m%d'; }
GetFileDateStamp() { ${G}date '+%Y%m%d' -d "$(${G}stat --format="%y" "$1")"; }
GetTimeStamp() { ${G}date '+%Y%m%d_%H%M%S'; }

GetSeconds() # GetSeconds [<date string>](current time) - seconds from 1/1/1970 to specified time
{
	[[ $1 ]] && { ${G}date +%s.%N -d "$1"; return; }
	[[ $# == 0 ]] && ${G}date +%s.%N; # only return default date if no argument is specified
}

# integer
IsInteger() { [[ "$1" =~ ^[0-9]+$ ]]; }
HexToDecimal() { echo "$((16#${1#0x}))"; }

# string
IsInList() { [[ $1 =~ (^| )$2($| ) ]]; }
IsWild() { [[ "$1" =~ (.*\*|\?.*) ]]; }
ProperCase() { GetArgs; arg="${1,,}"; r "${arg^}" $2; }
RemoveCarriageReturn()  { sed 's/\r//g'; }
RemoveEmptyLines() { ${G}sed -r '/^\s*$/d'; }
RemoveSpace() { GetArgs; echo "${@// /}"; }
RemoveSpaceEnd() { GetArgs; echo "${@%%*( )}"; }
RemoveSpaceFront() { GetArgs; echo "${@##*( )}"; }
RemoveSpaceTrim() { GetArgs; echo "$(RemoveSpaceFront "$(RemoveSpaceEnd "$@")")"; }

QuoteBackslashes() { sed 's/\\/\\\\/g'; } # escape (quote) backslashes
QuotePath() { sed 's/\//\\\//g'; } # escape (quote) path (forward slashes - /) using a back slash (\)
QuoteSpaces() { GetArgs; echo "$@" | sed 's/ /\\ /g'; } # escape (quote) spaces using a back slash (\)
RemoveQuotes() { sed 's/"//g'; }

BackToForwardSlash() { GetArgs; echo "${@//\\//}"; }
ForwardToBackSlash() { GetArgs; echo "${@////\\}"; }
RemoveBackslash() { GetArgs; echo "${@//\\/}"; }

if IsZsh; then
	GetWord() 
	{ 
		(( $# < 2 || $# > 3 )) && { EchoErr "usage: GetWord STRING WORD [DELIMITER] - 1 based"; return 1; }
		local s="$1" delimiter="${3:- }" word="$2"; echo "${${(@ps/$delimiter/)s}[$word]}"
	}
else
	GetWord() 
	{ 
		(( $# < 2 || $# > 3 )) && { EchoErr "usage: GetWord STRING WORD [DELIMITER] - 1 based"; return 1; }
		local word=$(( $2 + 1 )); IFS=${3:- }; set -- $1; 
		((word=word-1)); (( word < 1 || word > $# )) && echo "" || echo "${!word}"
	}
fi

# time
ShowTime() { ${G}date '+%F %T.%N %Z' -d "$1"; }
ShowSimpleTime() { ${G}date '+%D %T' -d "$1"; }
TimerOn() { startTime="$(${G}date -u '+%F %T.%N %Z')"; }
TimestampDiff () { ${G}printf '%s' $(( $(${G}date -u +%s) - $(${G}date -u -d"$1" +%s))); }
TimerOff() { s=$(TimestampDiff "$startTime"); printf "%02d:%02d:%02d" $(( $s/60/60 )) $(( ($s/60)%60 )) $(( $s%60 )); }

#
# File System
#

CopyFileProgress() { rsync --info=progress2 "$@"; }
DirCount() { RemoveSpace "$(command ls "$1" | wc -l)"; return "${PIPESTATUS[0]}"; }
EnsureDir() { GetArgs; echo "$(RemoveTrailingSlash "$@")/"; }
GetBatchDir() { GetFilePath "$0"; }
GetFileSize() { GetArgs; [[ ! -e "$1" ]] && return 1; local size="${2-MB}"; [[ "$size" == "B" ]] && size="1"; s="$(${G}du --apparent-size --summarize -B$size "$1" |& cut -f 1)"; echo "${s%%*([[:alpha:]])}"; } # FILE [SIZE]
GetFilePath() { GetArgs; local gfp="${1%/*}"; [[ "$gfp" == "$1" ]] && gfp=""; r "$gfp" $2; }
GetFileName() { GetArgs; r "${1##*/}" $2; }
GetFileNameWithoutExtension() { GetArgs; local gfnwe="$1"; GetFileName "$1" gfnwe; r "${gfnwe%.*}" $2; }
GetFileExtension() { GetArgs; local gfe="$1"; GetFileName "$gfe" gfe; [[ "$gfe" == *"."* ]] && r "${gfe##*.}" $2 || r "" $2; }
GetFullPath() { GetArgs; local gfp="$(GetRealPath "${@/#\~/$HOME}")"; r "$gfp" $2; } # replace ~ with $HOME so we don't lose spaces in expansion
GetLastDir() { GetArgs; echo "$@" | RemoveTrailingSlash | GetFileName; }
GetParentDir() { GetArgs; echo "$@" | GetFilePath | GetFilePath; }
IsDirEmpty() { GetArgs; [[ "$(find "$1" -maxdepth 0 -empty)" == "$1" ]]; }
InPath() { local f option; IsZsh && option="-p"; for f in "$@"; do ! which $option "$f" >& /dev/null && return 1; done; return 0; }
IsFileSame() { [[ "$(GetFileSize "$1" B)" == "$(GetFileSize "$2" B)" ]] && diff "$1" "$2" >& /dev/null; }
IsWindowsLink() { [[ "$PLATFORM" != "win" ]] && return 1; lnWin -s "$1" >& /dev/null; }
RemoveTrailingSlash() { GetArgs; r "${1%%+(\/)}" $2; }

GetFiles() { find "${2:-.}" -maxdepth 1 -name "$1" -type f -print0; } # for while loop
ReadFile() { read -d $'\0' file; }

fpc() { local arg; [[ $# == 0 ]] && arg="$PWD" || arg="$(GetRealPath -m "$1")"; echo "$arg"; clipw "$arg"; } # full path to clipboard
pfpc() { local arg; [[ $# == 0 ]] && arg="$PWD" || arg="$(GetRealPath -m "$1")"; clipw "$(utw "$arg")"; } # full path to clipboard in platform specific format

explore() # explorer DIR - explorer DIR in GUI program
{
	local dir="$1"; [[ ! $dir ]] && dir="."
	
	IsPlatform mac && { open "$dir"; return; }
	IsPlatform wsl1 && { explorer.exe "$(utw "$dir")"; return; }
	IsPlatform wsl2 && { local dir="$PWD"; ( cd /tmp; explorer.exe "$(utw "$dir")" ); return 0; } # cd to local directory to fix invalid argument error running programs from SMB mounted shares
	InPath nautilus && { start nautilus "$dir"; return; }
	InPath mc && { mc; return; } # Midnight Commander

	EchoErr "The $PLATFORM_ID platform does not have a file explorer"; return 1
}

# FileCacheFlush - flush cached files. Lots of file copying, such as for a file backup, can fill up the file cache and consume available memory.
FileCacheFlush()
{ 
	sudoc sync || return
	[[ -f /proc/sys/vm/drop_caches ]] && { sudoc bash -c "echo 3 > /proc/sys/vm/drop_caches" || return; }
	return 0
}

# FileCommand mv|cp|ren SOURCE... DIRECTORY - mv or cp ignoring files that do not exist
FileCommand() 
{ 
	local args command="$1" dir="${@: -1}" file files=0 n=$(($#-2))

	for arg in "${@:2:$n}"; do
		IsOption "$arg" && args+=( "$arg" )
		[[ -e "$arg" ]] && { args+=( "$arg" ); (( ++files )); }
	done
	(( files == 0 )) && return 0

	case "$command" in
		ren) 'mv' "${args[@]}" "$dir";;
		cp|mv)
			[[ ! -d "$dir" ]] && { EchoErr "FileCommand: accessing \`$dir\`: No such directory"; return 1; }
			"$command" -t "$dir" "${args[@]}";;
		*) EchoErr "FileCommand: unknown command $command"; return 1;;
	esac
}

FindInPath()
{
	local file="$1" 

	[[ -f "$file" ]] && { echo "$file"; return; }

	if IsZsh; then
		whence -p "${file}" && return
		IsPlatform wsl && { whence -p "${file}.exe" && return; }
	else
		type -P "${file}" && return
		IsPlatform wsl && { type -P "${file}.exe" && return; }
	fi

	return 1
}

GetRealPath()  # resolve symbolic links
{
	# use -m so directory existence is not checked (which can error out for mounted network volumes)
	InPath ${G}realpath && { ${G}realpath -m "$@"; return; }
	${G}readlink -f "$@"
}

HideAll()
{
	! IsPlatform win && return

	for f in $('ls' -A | grep -E '^\.'); do
		attrib "$f" +h 
	done
}

# MoveAll SRC DEST - move contents of SRC to DEST including hidden files and folders
MoveAll()
{ 
	[[ ! $1 || ! $2 ]] && { EchoErr "usage: MoveAll SRC DEST"; return 1; }
	shopt -s dotglob nullglob
	mv "$1/"* "$2" && rmdir "$1"
}

SelectFile() # DIR PATTERN MESSAGE
{
	local dir="$1" pattern="$2" message="${3:-Choose a file}" result items=()

	pushd "$dir" > /dev/null || return
	
	if IsZsh; then
		for f in $~pattern; do items+=( "$f" "" ); done
	else
		for f in $pattern; do items+=( "$f" "" ); done
	fi

	result=$(dialog --stdout --backtitle "Select File" \
  	--menu "Choose file to install:" $(($LINES-5)) 50 $(($LINES)) "${items[@]}")
	clear

	[[ ! $result ]] && { EchoErr "a file was not selected"; return 1; }

	file="$dir/$result"
	popd > /dev/null
}

# UnzipPlatform - use platform specific unzip to fix unzip errors syncing metadata on Windows drives
UnzipPlatform()
{
	local zip="$1" dest="$2"

	if IsPlatform win; then
		7z.exe x "$(utw "$zip")" -o"$(utw "$dest")" -y -bb3 || return
	else
		unzip -o "$zip" -d "$dest" || return
	fi

	return 0
}

# Path Conversion

utwq() { utw "$@" | QuoteBackslashes; } # UnixToWinQuoted
ptw() { printf "%s\n" "${1//\//"\\"}"; } # PathToWin - use printf so zsh does not interpret back slashes (\)

wtu() # WinToUnix
{
	[[ ! "$@" || "$PLATFORM" != "win" ]] && { echo "$@"; return 1; }
  wslpath -u "$*"
}

utw() # UnixToWin
{ 
	local clean="" file="$@"

	[[ ! "$file" || "$PLATFORM" != "win" ]] && { echo "$@"; return 1; }

	file="$(GetRealPath "$@")" || return

	# network shares do not translate properly in WSL 2
	if IsPlatform wsl2; then 
		read wsl win <<<$(findmnt --types=cifs --noheadings --output=TARGET,SOURCE --target "$file")
		[[ $wsl && $win ]] && { ptw "${file/$wsl/$win}"; return; } # network share	
	fi

	# utw requires the file exist in newer versions of wsl
	if [[ ! -e "$@" ]]; then
		local filePath="$(GetFilePath "$@")"
		[[ ! -d "$filePath" ]] && { ${G}mkdir --parents "$filePath" >& /dev/null || return; }
		touch "$@" || return
		clean="true"
	fi

	wslpath -w "$file"

	[[ $clean ]] && { rm "$@" || return; }
	return 0
} 

# File Attributes

FileHide() { for f in "$@"; do [[ -f "$f" ]] && { attrib "$f" +h || return; }; done; return 0; }
FileTouchAndHide() { [[ ! -f "$1" ]] && { touch "$1" || return; }; FileHide "$1"; return 0; }
FileShow() { for f in "$@"; do [[ -f "$f" ]] && { attrib "$f" -h || return; }; done; return 0; }
FileHideAndSystem() { for f in "$@"; do [[ -f "$f" ]] && { attrib "$f" +h +s || return; }; done; return 0; }

attrib() # attrib FILE [OPTIONS] - set Windows file attributes, attrib.exe options must come after the file
{ 
	! IsPlatform win && return
	
	local f="$1"; shift

	[[ ! -e "$f" ]] && { EchoErr "attrib: $f: No such file or directory"; return 2; }
	
	# /L flag does not work (target changed not link) from WSL when full path specified, i.e. attrib.exe /l +h 'C:\Users\jjbutare\Documents\data\app\Audacity'
	( cd "$(GetFilePath "$f")"; attrib.exe "$@" "$(GetFileName "$f")" );
}

#
# Network
#

ipconfig() { IsPlatform win && { ipconfig.exe "$@"; } || ip r; }
IsLocalHost() { local host="$(RemoveSpace "$1")"; [[ "$host" == "" || "$host" == "localhost" || "$(RemoveDnsSuffix "$host")" == "$(RemoveDnsSuffix $(hostname))" ]]; }
IsInDomain() { [[ $USERDOMAIN && "$USERDOMAIN" != "$HOSTNAME" ]]; }
GetInterface() { ifconfig | head -1 | cut -d: -f1; }
GetDefaultGateway() { route -n | grep '^0.0.0.0' | awk '{ print $2; }'; }
GetMacAddress() { grep " ${1:-$HOSTNAME}$" "/etc/ethers" | cut -d" " -f1; }
HostNameCheck() { SshHelper "$@" hostname; }
RemoveDnsSuffix() { GetArgs; echo "${@%%.*}"; }
UrlExists() { curl --output /dev/null --silent --head --fail "$1"; }

GetBroadcastAddress()
{
	if IsPlatform mac; then
		ifconfig | grep broadcast | head -1 |  awk '{ print $6; }'
	else
		ifconfig | head -2 | tail -1 | awk '{ print $6; }'
	fi
}

GetPrimaryAdapterName()
{
	if IsPlatform win; then
		ipconfig.exe | grep $(GetPrimaryIpAddress) -B 4 | grep "Ethernet adapter" | awk -F adapter '{ print $2 }' | sed 's/://' | sed 's/ //' | RemoveCarriageReturn
	else
		ifconfig | grep "UP,BROADCAST,RUNNING" | head -1 | cut -d":" -f1
	fi
}

GetPrimaryIpAddress() # GetPrimaryIpAddres [INTERFACE] - get default network adapter
{
	if IsPlatform wsl1; then 
		# default route (0.0.0.0 destination) with lowest metric
		route.exe -4 print | grep ' 0.0.0.0 ' | sort -k5 --numeric-sort | head -1 | tr -s " " | cut -d " " -f 5
	else
		ifconfig $1 | grep inet | grep -v 'inet6|127.0.0.1' | head -n 1 | awk '{ print $2 }'
	fi
}

GetIpAddress() # [HOST]
{
	local host="$1" ip

	[[ ! $host ]] && { GetPrimaryIpAddress; return; }

	IsIpAddress "$host" && { echo "$host"; return; }

	# Resolve mDNS (.local) addresses exclicitly as the name resolution commands below can fail on some hosts
	# In Windows WSL the methods below never resolve mDNS addresses
	IsLocalAddress "$host" && { MdnsResolve "$host" 2> /dev/null; return; }

	# - getent on Windows sometimes holds on to a previously allocated IP address.   This was seen with old IP address in a Hyper-V guest on test VLAN after removing VLAN ID) - host and nslookup return new IP.
	# - host and getent are fast and can sometimes resolve .local (mDNS) addresses 
	# - host is slow on wsl 2 when resolv.conf points to the Hyper-V DNS server for unknown names
	if InPath getent; then ip="$(getent hosts "$host" |& cut -d" " -f 1)"
	elif InPath host; then ip="$(host -t A "$host" |& grep -v "^ns." | head -1 | grep "has address" | cut -d" " -f 4)"
	elif InPath nslookup; then ip="$(nslookup "$host" |& tail -3 | grep "Address:" | cut -d" " -f 2)"
	fi

	[[ $ip ]] && { echo "$ip"; return ; }
}

IsIpAddress() # IP
{
  local ip="$1"
  [[ ! "$ip" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]] && return 1
	
  if IsBash; then
  	IFS='.' read -a ip <<< "$ip"
  	(( ${ip[0]}<255 && ${ip[1]}<255 && ${ip[2]}<255 && ${ip[3]}<255 ))
  else # zsh
  	ip=( "${(s/./)ip}" )
  	(( ${ip[1]}<255 && ${ip[2]}<255 && ${ip[3]}<255 && ${ip[4]}<255 ))
  fi
}

IsAvailable() # HOST [TIMEOUT](200ms) - returns ping response time in milliseconds
{ 
	local host="$1" timeout="${2-200}"

	# resolve the IP address explicitly:
	# - mDNS name resolution is intermitant (double check this on various platforms)
	# - Windows ping.exe name resolution is slow for non-existent hosts
	host="$(GetIpAddress "$host")" || return 
	
	if IsPlatform wsl1; then # WSL 1 ping and fping do not timeout quickly for unresponsive hosts so use ping.exe
		ping.exe -n 1 -w "$timeout" "$host" |& grep "bytes=" &> /dev/null 
	elif InPath fping; then
		fping -r 1 -t "$timeout" -e "$host" &> /dev/null
	else
		ping -c 1 -W 1 "$host" &> /dev/null # -W timeoutSeconds
	fi
}

IsAvailablePort() # ConnectToPort HOST PORT [TIMEOUT](200)
{
	local host="$1" port="$2" timeout="${3-200}"; host="$(GetIpAddress "$host")" || return

	if InPath ncat; then
		echo | ncat -C -w ${timeout}ms "$host" "$port" >& /dev/null
	elif IsPlatform win; then	
		chkport-ip.exe "$host" "$port" "$timeout" >& /dev/null
	else
		return 0 # assume the host is available if we cannot check
	fi
}

WaitForPort() # WaitForPort HOST PORT [TIMEOUT_MILLISECONDS](200) [SECONDS](120)
{
	local host="$1" port="$2" timeout="${3-200}" seconds="${4-200}"

	printf "Waiting for $host:$port..."
	for (( i=1; i<=$seconds; ++i )); do
 		ReadChars 1 1 && { echo "cancelled after $i seconds"; return 1; }
		printf "."
		IsAvailablePort "$host" "$port" "$timeout" && { echo "found"; return; }
	done

	echo "not found"; return 1
}

PingResponse() # HOST [TIMEOUT](200ms) - returns ping response time in milliseconds
{ 
	local host="$1" timeout="${2-200}"; host="$(GetIpAddress "$host")" || return

	if InPath fping; then
		fping -r 1 -t "$timeout" -e "$host" |& grep " is alive " | cut -d" " -f 4 | tr -d '('
		return ${PIPESTATUS[0]}
	else
		ping -c 1 -W 1 "$host" |& grep "time=" | cut -d" " -f 7 | tr -d 'time=' # -W timeoutSeconds
		return ${PIPESTATUS[0]}
	fi

}

DhcpRenew()
{
	echo "Old IP: $(GetPrimaryIpAddress)" || return

	if IsPlatform win; then
		local adapter="$(GetPrimaryAdapterName)"
		echo "Old IP: $(GetPrimaryIpAddress)" || return
		ipconfig.exe /release "$adapter" || return
		ipconfig.exe /renew "$adapter" || return
	elif IsPlatform debian && InPath dhclient; then
		sudoc dhclient -r || return
		sudoc dhclient || return
	fi

	echo "New IP: $(GetPrimaryIpAddress)" || return
}

IsLocalAddress() { IsBash && [[ "$1" =~ .*'.'local$ ]] || [[ "$1" =~ .*\\.local$ ]]; }

MdnsResolve()
{
	local name="$1" result

	{ [[ ! $name ]] || ! IsLocalAddress "$name"; } && return 1

	# Currently WSL does not resolve mDns .local address but Windows does
	if IsPlatform win; then
		result="$(ping.exe -4 -n 1 -w 200 "$name" |& grep "Pinging " | awk '{ print $3; }' | sed 's/\[//g' | sed 's/\]//g')"
	elif IsPlatform mac; then
		result="$(ping -c 1 -W 200 "$name" |& grep "bytes from" | gcut -d" " -f 4 | sed s/://)"
	else
		result="$(avahi-resolve-address -4 -n "$name" | awk '{ print $2; }')"
	fi

	[[ ! $result ]] && { EchoErr "mDNS: Could not resolve hostname $host"; return 1; } 
	echo "$result"
}

# UNC Shares - \\SERVER\SHARE\DIRS
IsUncPath() { [[ "$1" =~ //.* ]]; }
GetUncServer() { GetArgs; local gus="${1#*( )//}"; gus="${gus#*@}"; r "${gus%%/*}" $2; } # //USER@SERVER/SHARE/DIRS
GetUncShare() { GetArgs; local gus="${1#*( )//*/}"; r "${gus%%/*}" $2; }
GetUncDirs() { GetArgs; local gud="${1#*( )//*/*/}"; [[ "$gud" == "$1" ]] && gud=""; r "$gud" $2; }

FileToDesc() # short description for the file
{
	local desc file="$1"

	file="$(unc get unc "$file")"

	# remove the server DNS suffix from UNC paths
	IsUncPath "$file" && file="//$(GetUncServer "$file" | RemoveDnsSuffix)/$(GetUncShare "$file")/$(GetUncDirs "$file")"

	# replace $HOME with ~
	file="${file/$USERS/~}"

	 echo "$file"
}


# SSH

GetSshUser() { echo "$1" | cut -s -d@ -f 1; } # USER@SERVER:PORT
GetSshHost() { echo "$1" | cut -d@ -f 2 | cut -d: -f 1; }
GetSshPort() { echo "$1" | cut -s -d: -f 2; }

IsSsh() { [[ "$SSH_TTY" ]]; }
RemoteServer() { echo "${SSH_CONNECTION%% *}"; }
RemoteServerName() { nslookup "$(RemoteServer)" | grep "name =" | cut -d" " -f3; }

IsInSshConfig() # IsInSshConfig HOST - return true if HOST matches an entry in ~/.ssh/config
{
	local hostFull="$1" host="$(GetSshHost "$1")" defaultFull default="DEFAULT_CONFIG"
	defaultFull="${hostFull/$host/$default}"
	# echo $defaultFull-$default-$hostFull-$host
	# ssh -G "$defaultFull" | grep -i -v "^hostname ${default}$" > /tmp/1.txt	
	# ssh -G "$hostFull" | grep -i -v "^hostname ${host}$" > /tmp/2.txt
	# colordiff /tmp/1.txt /tmp/2.txt && echo SAME

	[[ "$(ssh -G "$defaultFull" | grep -i -v "^hostname ${default}$")" != "$(ssh -G "$hostFull" | grep -i -v "^hostname ${host}$")" ]] && return 0; # something other than the host changed
	ssh -G "$hostFull" | grep -i "^hostname ${host}$" >& /dev/null && return 1 # host is unchanged
	return 0
}

# SshAgentHelper - wrapper for SshAgent which ensures the correct variables are set in the calling shell
SshAgentHelper()
{ 
	[[ -f "$HOME/.ssh/environment" ]] && . "$HOME/.ssh/environment"
	SshAgent "$@" && . "$HOME/.ssh/environment"
}

# SshAgentCheck - check and start the SSH Agent if needed
SshAgentCheck()
{
	[[ -f "$HOME/.ssh/environment" ]] && . "$HOME/.ssh/environment"
	ssh-add -L >& /dev/null && return
	SshAgentHelper start --verbose --quiet
}

SshHelper() 
{
	local args=() mosh host port x

	[[ $# == 0 || $1 == @(--help) ]]	&& { echot "usage: SshHelper HOST
	-m, --mosh					connecting using mosh
	-x, --x-forwarding  connect with X forwarding"; return 1; }

	while (( $# != 0 )); do 
		case "$1" in "") : ;;
			-m|--mosh) mosh="true";;
			-x|--x-forwarding) x="true";;
			*) { ! IsOption "$1" && [[ ! $host ]]; } && host="$1" || args+=( "$1" );;
		esac
		shift
	done
	[[ ! $host ]] && MissingOperand "host" "SshHelper"
	set -- "${args[@]}"

	# fix SSH Agent if possible
	SshAgentCheck 

	# port - get a port specified in the host and remove it from the name, format USER@HOST:PORT
	port="$(GetSshPort "$host")" 
	host="${host/:$port/}"

	# identify port and IP if the host is in ~/.ssh/config 	
	if ! IsInSshConfig "$host"; then
		local hostFull="$host" ip mdnsIp; host="$(GetSshHost "$host")"

		# assume port 22 if none was specified
		[[ ! $port ]] && port="22"

		# resolve the host using DNS first
		ip="$(GetIpAddress "$host")"

		# if the DNS ip did not resolve or is not responding try mDNS (.local) name resolution
		if ! IsLocalAddress "$host" && { [[ ! $ip ]] || ! IsAvailablePort "$ip" "$port"; }; then
			mdnsIp="$(MdnsResolve "$host.local" 2> /dev/null)"
			[[ $mdnsIp ]] && ip="$mdnsIp"
		fi

		# unable to resolve the hostname
		if [[ ! $ip ]]; then
			EchoErr "ssh: Could not resolve $host : Name or service not known"
			return 1
		fi

		# the host is not available on the specified port
		if ! IsAvailablePort "$ip" "$port"; then
			EchoErr "ssh: $host ($ip) is not responding on port $port"
			return 1
		fi

		# replace the hostname with the IP address that was resolved
		host="${hostFull/$host/$ip}"
	fi

	# arguments
	args=($host)
	[[ $port ]] && args+=(-p "$port")
	[[ ! $mosh ]] && args+=(-y) # send diagnostic messages to syslog to supresses "Warning: No xauth data; using fake authentication data for X11 forwarding." in Windows
	set -- "${args[@]}" "$@"

	local log="" # -y send output to syslog

	# connect using ssh
	if [[ $mosh ]]; then
		mosh "$@"
	elif [[ ! $x ]]; then
		ssh "$@"
	elif IsPlatform wsl1; then # WSL 1 does not support X sockets over ssh and requires localhost
		DISPLAY=localhost:0 ssh -X $log "$@"
	elif IsPlatform mac,wsl2; then # macOS XQuartz requires trusted X11 forwarding, where X programs are trusted to use all X features on the host
		ssh -Y $log "$@"
	else # for everything else, use untrusted X Forwarding, where X programs are not trusted to use all X features on the host
		ssh -X $log "$@"
	fi
}

SshPermissionFix()
{
	local user="$1"; [[ ! $user ]] && { MissingOperand "user"; return 1; }
	
	sudoc bash -l << EOF
	find "$USERS/$user/.ssh" | xargs chown $user || exit
	find "$USERS/$user/.ssh" | sudo xargs chgrp "$user" || exit
	sudo chmod 700 "$USERS/$user/.ssh" || exit

	[[ -f "$USERS/$user/.ssh/config" ]] && sudo chmod 700 "$USERS/$user/.ssh/config" || exit
	[[ -f "$USERS/$user/.ssh/authorized_keys" ]] && sudo chmod 700 "$USERS/$user/.ssh/authorized_keys" || exit
	[[ -f "$USERS/$user/.ssh/id_rsa" ]] && sudo chmod 700 "$USERS/$user/.ssh/id_rsa" || exit
	[[ -f "$USERS/$user/.ssh/id_ed25519" ]] && sudo chmod 700 "$USERS/$user/.ssh/id_ed25519" || exit
EOF
}

#
# Package Manager
#

HasPackageManger() { IsPlatform debian,mac,dsm,qnap; }
PackageListInstalled() { InPath dpkg && dpkg --get-selections "$@"; }
PackagePurge() { InPath wajig && wajig purgeremoved; }
PackageSize() { InPath wajig && wajig sizes | grep "$1"; }

package() # package install
{
	local packages=() 
	local mac=( atop hdparm inotify-tools squidclient virt-what )	
	local force; [[ "$1" =~ (^--force$|^-f$) ]] && { force="true"; shift; }
	local noPrompt; [[ "$1" =~ (^--no-prompt$|^-np$) ]] && { noPrompt="true"; shift; }

	# add non-excluded packages
	for package in "$@"; do
		if IsPlatform mac; then ! IsInArray "$package" mac && packages+=( $package )
		else packages+=( $package )
		fi
	done
	[[ "$@" == "" ]] && return 0

	# just return if all of the packages are installed
	[[ ! $force ]] && { PackageInstalled "$@" && return; }

	# disable prompting if possible
	[[ $noPrompt ]] && IsPlatform debian && noPrompt="DEBIAN_FRONTEND=noninteractive"

	# install the packages
	IsPlatform debian && { sudoc $noPrompt apt install -y "${packages[@]}"; return; }
	IsPlatform dsm,qnap && { sudoc opkg install "${packages[@]}"; return; }
	IsPlatform mac && { HOMEBREW_NO_AUTO_UPDATE=1 brew install "${packages[@]}"; return; }

	return 0
}

packageu() # package uninstall
{ 
	IsPlatform debian && { sudo apt remove -y "$@"; return; }
	IsPlatform dsm,qnap && { sudo opkg remove "$@"; return; }
	IsPlatform mac && { brew remove "$@"; return; }	
	return 0
}

PackageExist()  # return true if the specified package exists
{ 
	IsPlatform debian && { [[ "$(apt-cache search "^$@$")" ]] ; return; }
	IsPlatform mac && { brew search "/^$@$/" | grep -v "No formula or cask found for" >& /dev/null; return; }	
	IsPlatform dsm,qnap && { [[ "$(packagel "$1")" ]]; return; }
	return 0
}

PackageInfo() # shows files installed by a package
{
	! IsPlatform debian && return
	
	apt show "$1" || return
	! PackageInstalled "$1" && return
	dpkg -L "$1"; echo
	dpkg -L "$1" | grep 'bin/'
}

PackageInstalled() # return true if a package is installed
{ 
	[[ "$@" == "" ]] && return 0

	if InPath dpkg; then
		# ensure the package counts match, i.e. dpkg --get-selectations samba will not return anything if samba-common is installed
		[[ "$(dpkg --get-selections "$@" |& grep -v "no packages found" | wc -l)" == "$#" ]]
	else
		InPath "$@" # assumes each package name is in the path
	fi
}

PackageList() # package list - search for a package
{ 
	IsPlatform debian && { apt-cache search  "$@"; return; }
	IsPlatform dsm,qnap && { sudo opkg list "$@"; return; }
	IsPlatform mac && { brew search "$@"; return; }	
	return 0
}

PackageUpdate() # update packages
{
	IsPlatform debian && { sudo apt update || return; sudo apt dist-upgrade -y; return; }
	IsPlatform mac && { brew update || return; brew upgrade; return; }
	IsPlatform qnap && { sudo opkg update || return; sudo opkg upgade; return; }
	return 0
}

PackageWhich() # which package is an executable in
{
	IsPlatform debian && { dpkg -S "$(which "$1")"; return; }
}

#
# Platform
# 

PlatformSummary() { echo "$(PlatformArchitecture) $(PlatformDescription)"; }
PlatformDescription() { echo "$PLATFORM $PLATFORM_LIKE $PLATFORM_ID"; }
PlatformArchitecture() { ! InPath dpkg && return; dpkg --print-architecture; } # amd64, armhf

# IsPlatform platform[,platform,...] [platform platformLike PlatformId wsl](PLATFORM PLATFORM_LIKE PLATFORM_ID)
function IsPlatform()
{
	local checkPlatforms="$1" platforms p
	local platform="${2:-$PLATFORM}" platformLike="${3:-$PLATFORM_LIKE}" platformId="${4:-$PLATFORM_ID}" wsl="${5:-$WSL}"
	local platforms=( ${checkPlatforms//,/ } ); IsZsh && platforms=( "${=platforms}" )

	for p in "${platforms[@]}"; do
		case "$p" in 
			win|mac|linux) [[ "$p" == "$platform" ]] && return;;
			wsl) [[ "$platform" == "win" && "$platformLike" == "debian" ]] && return;; # Windows Subsystem for Linux
			wsl1|wsl2) [[ "$p" == "wsl$wsl" ]] && return;;
			debian|mingw|openwrt|qnap|synology) [[ "$p" == "$platformLike" ]] && return;;
			dsm|qts|srm|pi|rock|ubiquiti|ubuntu) [[ "$p" == "$platformId" ]] && return;;

			# other
			busybox) InPath busybox && return;;
			entware) IsPlatform qnap,synology && return;;

			# package management
			apt) InPath apt && return;;
			ipkg) InPath ipkg && return;;
			opkg) InPath opkg && return;;

			# kernel
			winkernel) [[ "$PLATFORM_KERNEL" == @(wsl1|wsl2) ]] && return;;
			linuxkernel) [[ "$PLATFORM_KERNEL" == "linux" ]] && return;;
			pikernel) [[ "$PLATFORM_KERNEL" == "pi" ]] && return;;

			# virtual machine
			container) IsContainer && return;;
			docker) IsDocker && return;;
			chroot) IsChroot && return;;
			host|physical) ! IsChroot && ! IsContainer && ! IsVm && return;;
			guest|vm|virtual) IsVm && return;;

		esac

		[[ "$p" == "${platform}${platformId}" ]] && return 0 # i.e. LinuxUbuntu WinUbuntu
	done

	return 1
}

function GetPlatformFiles() # GetPlatformFiles FILE_PREFIX FILE_SUFFIX
{
	files=()

	[[ -f "$1$PLATFORM$2" ]] && files+=("$1$PLATFORM$2")
	[[ -f "$1$PLATFORM_LIKE$2" ]] && files+=("$1$PLATFORM_LIKE$2")
	[[ -f "$1$PLATFORM_ID$2" ]] && files+=("$1$PLATFORM_ID$2")

	return 0
}

SourceIfExists() { [[ -f "$1" ]] && { . "$1" || return; }; return 0; }

SourceIfExistsPlatform() # SourceIfExistsPlatform PREFIX SUFFIX
{
	local file files

	GetPlatformFiles "$1" "$2" || return 0;
	for file in "${files[@]}"; do . "$file" || return; done
}

PlatformTmp() { IsPlatform win && echo "$ADATA/Temp" || echo "$TMP"; }

# RunPlatform PREFIX - call platrform functions, i.e. prefixWin.  Sample order win -> debian -> ubuntu -> wsl
function RunPlatform()
{
	local function="$1"; shift

	RunFunction $function $PLATFORM "$@" || return
	RunFunction $function $PLATFORM_LIKE "$@" || return
	RunFunction $function $PLATFORM_ID "$@" || return
	IsPlatform wsl && { RunFunction $function wsl "$@" || return; }
	IsPlatform wsl1 && { RunFunction $function wsl1 "$@" || return; }
	IsPlatform wsl2 && { RunFunction $function wsl2 "$@" || return; }
	IsPlatform entware && { RunFunction $function entware "$@" || return; }
	IsPlatform debian,mac && { RunFunction $function DebianMac "$@" || return; }
	IsPlatform vm && { RunFunction $function vm "$@" || return; }
	IsPlatform physical && { RunFunction $function physical "$@" || return; }
	return 0
}

IsDesktop()
{
	IsPlatform mac,win && return 0
	IsPlatform debian && [[ "$XDG_CURRENT_DESKTOP" != "" ]] && return 0
	return 1
}

IsServer() { ! IsDesktop; }

#
# Process
#

console() { start proxywinconsole.exe "$@"; } # console PROGRAM ARGS - attach PROGRAM to a hidden Windows console (powershell, nuget, python, chocolatey), alternatively run in a regular Windows console (Start, Run, bash --login)
CoprocCat() { cat 0<&${COPROC[0]}; } # read output from a process started with coproc
IsRoot() { [[ "$USER" == "root" || $SUDO_USER ]]; }
IsSystemd() { cat /proc/1/status | grep -i "^Name:[	 ]*systemd$" >& /dev/null; } # systemd must be PID 1

IsExecutable()
{
	local p="$@"; [[ ! $p ]] && { EchoErr "usage: IsExecutable PROGRAM"; return 1; }
	local ext="$(GetFileExtension "$p")"

	# file $ADATA/Microsoft/WindowsApps/*.exe returns empty, so assume files that end in exe are executable
	[[ -f "$p" && "$ext" =~ (^exe$|^com$) ]] && return 0

	# executable file
	[[ -f "$p" ]] && { file "$(GetRealPath "$p")" | grep -E "executable|ELF" > /dev/null; return; }

	# alias, builtin, or function
	type -a "$p" >& /dev/null
}

IsTaskRunning() 
{
	local file="$1" 

	# If the file has a path component convert file to Windows format since
	# ProcesList returns paths in Windows format
	[[ "$(GetFilePath "$file")" ]] && file="$(utwq "$file")"

	ProcessList | grep -v ",grep" | grep -i  ",$file" >& /dev/null
}

# IsWindowsProces: true if the executable is a native windows program requiring windows paths for arguments (c:\...) instead of POSIX paths (/...)
IsWindowsProces() 
{
	if IsPlatform win; then
		file "$file" | grep PE32 > /dev/null; return;
	else
			return 0
	fi
}

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

ProcessIdExists() {	kill -0 $1 >& /dev/null; } # kill is a fast check

ProcessKill()
{
	local p="$1"

	if [[ "$PLATFORM" == "win" ]]; then
		start pskill "$p" > /dev/null
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

handle() { ProcessResource; }
ProcessResource()
{
	IsPlatform win && { start handle.exe "$@"; return; }
	echo "Not Implemented"
}

# start a program converting file arguments for the platform as needed

startUsage()
{
	echot "\
Usage: start [OPTION]... FILE [ARGUMENTS]...
	Start a program converting file arguments for the platform as needed

	-e, --elevate 					run the program with an elevated administrator token (Windows)
	-o, --open							open the the file using the associated program
	-s, --sudo							run the program as root
	-t, --terminal 					the terminal used to elevate programs, valid values are wsl|wt
													wt does not preserve the current working directory
	-w, --wait							wait for the program to run before returning
	-ws, --window-style 		hidden|maximized|minimized|normal"
}

start() 
{
	local elevate file sudo terminal wait windowStyle

	while (( $# != 0 )); do
		case "$1" in "") : ;;
			-e|--elevate) ! IsElevated && IsPlatform win && elevate="--elevate";;
			-h|--help) startUsage; return 0;;
			-s|--sudo) sudo="sudoc";;
			-t|--terminal) [[ ! $2 ]] && { startUsage; return 1; }; terminal="$2"; shift;;
			-w|--wait) wait="--wait";;
			-ws|--window-style) [[ ! $2 ]] && { startUsage; return 1; }; windowStyle=( "--window-style" "$2" ); shift;;
			*)
				! IsOption "$1" && [[ ! $file ]] && { file="$1"; shift; break; }
				UnknownOption "$1" start; return
		esac
		shift
	done
	[[ ! "$file" ]] && { MissingOperand "file" "start"; return; }

	local args=( "$@" ) fileOrig="$file"

	# open file with the associated program
	local open=()
	if IsPlatform mac; then open=( open )
	elif IsPlatform win; then open=( cmd.exe /c start \"open\" /b ) # must set title with quotes so quoted arguments are interpreted as file to start, test with start "/mnt/c/Program Files"
	elif InPath xdg-open; then open=( xdg-open )
	else open="NO_OPEN"; fi

	# start Mac application
	[[ "$file" =~ \.app$ ]] && { open -a "$file" --args "${args[@]}"; return; }

	# start directories and URL's
	{ [[ -d "$file" ]] || IsUrl "$file"; } && { start "${open[@]}" "$file" "${args[@]}"; return; }

	# verify the file	
	[[ ! -f "$file" ]] && file="$(FindInPath "$file")"
	[[ ! -f "$file" ]] && { EchoErr "Unable to find $fileOrig"; return 1; }

	# start files with a specific extention
	case "$(GetFileExtension "$file")" in
		cmd) start "${open[@]}" "$file" "${args[@]}"; return;;
		js|vbs) start cscript.exe /NoLogo "$file" "${args[@]}"; return;;
	esac

	# start non-executable files
	! IsExecutable "$file" && { start "${open[@]}" "$file" "${args[@]}"; return; }

	# start Windows processes, or start a process on Windows elevated
	if IsPlatform win && ( [[ $elevate ]] || IsWindowsProgram "$file" ) ; then
		local fullFile="$(GetFullPath "$file")"

		# convert POSIX paths to Windows format (i.e. c:\...)		
		if IsWindowsProgram "$file"; then
			local a newArgs=()
			for a in "${args[@]}"; do 
				[[  -e "$a" || ( ! "$a" =~ .*\\.* && "$a" =~ .*/.* && -e "$a" ) ]] && { newArgs+=( "$(utw "$a")" ) || return; } || newArgs+=( "$a" )
			done
			args=("${newArgs[@]}")
		fi

		# start Windows console process
		[[ ! $elevate ]] && IsConsoleProgram "$file" && { $sudo "$fullFile" "${args[@]}"; return; }

		# escape spaces for shell scripts so arguments are preserved when elevating - we must be elevating scripts here
		if IsShellScript "$fullFile"; then	
			IsBash && for (( i=0 ; i < ${#args[@]} ; ++i )); do args[$i]="${args[$i]// /\\ }"; done
			IsZsh && for (( i=1 ; i <= ${#args[@]} ; ++i )); do args[$i]="${args[$i]// /\\ }"; done	
		fi

		if IsShellScript "$fullFile"; then
			local p="wsl.exe"; [[ "$terminal" == "wt" ]] && InPath wt.exe && p="wt.exe -d "$PWD" wsl.exe"
			if IsSystemd; then
				RunProcess.exe $wait $elevate "${windowStyle[@]}" bash.exe -c \""$(FindInPath "$fullFile") "${args[@]}""\"
			else
				RunProcess.exe $wait $elevate "${windowStyle[@]}" $p --user $USER -e "$(FindInPath "$fullFile")" "${args[@]}"
			fi
		else
			RunProcess.exe $wait $elevate "${windowStyle[@]}" "$(utw "$fullFile")" "${args[@]}"
		fi
		result=$?

		return $result
	fi

 	# run a non-Windows program
	if [[ $wait ]]; then
		(
			nohup $sudo "$file" "${args[@]}" >& /dev/null &
			wait $!
		)
	else
		(nohup $sudo "$file" "${args[@]}" >& /dev/null &)		
	fi
} 

#
# Scripts
#

FilterShellScript() { grep -E "shell script|bash.*script|Bourne-Again shell script|\.sh:|\.bash.*:"; }
GetFunction() { declare -f | grep -iE "^$1 \(\) $" | sed "s/ () //"; return ${PIPESTATUS[1]}; } # GetFunction NAME - get function NAME case-insensitive
IsInstalled() { type "$1" >& /dev/null && command "$1" IsInstalled; }
IsShellScript() { file "$1" | FilterShellScript >& /dev/null; }
IsDeclared() { declare -p "$1" >& /dev/null; } # IsDeclared NAME - NAME is a declared variable
IsFunction() { declare -f "$1" >& /dev/null; } # IsFunction NAME - NAME is a function
ScriptErr() { EchoErr "$(ScriptName): $1"; }

# arguments
IsOption() { [[ "$1" =~ ^-.* ]]; }
IsWindowsOption() { [[ "$1" =~ ^/.* ]]; }
MissingOperand() { EchoErr "${2:-$(ScriptName)}: missing $1 operand"; [[ "$-" == *i* ]] && return 1 || exit 1; }
UnknownOption() {	EchoErr "${2:-$(ScriptName)}: unknown unrecognized option \`$1\`"; EchoErr "Try \`${2:-$(ScriptName)} --help\` for more information.";	[[ "$-" == *i* ]] && return 1 || exit 1; }

# RunFunction NAME SUFFIX - call a function with the specified suffix
RunFunction()
{ 
	local method="$1" suffix="$2"; shift 2
	[[ $suffix ]] && IsFunction $method${suffix^} && { $method${suffix^} "$@"; return; }
	return 0
}

IsAlias() { type "-t $1" |& grep alias > /dev/null; } # IsAlias NAME - NAME is an alias
GetAlias() { local a=$(type "$1"); a="${a#$1 is aliased to \`}"; echo "${a%\'}"; }

CheckCommand() 
{	
	[[ ! $1 ]]  && MissingOperand "command"
	IsFunction "${1,,}Command" && { command="${1,,}"; return 0; } ; 
	EchoErr "$(ScriptName): unknown command \`$1\`"
	exit 1
} 

CheckSubCommand() 
{	
	local sub="$1"
	[[ ! $2 ]]  && MissingOperand "$sub command"
	command="$sub$(ProperCase "$2")Command"; 
	IsFunction "$command" && return 0
	EchoErr "$(ScriptName): unknown $sub command \`$2\`"; exit 1
} 

ScriptName() { IsBash && GetFileName "${BASH_SOURCE[-1]}" || GetFileName "$ZSH_SCRIPT"; }
ScriptDir() { IsBash && GetFilePath "${BASH_SOURCE[0]}" || GetFilePath "$ZSH_SCRIPT"; }

ScriptCd() { local dir; dir="$("$@" | ${G}head --lines=1)" && { echo "cd $dir"; cd "$dir"; }; }  # ScriptCd <script> [arguments](cd) - run a script and change the directory returned

# ScriptEval <script> [<arguments>] - run a script and evaluate the output.
#    Typically the output is variables to set, such as printf "a=%q;b=%q;" "result a" "result b"
ScriptEval() { local result; result="$("$@")" || return; eval "$result"; } 

# ScriptReturn [-s|--show] <var>... - return the specified variables as output from the script in a escaped format.
#    The script should be called using ScriptEval.
#   -e, --export		the returned variables should be exported
#   -s, --show			show the variables in a human readable format instead of a escpaed format
ScriptReturn() 
{
	local var avar fmt="%q" arrays export
	[[ "$1" == @(-e|--export) ]] && { export="export "; shift; }
	[[ "$1" == @(-s|--show) ]] && { fmt="\"%s\""; shift; }

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
	done
}

#
# Security
#

sudox() { sudoc XAUTHORITY="$HOME/.Xauthority" "$@"; }

sudoc()  # use the credential store to get the password if available, --preserve|-p to preserve the existing path (less secure)
{ 
	local p=(sudo) preserve; [[ "$1" == @(-p|--preserve) ]] && { preserve="true"; shift; }

	if [[ $preserve ]]; then
		if IsPlatform pi; then p+=( --preserve-env )
		elif ! IsPlatform mac; then p+=( --preserve-env=PATH )
		fi
	fi

	if credential -q exists secure default; then
		SUDO_ASKPASS="$BIN/SudoAskPass" "${p[@]}" --askpass "$@"; 
	else
		"${p[@]}" "$@"; 
	fi
} 

sudoe()  # sudoedit with credentials
{ 
	if credential -q exists secure default; then
		SUDO_ASKPASS="$BIN/SudoAskPass" sudoedit --askpass "$1";
	else
		sudo "$1"; 
	fi
} 

#
# Text Processing
#

Utf16toAnsi() { iconv -f utf-16 -t ISO-8859-1; }
Utf16to8() { iconv -f utf-16 -t UTF-8; }

GetTextEditor()
{
	if HasWindowManager; then
		IsInstalled sublime && { echo "$(sublime program)"; return 0; }
		IsPlatform win && InPath "$P/Notepad++/notepad++.exe" && { echo "$P/Notepad++/notepad++.exe"; return 0; }
		InPath geany && { echo "geany"; return 0; }
		IsPlatform mac && { echo "open -a TextEdit"; return 0; }
		IsPlatform win && InPath notepad.exe && { echo "notepad.exe"; return 0; }
		InPath gedit && { echo "gedit"; return 0; }
	fi

	InPath micro && { echo "micro"; return 0; }
	InPath nano && { echo "nano"; return 0; }
	InPath vi && { echo "vi"; return 0; }
	EchoErr "No text editor found"; return 1;
}

# SetTextEditor - set the default text editor for commands.  The text editor must:
# - be a physical file in the path 
# - accept a UNIX style path as the file to edit
# - return only when the file has been edited
SetTextEditor()
{
	local e
	
	if IsInstalled sublime; then e="$BIN/sublime -w"
	elif InPath geany; then e="geany -i"
	elif InPath micro; then e="micro"
	elif InPath nano; then e="nano"
	elif InPath vi; then e="vi"
	fi
		
	export {SUDO_EDITOR,EDITOR}="$e"
}

TextEdit()
{
	local file files=() p=""
	local wait; [[ "$1" == +(-w|--wait) ]] && { wait="--wait"; shift; }
	local options=(); while IsOption "$1"; do options+=( "$1" ); shift; done
	local p="$(GetTextEditor)"; [[ ! $p ]] && { EchoErr "No text editor found"; return 1; }

	for file in "$@"; do
		[[ -e "$file" ]] && files+=( "$file" ) || EchoErr "$(GetFileName "$file") does not exist"
	done

	# return if no files exist
	[[ $# == 0 || "${#files[@]}" > 0 ]] || return 0

	# edit the file
	if [[ "$p" =~ (micro|nano|open.*|vi) ]]; then
		$p "${files[@]}"
	else
		start $wait "${options[@]}" "$p" "${files[@]}"
	fi
}

#
# Virtual Machine
#

IsChroot() { GetChrootName; [[ $CHROOT_NAME ]]; }
ChrootName() { GetChrootName; echo "$CHROOT_NAME"; }
ChrootPlatform() { ! IsChroot && return; [[ $(uname -r) =~ [Mm]icrosoft ]] && echo "win" || echo "linux"; }

IsContainer() { ! InPath systemd-detect-virt && return 1; [[ "$(systemd-detect-virt --container)" != "none" ]]; }
IsDocker() { ! InPath systemd-detect-virt && return 1; [[ "$(systemd-detect-virt --container)" == "docker" ]]; }

IsVm() { GetVmType; [[ $VM_TYPE ]]; }
IsVmwareVm() { GetVmType; [[ "$VM_TYPE" == "vmware" ]]; }
IsHypervVm() { GetVmType; [[ "$VM_TYPE" == "hyperv" ]]; }
VmType() { GetVmType; echo "$VM_TYPE"; }

GetChrootName()
{
	[[ $CHROOT_CHECKED ]] && return
	
	if [[ -f "/etc/debian_chroot" ]]; then
		CHROOT_NAME="$(cat "/etc/debian_chroot")"
	elif ! IsPlatform winKernel && [[ "$(${G}stat / --printf="%i")" != "2" ]]; then
		CHROOT_NAME="chroot"
	elif IsPlatform wsl1 && sudoc systemd-detect-virt -r; then
		CHROOT_NAME="chroot"
	fi

	CHROOT_CHECKED="true"
}

GetVmType() # vmware|hyperv
{	
	[[ $VM_TYPE_CHECKED ]] && return

	local result

	if InPath systemd-detect-virt; then
		result="$(systemd-detect-virt -v)"
	elif InPath virt-what; then
		result="$(sudoc virt-what)"
	else
		result=""
	fi

	[[ "$result" == "microsoft" ]] && result="hyperv"
	[[ "$result" == "none" ]] && result=""

	# In wsl2, Hyper-V is detected on the physical host and the virtual machine as "microsoft" so check the product
	if IsPlatform wsl2 && [[ "$result" == "hyperv" ]]; then
		local product="$(RemoveSpaceTrim $(wmic.exe baseboard get product | RemoveCarriageReturn | tail -2 | head -1))"
		if [[ "$product" == "440BX Desktop Reference Platform" ]]; then result="vmware"
		elif [[ "$product" == "Virtual Machine" ]]; then result="hyperv"
		else result=""
		fi
	fi

	VM_TYPE_CHECKED="true" VM_TYPE="$result"
}

#
# Window
#

HasWindowManager() { ! IsSsh || IsXServerRunning; } # assume if we are not in an SSH shell we are running under a Window manager
IsXServerRunning() { xprop -root >& /dev/null; }
RestartGui() { IsPlatform win && { RestartExplorer; return; }; IsPlatform mac && { RestartDock; return; }; }

WinInfo() { IsPlatform win && start Au3Info; } # get window information
WinList() { ! IsPlatform win && return; start cmdow /f | RemoveCarriageReturn; }

InitializeXServer()
{
	{ [[ "$DISPLAY" ]] || ! InPath xauth; } && return

	if IsPlatform wsl2; then
		export DISPLAY="$(GetDefaultGateway):0"
		export LIBGL_ALWAYS_INDIRECT=1
	elif [[ $SSH_CONNECTION ]]; then
		export DISPLAY="$(GetWord "$SSH_CONNECTION" 1):0"
	else
		export DISPLAY=:0
	fi

	return 0
}

WinSetStateUsage()
{
	echot "\
Usage: WinSetState [OPTION](--activate) WIN
	Set the state of the specified windows title or class

	-a, --activate 					make the window active
	-c, --close 						close the window gracefully

	-max, --maximize				maximize the window
	-min, --minimize				minimize the window

	-h, --hide							hide the window (Windows)
	-uh, --unhide						unhide the window (Windows)"
}

WinSetState()
{
	local wargs=( /res /act ) args=( -a ) title result

	while (( $# != 0 )); do
		case "$1" in "") : ;;
			-a|--activate) wargs=( /res /act ); args=( -a );;
			-c|--close) wargs=( /res /act ); args=( -c );;
			-max|--maximize) wargs=( /res /act /max ) args=( -a );;
			-min|--minimize) wargs=( /min );;
			-h|--hide) wargs=( /hid );;
			-uh|--unhide) wargs=( /vis );;
			-h|--help) WinSetStateUsage; return 0;;
			*)
				if [[ ! $title ]]; then title="$1"
				else UnknownOption "$1" "WinSetState"; return; fi
		esac
		shift
	done

	# X Windows - see if title matches a windows running on the X server
	if [[ $DISPLAY ]] && InPath wmctrl; then
		id="$(wmctrl -l -x | grep -i "$title" | head -1 | cut -d" " -f1)"

		if [[ $id ]]; then
			[[ $args ]] && { wmctrl -i "${args[@]}" "$id"; return; }
			return 0
		fi
	fi

	# Windows - see if the title matches a windows running in Windows
	if IsPlatform win; then
		cmdow.exe "$title" "${wargs[@]}" >& /dev/null
		return
	fi

	return 1
}

# platform specific functions
SourceIfExistsPlatform "$BIN/function." ".sh" || return

FUNCTIONS="true"
