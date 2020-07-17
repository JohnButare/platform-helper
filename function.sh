# function.sh: common functions for non-interactive scripts

IsBash() { [[ $BASH_VERSION ]]; }
IsZsh() { [[ $ZSH_VERSION ]]; }

IsBash && { shopt -s nocasematch extglob;  PLATFORM_SHELL="bash"; whence() { type "$@"; }; }
IsZsh && { setopt KSH_GLOB EXTENDED_GLOB; PLATFORM_SHELL="zsh"; }

[[ ! $BIN ]] && { BASHRC="${BASH_SOURCE[0]%/*}/bash.bashrc"; [[ -f "$BASHRC" ]] && . "$BASHRC"; }

#
# Other
#

EvalVar() { r "${!1}" $2; } # EvalVar <variable> <var> - return the contents of the variable in variable, or set it to var
IsUrl() { [[ "$1" =~ ^(file|http[s]?|ms-windows-store)://.* ]]; }
IsInteractive() { [[ "$-" == *i* ]]; }
r() { [[ $# == 1 ]] && echo "$1" || eval "$2=""\"${1//\"/\\\"}\""; } # result VALUE VAR - echo value or set var to value (faster), r "- '''\"\"\"-" a; echo $a

clipw() 
{ 
	case "$PLATFORM" in 
		linux) { [[ "$DISPLAY" ]] && InPath xclip; } && { printf "%s" "$@" | xclip -sel clip; };;
		mac) printf "%s" "$@" | pbcopy;; 
		win) ( cd /; printf "%s" "$@" | clip.exe );; # cd / to fix WSL 2 error running from network share
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

	if InPath chsh; then chsh -s "$shell"
	elif InPath usermod; then sudo usermod --shell "$shell" $USER
	elif [[ -f /etc/passwd ]]; then { clipw "$shell"; sudo nano "/etc/passwd"; }
	else EchoErr "SetLoginShell: unable to change login shell to $1"
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

	[[ ! $shell ]] && { EchoErr "FindLoginShell: $1 is not a valid default shell"; return 1; }
	echo "$shell"
}

#
# Applications
#

i() # invoke the installer script (inst) saving the INSTALL_DIR
{ 
	local find force noRun select

	if [[ "$1" == "--help" ]]; then echot "\
usage: i [APP*|cd|dir|force|info|select]
  Install applications
  -nr, --no-run do not find or run the installation program
  -f, --force		check for a new installation location
  -s, --select	select the install location"
	return 0
	fi

  [[ "$1" == @(--no-run|-nr) ]] && { noRun="$1"; shift; }
	[[ "$1" == @(--force|-f) ]] && { force="true"; shift; }
	[[ "$1" == @(--select|-s) ]] && { select="--select"; shift; }
	[[ "$1" == @(select) ]] && { select="--select"; }
	[[ "$1" == @(force) ]] && { force="true"; }

	if [[ ! $noRun && ($force || $select || ! $INSTALL_DIR) ]]; then
		ScriptEval FindInstallFile --eval $select || return
		export INSTALL_DIR="$InstallDir"
		unset InstallDir file
	fi

	case "${1:-cd}" in
		cd) cd "$INSTALL_DIR";;
		dir) echo "$INSTALL_DIR";;
		force|select) return 0;;
		info) echo "The installation directory is $INSTALL_DIR";;
		*) inst --hint "$INSTALL_DIR" $noRun "$@";;
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
	IsPlatform win && { cmd.exe /c start ms-windows-store: >& /dev/null; return; }
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

	if [[ $ZSH_NAME ]]; then # single line statement fails in zsh
		read -s -k $n ${t[@]} "response"
	else
		read -n $n -s ${t[@]} response
	fi
	result="$?"

	[[ $m ]] && echo

	return "$result"
}

SleepStatus() # SleepStatus SECONDS
{
	printf "Waiting for $1 seconds..."
	for (( i=1; i<=$1; ++i )); do
 		ReadChars 1 1 && { echo "cancelled after $i seconds"; return 1; }
		printf "."
	done

	echo "done"
}

EchoErr() { printf "$@\n" >&2; }
PrintErr() { printf "$@" >&2; }

# display tabs
[[ "$TABS" == "" ]] && TABS=2
catt() { cat $* | expand -t $TABS; } 							# CatTab
echot() { echo -e "$*" | expand -t $TABS; } 			# EchoTab
lesst() { less -x $TABS $*; } 										# LessTab
printfp() { local stdin; read -d '' -u 0 stdin; printf "$@" "$stdin"; } # printf pipe: cat file | printf -v var

#
# Data Types
#

# array
CopyArray() { local ca; GetArrayDefinition "$1" ca; eval "$2=$ca"; }
GetArrayDefinition() { local gad="$(declare -p $1)"; gad="(${gad#*\(}"; r "${gad%\'}" $2; }
ShowArrayDetail() { declare -p "$1"; }

if IsBash; then
	DelimitArray() { local -n delimitArray="$2"; IFS=$1; echo "${delimitArray[*]}"; } # DelimitArray DELIMITER ARRAY_VAR
	IsArray() { [[ "$(declare -p "$1" 2> /dev/null)" =~ ^declare\ \-a.* ]]; }
	ShowArray() { local result; local -n showArray="$1"; printf -v result ' "%s"' "${showArray[@]}"; printf "%s\n" "${result:1}"; }
	ShowArrayKeys() { local var getKeys="!$1[@]"; eval local keys="( \${$getKeys} )"; ShowArray keys; }
	StringToArray() { IFS=$2 read -a $3 <<< "$1"; } # StringToArray STRING DELIMITER ARRAY_VAR

	RemoveFromArray() # VALUE ARRAY_VAR
	{
		local i value="$1"; local -n removeFromArray="$2"; 

		for i in "${!removeFromArray[@]}"; do
			[[ "${removeFromArray[$i]}" == "$value" ]] && unset removeFromArray[$i]
		done
	}

else
	DelimitArray() { (local get="$2[*]"; IFS=$1; echo "${(P)get}")} # DelimitArray DELIMITER ARRAY_VAR
	IsArray() { [[ "$(eval 'echo ${(t)'$1'}')" == "array" ]]; }
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
GetFileDateStamp() { date '+%Y%m%d' -d "$(stat --format="%y" "$1")"; }
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
ProperCase() { arg="${1,,}"; r "${arg^}" $2; }
QuoteSpaces() { sed 's/ /\\ /g'; } # escape (quote) spaces
RemoveCarriageReturn()  { sed 's/\r//g'; }
RemoveEmptyLines() { sed -r '/^\s*$/d'; }
RemoveSpace() { echo "${@// /}"; }
RemoveSpaceEnd() { echo "${@%%*( )}"; }
RemoveSpaceFront() { echo "${@##*( )}"; }
RemoveSpaceTrim() { echo "$(RemoveSpaceFront "$(RemoveSpaceEnd "$@")")"; }

BackToForwardSlash() { echo "${@//\\//}"; }
ForwardToBackSlash() { echo "${@////\\}"; }
QuoteBackslashes() { sed 's/\\/\\\\/g'; } # escape (quote) backslashes
RemoveBackslash() { echo "${@//\\/}"; }

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

EnsureDir() { echo "$(RemoveTrailingSlash "$1")/"; }
GetBatchDir() { GetFilePath "$0"; }
GetFileSize() { [[ ! -e "$1" ]] && return 1; local size="${2-MB}"; [[ "$size" == "B" ]] && size="1"; s="$(${G}du --apparent-size --summarize -B$size "$1" |& cut -f 1)"; echo "${s%%*([[:alpha:]])}"; } # FILE [SIZE]
GetFilePath() { local gfp="${1%/*}"; [[ "$gfp" == "$1" ]] && gfp=""; r "$gfp" $2; }
GetFileName() { r "${1##*/}" $2; }
GetFileNameWithoutExtension() { local gfnwe="$1"; GetFileName "$1" gfnwe; r "${gfnwe%.*}" $2; }
GetFileExtension() { local gfe="$1"; GetFileName "$gfe" gfe; [[ "$gfe" == *"."* ]] && r "${gfe##*.}" $2 || r "" $2; }
GetParentDir() { echo "$(GetFilePath "$(GetFilePath "$1")")"; }
GetRealPath() { ${G}readlink -f "$@"; } # resolve symbolic links
InPath() { which "$1" >& /dev/null; }
IsFileSame() { [[ "$(GetFileSize "$1" B)" == "$(GetFileSize "$2" B)" ]] && diff "$1" "$2" >& /dev/null; }
IsWindowsLink() { [[ "$PLATFORM" != "win" ]] && return 1; lnWin -s "$1" >& /dev/null; }
RemoveTrailingSlash() { r "${1%%+(\/)}" $2; }

fpc() { local arg; [[ $# == 0 ]] && arg="$PWD" || arg="$(${G}realpath -m "$1")"; echo "$arg"; clipw "$arg"; } # full path to clipboard
pfpc() { local arg; [[ $# == 0 ]] && arg="$PWD" || arg="$(${G}realpath -m "$1")"; clipw "$(utw "$arg")"; } # full path to clipboard in platform specific format

GetDriveLabel()
{ 
	! IsPlatform win && { echo ""; return 0; }
	cmd.exe /c vol "$1": |& RemoveCarriageReturn | grep -v "has no label" | grep "Volume in" | cut -d" " -f7;
}

FindInPath()
{
	local file="$1" 

	[[ -f "$file" ]] && { echo "$file"; return; }

	if [[ $ZSH ]]; then
		whence -p "${file}" && return
		IsPlatform wsl && { whence -p "${file}.exe" && return; }
	else
		type -P "${file}" && return
		IsPlatform wsl && { type -P "${file}.exe" && return; }
	fi

	return 1
}

GetFullPath() 
{ 
	local gfp="$(realpath -m "${@/#\~/$HOME}")"; r "$gfp" $2; # replace ~ with $HOME so we don't lose spaces in expansion
}

HideAll()
{
	! IsPlatform win && return

	for f in $('ls' -A | egrep '^\.'); do
		attrib "$f" +h 
	done
}

# Path conversion - ensure symbolic links are dereferenced for use in Windows
[[ "$PLATFORM_LIKE" == "cygwin" ]] && wslpath() { cygpath "$@"; }

wtu() # WinToUnix
{
	[[ ! "$@" || "$PLATFORM" != "win" ]] && { echo "$@"; return 1; }
  wslpath -u "$*"
}

utw() # UnixToWin
{ 
	local clean="" file="$@"

	[[ ! "$file" || "$PLATFORM" != "win" ]] && { echo "$@"; return 1; }

	file="$(realpath -m "$@")"

	# drvfs network shares (type 9p) do not map properly in WSL 2
	# sudo mount -t drvfs //nas3/home /tmp/t; wslpath -a -w /tmp/t # \\nas3\home (WSL1) \\wsl$\test1\tmp\t (WSL 2)
	if IsPlatform wsl2; then 
		read wsl win <<<$(findmnt --types=9p --noheadings --output=TARGET,SOURCE --target "$file")
		[[ $wsl && $win ]] && { echo "$(ptw "${file/$wsl/$win}")"; return; }
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

utwq() { utw "$@" | QuoteBackslashes; } # UnixToWinQuoted
ptw() { echo "${1////\\}"; } # PathToWin
DirCount() { RemoveSpace "$(command ls "$1" | wc -l)"; return "${PIPESTATUS[0]}"; }

explore() # explorer DIR - explorer DIR in GUI program
{
	local dir="$1"; [[ ! $dir ]] && dir="."
	
	IsPlatform mac && { open "$dir"; return; }
	IsPlatform wsl1 && { explorer.exe "$(utw "$dir")"; return; }
	IsPlatform wsl2 && { local dir="$PWD"; ( cd /tmp; explorer.exe "$(utw "$dir")" ); return; } # invalid argument when starting from mounted network share
	IsPlatform debian && InPath nautilus && { start nautilus "$dir"; return; }
	
	EchoErr "The $PLATFORM_ID platform does not have a file explorer"; return 1
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
		win) [[ -d /mnt ]] && for disk in /mnt/*; do getDisks+=( "$disk" ); done;;
	esac

	CopyArray getDisks "$1"
}

CopyDir()
{
	local help recursive sudo exclude=".git" o=(--info=progress2) f=( );

	# preserve metadata
	o+=(--links --perms --times --group --owner)

	IsPlatform win && sudo="sudoc" # required to preserve metadata in Windows
	
	# arguments
	for arg in "$@"; do
		[[ ! $1 ]] && { shift; continue; } 										# ignore empty options
		[[ $1 == @(-h|--help) ]] && { help="true"; shift; continue; }
		[[ $1 == @(-r|--recursive) ]] && { o+=(--recursive); recursive="true"; shift; continue; }
		[[ $1 == @(-v|--verbose) ]] && { o+=(--verbose); shift; continue; }
		f+=("$1"); shift
	done

	o+=(--exclude="$exclude")

	# help
	[[ "${#f[@]}" != "2" || $help ]]	&& { echot "usage: CopyDir SRC_DIR DEST_DIR
	-q, --quiet				minimize logging
	-r, --recursive		copy directories recursively
	-v, --verbose			maximize logging"; return 1; }

	local made result src="${f[0]}" dest="$(EnsureDir "${f[1]}")"; 
	local parent="$(GetParentDir "$dest")"
	local finalSrcDir="$(GetFileName "$(RemoveTrailingSlash "$src")")"
	local finalDestDir="$(GetFileName "$(RemoveTrailingSlash "$dest")")"

	# destination parent directory must exists
	[[ $parent && ! -d "$parent" ]] && { ${G}mkdir --parents "$parent" || return; }

	# destination parent directory must exist
	[[ ! -d "$dest" ]] && { made="true"; ${G}mkdir --parents "$dest" || return; }
	
	# perform the copy
	if [[ $recursive ]]; then

		# dest cannot contain the directory to copy otherwise it will be duplicated
		[[ "$finalSrcDir" == "$finalDestDir" ]] && dest="$parent"

		$sudo rsync "${o[@]}" "$src" "$dest"

	else # non-recursive copy - the source must be individual files
		$sudo rsync "${o[@]}" "$src"/* "$dest"
	fi
	result=$?

	[[ "$result" != "0" && $made ]] && rm -fr "$dest";
	return $result
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
		EchoErr "CopyFile: unrecognized option `$1`"; return 1;
	done

	[[ ! -f "$src" ]] && { EchoErr "CopyFile: cannot access \`$src\`: No such file"; return 1; }
	[[ ! -d "$dest" ]] && { EchoErr "CopyFile: cannot access \`$dest\`: No such directory"; return 1; }		
	GetFileName "$src" fileName || return
	GetFilePath "$(GetFullPath "$src")" src || return

	local fileSize="$(GetFileSize "$src/$fileName" MB)" || return
	(( fileSize < size )) && cp "$src/$fileName" "$dest" || CopyDir "$src/$fileName" "$dest"
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
	f="$(utw "$f")"

	# cd / to fix WSL 2 error running from network share
	( cd /; attrib.exe "$@" "$f" ); 
}

#
# Network
#

IsLocalHost() { local host="$(RemoveSpace "$1")"; [[ "$host" == "" || "$host" == "localhost" || "$(RemoveDnsSuffix "$host")" == "$(RemoveDnsSuffix $(hostname))" ]]; }
IsInDomain() { [[ $USERDOMAIN && "$USERDOMAIN" != "$HOSTNAME" ]]; }
GetInterface() { ifconfig | head -1 | cut -d: -f1; }
HostNameCheck() { SshHelper "$@" hostname; }
RemoveDnsSuffix() { echo "${1%%.*}"; }

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
	fi
}

GetPrimaryIpAddress() # GetPrimaryIpAddres [INTERFACE] - get default network adapter
{
	if IsPlatform wsl1; then 
		# default route (0.0.0.0 destination) with lowest metric
		route.exe -4 print | grep ' 0.0.0.0 ' | sort -k5 --numeric-sort | head -1 | tr -s " " | cut -d " " -f 5
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

	# Windows - ping and fping do not timeout quickly for unresponsive hosts so use ping.exe
	if IsPlatform win; then

		# resolve .local host - WSL getent does not currently resolve mDns (.local) addresses
		IsLocalAddress "$host" && { host="$(MdnsResolve "$host")" || return; }

		# resolve IP address to avoid slow ping.exe name resolution
		! IsIpAddress "$host" && { host="$(getent hosts "$host" | cut -d" " -f 1)"; [[ ! $host ]] && return 1; }

		ping.exe -n 1 -w "$timeout" "$host" |& grep "bytes=" &> /dev/null; return
	fi
	
	if InPath fping; then
		fping -r 1 -t "$timeout" -e "$host" &> /dev/null
	else
		ping -c 1 -W 1 "$host"  &> /dev/null # -W timeoutSeconds
	fi
}

IsAvailablePort() # ConnectToPort HOST PORT [TIMEOUT](200)
{
	local host="$1" port="$2" timeout="${3-200}"
 
 	# resolve .local host - WSL getent does not currently resolve mDns (.local) addresses
	IsPlatform win && IsLocalAddress "$host" && { host="$(MdnsResolve "$host")" || return; }

	if InPath ncat; then
		echo | ncat -C -w ${timeout}ms "$host" "$port" >& /dev/null
	elif IsPlatform win; then	
		! IsIpAddress "$host" && { host="$(GetIpAddress $host)" || return; }
		chkport-ip.exe "$host" "$port" "$timeout" >& /dev/null
	else
		return 1
	fi
}

PingResponse() # HOST [TIMEOUT](200ms) - returns ping response time in milliseconds
{ 
	local host="$1" timeout="${2-200}"

	# resolve .local host - WSL getent does not currently resolve mDns (.local) addresses
	IsPlatform win && IsLocalAddress "$host" && { host="$(MdnsResolve "$host")" || return; }

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
		sudo dhclient -r || return
		sudo dhclient || return
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
	else
		result="$(avahi-resolve-address -4 -n "$name" | awk '{ print $2; }')"
	fi

	[[ $result ]] && echo "$result"
}

# UNC Shares - \\SERVER\SHARE\DIRS
IsUncPath() { [[ "$1" =~ //.* ]]; }
GetUncServer() { local gus="${1#*( )//}"; gus="${gus#*@}"; r "${gus%%/*}" $2; } # //USER@SERVER/SHARE/DIRS
GetUncShare() { local gus="${1#*( )//*/}"; r "${gus%%/*}" $2; }
GetUncDirs() { local gud="${1#*( )//*/*/}"; [[ "$gud" == "$1" ]] && gud=""; r "$gud" $2; }

# SSH

IsSsh() { [[ "$SSH_TTY" ]]; }
RemoteServer() { echo "${SSH_CONNECTION%% *}"; }
RemoteServerName() { nslookup "$(RemoteServer)" | grep "name =" | cut -d" " -f3; }

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

# SSH

SshHelper() 
{
	local x mosh host args=()

	[[ $# == 0 || $1 == @(--help) ]]	&& { echot "usage: SshHelper HOST
	-m, --mosh					connecting using mosh
	-x, --x-forwarding  conntect with X forwarding"; return 1; }

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

	# resolve .local host - WSL getent does not currently resolve mDns (.local) addresses
	IsPlatform win && IsLocalAddress "$host" && { host="$(MdnsResolve "$host")" || { EchoErr "ssh: Could not resolve hostname $host: Name or service not known"; return 1; }; }

	[[ $mosh ]] && { mosh "$host" "$@"; return; }
	[[ ! $x ]] && { ssh "$host" $@; return; }

	# -y send diagnostic messages to syslog - supresses "Warning: No xauth data; using fake authentication data for X11 forwarding."
	if IsPlatform wsl1; then # WSL 1 does not support X sockets over ssh and requires localhost
		DISPLAY=localhost:0 ssh -Xy "$host" $@
	elif IsPlatform mac,wsl2; then # macOS XQuartz requires trusted X11 forwarding
		ssh -Yy "$host" $@
	else # use use untrusted (X programs are not trusted to use all X features on the host)
		ssh -Xy "$host" $@
	fi
} 

#
# Package Manager
#

HasPackageManger() { IsPlatform debian,mac,dsm,qnap,cygwin; }

package() 
{ 
	IsPlatform cygwin && { apt-cyg install -y "$@"; return; }
	IsPlatform debian && { sudo apt install -y "$@"; return; }
	IsPlatform dsm,qnap && { sudo opkg install "$@"; return; }
	IsPlatform mac && { brew install "$@"; return; }
	return 0
}

packageu() # package uninstall
{ 
	IsPlatform cygwin && { apt-cyg remove -y "$@"; return; }
	IsPlatform debian && { sudo apt remove -y "$@"; return; }
	IsPlatform dsm,qnap && { sudo opkg remove "$@"; return; }
	IsPlatform mac && { brew remove "$@"; return; }	
	return 0
}

packagel() # package list
{ 
	IsPlatform debian && { apt-cache search  "$@"; return; }
	IsPlatform dsm,qnap && { sudo opkg list "$@"; return; }
	IsPlatform mac && { brew search "$@"; return; }	
	return 0
}

packageli() { dpkg --get-selections; } # package list installed

PackageExist() 
{ 
	IsPlatform debian && { [[ "$(apt-cache search "^$@$")" ]] ; return; }
	IsPlatform mac && { brew search "/^$@$/" | egrep -v "No formula or cask found for" >& /dev/null; return; }	
	IsPlatform dsm,qnap && { [[ "$(packagel "$1")" ]]; return; }
	return 0
}

packages() # install list of packages, assuming each is in the path
{
	local p

	for p in "$@"; do
		! InPath "$p" && { package "$p" || return; }
	done

	return 0
}

PackageUpdate()
{
	IsPlatform debian && { sudo apt update || return; sudo apt dist-upgrade -y; return; }
	IsPlatform mac && { brew update || return; brew upgrade; return; }
	IsPlatform qnap && { sudo opkg update || return; sudo opkg upgade; return; }
	return 0
}

#
# Platform
# 

PlatformDescription() { echo "$PLATFORM $PLATFORM_LIKE $PLATFORM_ID"; }

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
			cygwin|debian|mingw|openwrt|qnap|synology) [[ "$p" == "$platformLike" ]] && return;;
			dsm|qts|srm|raspbian|rock|ubiquiti|ubuntu) [[ "$p" == "$platformId" ]] && return;;
			busybox) InPath busybox && return;;
			entware) IsPlatform qnap,synology && return;;

			# package management
			apt) InPath apt && return 0;;
			ipkg) InPath ipkg && return 0;;
			opkg) InPath opkg && return 0;;
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
	local files; GetPlatformFiles "$1" "$2" || return 0;
	for file in "${files[@]}"; do . "$file"; done
}

PlatformTmp() { IsPlatform win && echo "$(wtu "$tmp")" || echo "$TMP"; }

# RunPlatform PREFIX - call platrform functions, i.e. prefixWin.  Sample order win -> debian -> ubuntu -> wsl
function RunPlatform()
{
	local function="$1"; shift

	RunFunction $function $PLATFORM "$@" || return
	RunFunction $function $PLATFORM_LIKE "$@" || return
	RunFunction $function $PLATFORM_ID "$@" || return
	IsPlatform cygwin && { RunFunction $function cygwin "$@" || return; }
	IsPlatform qnap,synology && { RunFunction $function entware "$@" || return; }
	IsPlatform debian,mac && { RunFunction $function macDebian "$@" || return; }
	IsPlatform wsl && { RunFunction $function wsl "$@" || return; }
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
IsRoot() { IsPlatform cygwin && { IsElevated.exe > /dev/null; return; } || [[ $SUDO_USER ]]; }

IsExecutable()
{
	local p="$@"; [[ ! $p ]] && { EchoErr "usage: IsExecutable PROGRAM"; return 1; }

	# executable file - realpath resolves symbolic links, use -m so directory existence is not checked (which can error out for mounted network volumes)
	[[ -f "$p" ]] && { file "$(realpath -m "$p")" | egrep "executable|ELF" > /dev/null; return; }

	# alias, builtin, or function
	type -a "$p" >& /dev/null
}

IsTaskRunning() 
{
	local file="$1" 

	# If the file has a path component convert file to Windows format since
	# ProcesList returns paths in Windows format
	[[ "$(GetFilePath "$file")" ]] && file="$(utwq "$file")"

	ProcessList | egrep -v ",grep" | grep -i  ",$file" >& /dev/null
}

# IsWindowsProces: true if the executable is a native windows program requiring windows paths for arguments (c:\...) instead of POSIX paths (/...)
IsWindowsProces() 
{
	if IsPlatform cygwin; then 
		utw "$file" | egrep -iv cygwin > /dev/null; return;
	elif IsPlatform win; then
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

ProcessResource() { IsPlatform win && { start handle.exe "$@"; return; } || echo "Not Implemented"; }; alias handle='ProcessResource'

# start a program converting file arguments for the platform as needed

startUsage()
{
	echot "\
Usage: start [OPTION]... FILE [ARGUMENTS]...
	Start a program converting file arguments for the platform as needed

	-e, --elevate 					run the program with an elevated administrator token (Windows)
	-o, --open							open the the file using the associated program
	-w, --wait							wait for the program to run before returning
	-ws, --windows-style 		hidden|maximized|minimized|normal"
}

start() 
{
	local elevate file wait windowStyle

	while (( $# != 0 )); do
		case "$1" in "") : ;;
			-e|--elevate) ! IsElevated && elevate="--elevate";;
			-h|--help) startUsage; return 0;;
			-w|--wait) wait="--wait";;
			-ws|--window-style) [[ ! $2 ]] && { startUsage; return 1; }; windowStyle=( "$1" "$2" ); shift;;
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
		[[ ! $elevate ]] && IsConsoleProgram "$file" && { "$fullFile" "${args[@]}"; return; }

		# escape spaces for shell scripts so arguments are preserved when elevating - we must be elevating scripts here
		if IsShellScript "$fullFile"; then	
			IsBash && for (( i=0 ; i < ${#args[@]} ; ++i )); do args[$i]="${args[$i]// /\\ }"; done
			IsZsh && for (( i=1 ; i <= ${#args[@]} ; ++i )); do args[$i]="${args[$i]// /\\ }"; done	
		fi

		if IsShellScript "$fullFile"; then			
			RunProcess.exe $wait $elevate "${windowStyle[@]}" wsl.exe --user $USER -e "$(FindInPath "$fullFile")" "${args[@]}"
		else
			RunProcess.exe $wait $elevate "${windowStyle[@]}" "$(utw "$fullFile")" "${args[@]}"
		fi
		result=$?

		return $result
	fi

 	# run a non-Windows program
	if [[ $wait ]]; then
		(
			nohup "$file" "${args[@]}" >& /dev/null &
			wait $!
		)
	else
		(nohup "$file" "${args[@]}" >& /dev/null &)		
	fi
} 

sudop() 
{
	local SUDO_ASKPASS; [[ "$1" == @(-cs|--credential-store) ]] && { shift; credential -q exists secure default && SUDO_ASKPASS="$BIN/SudoAskPass"; }

}

unalias sudoc >& /dev/null;
sudoc()  # use the credential store to get the password if available, --preserve|-p to preserve the existing path (less secure)
{ 
	local p=(sudo) preserve; [[ "$1" == @(-p|--preserve) ]] && { preserve="true"; shift; }

	if [[ $preserve ]]; then
		if IsPlatform raspbian; then p+=( --preserve-env )
		elif ! IsPlatform mac; then p+=( --preserve-env=PATH )
		fi
	fi

	if credential -q exists secure default; then
		SUDO_ASKPASS="$BIN/SudoAskPass" "${p[@]}" --askpass "$@"; 
	else
		"${p[@]}" "$@"; 
	fi
} 
IsZsh && alias sudoc="nocorrect sudoc" # prevent auto correction, i.e. sudoc ls

#
# Scripts
#

IsInstalled() { type "$1" >& /dev/null && command "$1" IsInstalled; }
FilterShellScript() { egrep "shell script|bash.*script|Bourne-Again shell script|\.sh:|\.bash.*:"; }
IsShellScript() { file "$1" | FilterShellScript >& /dev/null; }
IsOption() { [[ "$1" =~ ^-.* ]]; }
IsWindowsOption() { [[ "$1" =~ ^/.* ]]; }
UnknownOption() {	EchoErr "${2:-$(ScriptName)}: unknown unrecognized option \`$1\`"; EchoErr "Try \`${2:-$(ScriptName)} --help\` for more information";	[[ "$-" == *i* ]] && return 1 || exit 1; }
MissingOperand() { EchoErr "${2:-$(ScriptName)}: missing $1 operand"; [[ "$-" == *i* ]] && return 1 || exit 1; }
IsDeclared() { declare -p "$1" >& /dev/null; } # IsDeclared NAME - NAME is a declared variable
IsFunction() { declare -f "$1" >& /dev/null; } # IsFunction NAME - NAME is a function
GetFunction() { declare -f | egrep -i "^$1 \(\) $" | sed "s/ () //"; return ${PIPESTATUS[1]}; } # GetFunction NAME - get function NAME case-insensitive

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

ScriptName() { IsBash && GetFileName "${BASH_SOURCE[-1]}" || GetFileName "$ZSH_SCRIPT"; }
ScriptDir() { IsBash && GetFilePath "${BASH_SOURCE[0]}" || GetFilePath "$ZSH_SCRIPT"; }

ScriptCd() { local dir; dir="$("$@" | ${G}head --lines=1)" && { echo "cd $dir"; cd "$dir"; }; }  # ScriptCd <script> [arguments](cd) - run a script and change the directory returned
ScriptEval() { local result; result="$("$@")" || return; eval "$result"; } # ScriptEval <script> [<arguments>] - run a script and evaluate it's output, typical variables to set using  printf "a=%q;b=%q;" "result a" "result b"

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
# Text Processing
#

Utf16toAnsi() { iconv -f utf-16 -t ISO-8859-1; }
Utf16to8() { iconv -f utf-16 -t UTF-8; }

GetTextEditor()
{
	if ! IsSsh; then
		case "$PLATFORM" in 
		
			linux)
				p="$P/sublime_text/sublime_text"; [[ -f "$p" ]] && { echo "$p"; return 0; }
				p="$P/sublime_text_3/sublime_text"; [[ -f "$p" ]] && { echo "$p"; return 0; }
				;;

			mac)
				p="$P/Sublime Text.app/Contents/SharedSupport/bin/subl"; [[ -f "$p" ]] && { echo "$p"; return 0; }
				echo "open -a TextEdit"; return 0
				;;

			win)
				p="$P/Sublime Text 3/subl.exe"; [[ -f "$p" ]] && { echo "$p"; return 0; }
				p="$P/Notepad++/notepad++.exe"; [[ -f "$p" ]] && { echo "$p"; return 0; }
				p="$WINDIR/system32/notepad.exe"; [[ -f "$p" ]] && { echo "$p"; return 0; }
				;;

		esac
	fi
	
	InPath geany && { echo "geany"; return 0; }
	InPath gedit && { echo "gedit"; return 0; }
	InPath nano && { echo "nano"; return 0; }
	InPath vi && { echo "vi"; return 0; }

	EchoErr "No text editor found"; return 1;
}

export EDITOR="$(GetTextEditor)"

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
	if [[ "$p" =~ (nano|open.*|vi) ]]; then
		$p "${files[@]}"
	else
		start $wait "${options[@]}" "$p" "${files[@]}"
	fi
}

#
# Virtual Machine
#

IsChroot() { [[ -f "/etc/debian_chroot" ]] || sudo systemd-detect-virt -r; }
IsVm() { [[ $(VmType) ]]; }
IsVmwareVm() { [[ "$(VmType)" == "vmware" ]]; }
IsHypervVm() { [[ "$(VmType)" == "hyperv" ]]; }

VmType() # vmware|hyperv
{	
	! InPath systemd-detect-virt && return 1 # assume physical host if systemd-detect-virt is not present

	local result="$(systemd-detect-virt -v)"

	if IsPlatform win && [[ "$result" == "microsoft" ]]; then # Hyper-V is detected on the physical host and the virtual machine as "microsoft"
		[[ "$(RemoveSpaceTrim $(wmic.exe baseboard get manufacturer, product | RemoveCarriageReturn | tail -2 | head -1))" != "Microsoft Corporation  Virtual Machine" ]] && result=""
	fi

	[[ "$result" == "microsoft" ]] && result="hyperv"
	[[ "$result" == "none" ]] && result=""

	echo "$result"
}

#
# Window
#

IsXServerRunning() { xprop -root >& /dev/null; }
RestartGui() { IsPlatform win && { RestartExplorer; return; }; IsPlatform mac && { RestartDock; return; }; }

WinInfo() { IsPlatform win && start Au3Info; } # get window information
WinList() { ! IsPlatform win && return; start cmdow /f | RemoveCarriageReturn; }

InitializeXServer()
{
	{ [[ "$DISPLAY" ]] || ! InPath xprop; } && return

	if [[ "$WSL" == "2" ]]; then
		export WSL_HOST="$(awk '/nameserver / {print $2; exit}' /etc/resolv.conf 2>/dev/null)"
		export DISPLAY="${WSL_HOST}:0"
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
		id="$(wmctrl -l -x | egrep -i "$title" | head -1 | cut -d" " -f1)"

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
