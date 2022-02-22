# function.sh: common functions for non-interactive scripts

set -o pipefail # pipes return first non-zero result

IsBash() { [[ $BASH_VERSION ]]; }
IsZsh() { [[ $ZSH_VERSION ]]; }

if IsBash; then
	shopt -s extglob expand_aliases
	shopt -u nocaseglob nocasematch
	PLATFORM_SHELL="bash"
	whence() { type "$@"; }
fi

if IsZsh; then
	setopt EXTENDED_GLOB KSH_GLOB NO_NO_MATCH
	PLATFORM_SHELL="zsh"
fi

if [[ ! $BIN ]]; then
	BASHRC="${BASH_SOURCE[0]%/*}/bash.bashrc"
	[[ -f "$BASHRC" ]] && . "$BASHRC"
fi

# arguments - get argument from standard input if not specified on command line
# - must be an alias to set arguments
# - GetArgsN will read the first argument from standard input if there are not at least N arguments present
# - aliases must be defiend before used in a function
alias GetArgDash='[[ "$1" == "-" ]] && shift && set -- "$(cat)" "$@"' 
alias GetArgs='[[ $# == 0 ]] && set -- "$(cat)"' 
alias GetArgs2='(( $# < 2 )) && set -- "$(cat)" "$@"'
alias GetArgs3='(( $# < 3 )) && set -- "$(cat)" "$@"'

#
# Other
#

EvalVar() { r "${!1}" $2; } # EvalVar <var> <variable> - return the contents of the variable in variable, or set it to var
IsUrl() { [[ "$1" =~ ^(file|http[s]?|ms-windows-store)://.* ]]; }
IsInteractive() { [[ "$-" == *i* ]]; }
r() { [[ $# == 1 ]] && echo "$1" || eval "$2=""\"${1//\"/\\\"}\""; } # result VALUE VAR - echo value or set var to value (faster), r "- '''\"\"\"-" a; echo $a

urlencode()
{
	GetArgs
	echo "$1" | sed '
		s / %2f g
		s : %3a g
		s \$ %24 g
		s/ /%20/g 
  '
}

# update - manage update state in a temporary file location
UpdateInit() { updateDir="${1:-$DATA/update}"; [[ -d "$updateDir" ]] && return; ${G}mkdir --parents "$updateDir"; }
UpdateCheck() { [[ $updateDir ]] && return; UpdateInit; }
UpdateNeeded() { UpdateCheck || return; [[ $force || ! -f "$updateDir/$1" || "$(GetDateStamp)" != "$(GetFileDateStamp "$updateDir/$1")" ]]; }
UpdateDone() { UpdateCheck && touch "$updateDir/$1"; }
UpdateGet() { UpdateCheck && [[ ! -f "$updateDir/$1" ]] && return; cat "$updateDir/$1"; }
UpdateSet() { UpdateCheck && printf "$2" > "$updateDir/$1"; }

# clipboard

clipok()
{ 
	case "$PLATFORM" in 
		linux) [[ "$DISPLAY" ]] && InPath xclip;;
		mac) InPath pbcopy;; 
		win) InPath clip.exe paste.exe;;
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

clipw() 
{ 
	! clipok && return 1;

	case "$PLATFORM" in 
		linux) printf "%s" "$@" | xclip -sel clip;;
		mac) printf "%s" "$@" | pbcopy;; 
		win) ( cd /; printf "%s" "$@" | clip.exe );; # cd / to fix WSL 2 error running from network share
	esac
}

# languages

# pipxg - pipx global, run pipx for all users
pipxg()
{
	if IsPlatform debian,mac,qnap; then
		local dir
		if IsPlatform debian; then dir="/root/.local/bin/"
		elif IsPlatform qnap; then dir="/share/homes/admin/.local/bin/"
		fi
		sudo PIPX_HOME="$ADATA/pipx" PIPX_BIN_DIR="/usr/local/bin" "${dir}pipx" "$@"
	elif [[ "$1" == "install" ]]; then
		sudo python3 -m pip "$@"
	fi
}

# logging
InitColor() { GREEN=$(printf '\033[32m'); RB_BLUE=$(printf '\033[38;5;021m') RB_INDIGO=$(printf '\033[38;5;093m') RED=$(printf '\033[31m') RESET=$(printf '\033[m'); }
header() { InitColor; printf "${RB_BLUE}*************** ${RB_INDIGO}$1${RB_BLUE} ***************${RESET}\n"; headerDone="$((32 + ${#1}))"; }
HeaderBig() { InitColor; printf "${RB_BLUE}**************************************************\n* ${RB_INDIGO}$1${RB_BLUE}\n**************************************************${RESET}\n"; }
HeaderDone() { InitColor; printf "${RB_BLUE}$(StringRepeat '*' $headerDone)${RB_BLUE}\n"; }
hilight() { InitColor; EchoWrap "${GREEN}$1${RESET}"; }
CronLog() { local severity="${2:-info}"; logger -p "cron.$severity" "$1"; }

if IsBash && IsInteractive; then
	CurrentColumn() # https://stackoverflow.com/questions/2575037/how-to-get-the-cursor-position-in-bash/2575525#2575525
	{
		exec < /dev/tty
		oldstty=$(stty -g)
		stty raw -echo min 0
		echo -en "\033[6n" > /dev/tty
		IFS=';' read -r -d R -a pos
		stty $oldstty
		echo $((${pos[1]} - 1))
	}
else
	CurrentColumn() { echo "0"; }
fi

#
# Account
#

ActualUser() { echo "${SUDO_USER-$USER}"; }
UserExists() { getent passwd "$1" >& /dev/null; }
GroupAdd() { local group="$1"; GroupExists "$group" && return; sudoc groupadd "$group"; }
GroupAddUser() { local group="$1" user="${2:-$USER}"; GroupAdd "$group" || return; UserInGroup "$user" "$group" && return; sudo adduser "$user" "$group"; }
GroupDelete() { local group="$1"; ! GroupExists "$group" && return; sudoc groupdel "$group"; }
GroupExists() { getent group "$1" >& /dev/null; }
GroupList() { getent group; }
UserInGroup() { id "$1" | grep -q "($2)"; } # UserInGroup USER GROUP

UserCreate()
{
	local user="$1"; [[ ! $user ]] && { MissingOperand "user" "UserCreate"; return 1; }
	local password="$2"; [[ ! $password ]] && { password="$(pwgen 14 1)" || return; }

	# create user
	if ! UserExists "$1"; then
		sudoc adduser $user --disabled-password --gecos "" || return
		echo "$user:$password" | sudoc chpasswd || return
		echo "User password is $password"
	fi

	# make root
	! UserInGroup "$user" "sudo" && ask "Make user root" && { sudo usermod -aG sudo $user || return; }

	# create private key
	[[ ! -d ~$user/.ssh ]] && { sudo install -o "$user" -g "$user" -m 700 -d ~$user/.ssh || exit || return; }
	if ! sudo ls ~$user/.ssh/id_ed25519 >& /dev/null && ask "Create private key"; then
		sudo ssh-keygen -t ed25519 -C "$user" -f ~$user/.ssh/id_ed25519 -P "$password" || return
		sudo chown $user ~$user/.ssh/id_ed25519 ~$user/.ssh/id_ed25519.pub || return
		sudo chgrp $user ~$user/.ssh/id_ed25519 ~$user/.ssh/id_ed25519.pub || return
		echo "Private key passphrase is password is $password"
	fi

	return 0	
}

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

AddLoginShell()
{
	local shell="$1" shells="/etc/shells";  IsPlatform entware && shells="/opt/etc/shells"
	[[ ! -f "$shell" ]] && { EchoErr "AddLoginShell: $shell is not a valid shell"; return 1; }
	grep "$shell" "$shells" >& /dev/null && return
	echo "$shell" | sudo tee -a "$shells" || return
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
	local shell shells="/etc/shells";  IsPlatform entware && shells="/opt/etc/shells"

	[[ ! $1 ]] && { MissingOperand "shell" "FindLoginShell"; return 1; }

	if [[ -f "$shells" ]]; then
		shell="$(grep "/$1" "$shells" | tail -1)" # assume the last shell is the newest
	else
		shell="$(which "$1")" # no valid shell file, assume it is valid and search for it in the path
	fi

	[[ ! -f "$shell" ]] && { EchoErr "FindLoginShell: $1 is not a valid default shell"; return 1; }
	echo "$shell"
}

#
# Applications
#

browser()
{
	echo "Opening $@..."
	if InPath sensible-browser; then sensible-browser "$@"
	elif firefox IsInstalled; then firefox "$@"
	elif InPath w3m; then w3m "$@"
	elif InPath lynx; then lynx "$@"
	elif InPath elinks; then elinks "$@"
	elif InPath links; then links "$@"
	else EchoErr "no browser found"; return 1
	fi
}

# HashiConfig [prod|reset|test]
HashiConfig() { ScriptEval hashi config environment --suppress-errors "$@"; }
HashiConfigConsul() { [[ $CONSUL_HTTP_ADDR ]] || HashiConfig "$@"; }
HashiConfigNomad() { [[ $NOMAD_ADDR ]] || HashiConfig "$@"; }
HashiConfigVault() { [[ $VAULT_ADDR ]] || HashiConfig "$@"; }

# HashiServiceRegister SERVICE HOST_NUMS - register consul service SERVICE<n> for all specified hosts, i.e. HashiServiceRegister web 1,2
HashiServiceRegister()
{
	local service="$1" hostNum hostNums; StringToArray "$2" "," hostNums; shift 2

	HashiConfig || return
	for hostNum in "${hostNums[@]}"; do
		hashi consul service register "$CLOUD/network/system/hashi/services/$service$hostNum.hcl" --host="$hostNum" "$@" 
	done
}

# i: invoke the installer script (inst) saving the INSTALL_DIR
i() 
{ 
	local check find force noRun select

	if [[ "$1" == "--help" ]]; then echot "\
usage: i [APP*|bak|cd|check|dir|info|select]
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
	[[ "$1" == @(check) ]] && { check="true"; }


	case "${1:-cd}" in
		bak) InstBak;;
		cd) InstFind && cd "$INSTALL_DIR";;
		check|select) InstFind;;
		dir) InstFind && echo "$INSTALL_DIR";;
		info) InstFind && echo "The installation directory is $INSTALL_DIR";;
		*) inst --hint "$INSTALL_DIR" $noRun $force "$@";;
	esac
}

InstFind()
{
	[[ ! $force && ! $select && $INSTALL_DIR && -d "$INSTALL_DIR" ]] && return
	ScriptEval FindInstallFile --eval $select || return
	export INSTALL_DIR="$installDir"
	unset installDir file
}

powershell() 
{ 
	local files=( "$P/PowerShell/7/pwsh.exe" "$WINDIR/system32/WindowsPowerShell/v1.0/powershell.exe" )

	[[ "$1" == @(--version|-v) ]] && { powershell -Command '$PSVersionTable'; return; }
	
	for f in "${files[@]}"; do
		[[ -f "$f" ]] && { "$f" "$@"; return; }
	done

	FindInPath powershell.exe && { powershell.exe "$@"; return; }
	
	EchoErr "Could not find powershell"; return 1;
}

PowerShellVersion() { powershell --version | grep PSVersion | tr -s " " | cut -d" " -f2; }

store()
{
	IsPlatform win && { cmd.exe /c start ms-windows-store: >& /dev/null; }
	InPath gnome-software && { coproc gnome-software; }
	InPath snap-store && { coproc snap-store; }
	return 0
}

#
# Config
#

ConfigInit() { [[ ! $functionConfigFileCache ]] && export functionConfigFileCache="${1:-$BIN/bootstrap-config.sh}"; [[ -f "$functionConfigFileCache" ]] && return; EchoErr "ConfigInit: configuration file '$functionConfigFileCache' does not exist"; return 1; }
ConfigExists() { ConfigInit && (. "$functionConfigFileCache"; IsVar "$1"); }
ConfigGet() { ConfigInit && (. "$functionConfigFileCache"; eval echo "\$$1"); }
ConfigFileGet() { echo "$functionConfigFileCache"; }

#
# Console
#

clear() { echo -en $'\e[H\e[2J'; }
pause() { local response m="${@:-Press any key when ready...}"; ReadChars "" "" "$m"; }

LineWrap() { ! InPath setterm && return; setterm --linewrap "$1"; }

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

EchoErr() { (( $(CurrentColumn) != 0 )) && echo; EchoWrap "$@" >&2; }
HilightErr() { InitColor; EchoWrap "${RED}$1${RESET}" >&2; }
PrintErr() { printf "$@" >&2; }

EchoWrap()
{
	! InPath ${G}fold || ! IsInteger "$COLUMNS" || (( COLUMNS < 20 )) && { echo -e "$@"; return; }
	echo -e "$@" | expand -t $TABS | ${G}fold --space --width=$COLUMNS
}

EchoWrapErr() { EchoWrap "$@" >&2; }

# printf pipe: read input for printf from a pipe, ex: cat file | printfp -v var
printfp() { local stdin; read -d '' -u 0 stdin; printf "$@" "$stdin"; }

# change tab to $TABS spaces
[[ "$TABS" == "" ]] && TABS=2
catt() { cat $* | expand -t $TABS; } 							# CatTab
echot() { echo -e "$*" | expand -t $TABS; } 			# EchoTab
echote() { echo -e "$*" | expand -t $TABS >&2; } 	# EchoTabError
lesst() { less -x $TABS $*; } 										# LessTab

AddTab() { sed "s/^/$(StringRepeat " " 2)/"; } # AddTab - add $TABS spaces to the pipeline 

#
# Data Types
#

GetDef() { local gd="$(declare -p $1)"; gd="${gd#*\=}"; gd="${gd#\(}"; r "${gd%\)}" $2; } # get definition
IsVar() { declare -p "$1" >& /dev/null; }
IsAnyArray() { IsArray "$1" || IsAssociativeArray "$1"; }

if IsBash; then
	ArrayShift() { local -n arrayShiftVar="$1"; local arrayShiftNum="$2"; ArrayAnyCheck "$1" || return; set -- "${arrayShiftVar[@]}"; shift "$arrayShiftNum"; arrayShiftVar=( "$@" ); }
	ArrayShowKeys() { local var getKeys="!$1[@]"; eval local keys="( \${$getKeys} )"; ArrayShow keys; }
	GetType() { local gt="$(declare -p $1)"; gt="${gt#declare }"; r "${gt%% *}" $2; } # get type
	IsArray() { [[ "$(declare -p "$1" 2> /dev/null)" =~ ^declare\ \-a.* ]]; }
	IsAssociativeArray() { [[ "$(declare -p "$1" 2> /dev/null)" =~ ^declare\ \-A.* ]]; }
	StringToArray() { GetArgs3; IFS=$2 read -a $3 <<< "$1"; } # StringToArray STRING DELIMITER ARRAY_VAR
else
	ArrayShift() { local arrayShiftVar="$1"; local arrayShiftNum="$2"; ArrayAnyCheck "$1" || return; set -- "${${(P)arrayShiftVar}[@]}"; shift "$arrayShiftNum"; local arrayShiftArray=( "$@" ); ArrayCopy arrayShiftArray "$arrayShiftVar"; }
	ArrayShowKeys() { local var; eval 'local getKeys=( "${(k)'$1'[@]}" )'; ArrayShow getKeys; }
	GetType() { local gt="$(declare -p $1)"; gt="${gt#typeset }"; r "${gt%% *}" $2; } # get type
	IsArray() { [[ "$(eval 'echo ${(t)'$1'}')" == @(array|array-local) ]]; }
	IsAssociativeArray() { [[ "$(eval 'echo ${(t)'$1'}')" == "association" ]]; }
	StringToArray() { GetArgs3; IFS=$2 read -A $3 <<< "$1"; } # StringToArray STRING DELIMITER ARRAY_VAR
fi

# array
ArrayAnyCheck() { IsAnyArray "$1" && return; ScriptErr "'$1' is not an array"; return 1; }
ArrayReverse() { ArrayDelimit "$1" $'\n' | tac; }
ArraySize() { eval "echo \${#$1[@]}"; }

# AppendArray [-rd|--remove-dups|--remove-duplicates] DEST A1 A2 ... - combine specified arrays into first array
ArrayAppend()
{
	local removeDups; [[ "$1" == @(-rd|--remove-dups|--remove-duplicates) ]] && { removeDups="true"; shift; }
	local arrayAppendDest="$1"; shift
	
	ArrayAnyCheck "$arrayAppendDest" || return

	for arrayAppendName in "$@"; do		
		ArrayAnyCheck "$arrayAppendName" || return		
		(( $(ArraySize "$arrayAppendName") == 0 )) && continue
		eval "$arrayAppendDest+=( $(ArrayShow $arrayAppendName) )"
	done

	[[ ! $removeDups ]] && return
	eval "IFS=$'\n' $arrayAppendDest=( $(ArrayDelimit "$arrayAppendDest" $'\n' | sort | uniq) )"
}

# ArrayCopy SRC DEST
ArrayCopy()
{
	! IsAnyArray "$1" && { ScriptErr "'$1' is not an array"; return 1; }
	declare -g $(GetType $1) $2
	eval "$2=( $(GetDef $1) )"
}

# ArrayDelimit NAME [DELIMITER](,) - show array with a delimiter, i.e. ArrayDelimit a $'\n'
ArrayDelimit()
{
	local arrayDelimit=(); ArrayCopy "$1" arrayDelimit || return;
	local result delimiter="${2:-,}"
	printf -v result '%s'"$delimiter" "${arrayDelimit[@]}"
	printf "%s\n" "${result%$delimiter}" # remove delimiter from end
}

# ArrayDiff A1 A2 - return the items not in either array
ArrayIntersection()
{
	local arrayIntersection1=(); ArrayCopy "$1" arrayIntersection1 || return;
	local arrayIntersection2=(); ArrayCopy "$2" arrayIntersection2 || return;
	local result=() e

	for e in "${arrayIntersection1[@]}"; do ! IsInArray "$e" arrayIntersection2 && result+=( "$e" ); done
	for e in "${arrayIntersection2[@]}"; do ! IsInArray "$e" arrayIntersection1 && result+=( "$e" ); done

	ArrayDelimit result $'\n'
}

# ArrayIndex NAME VALUE - return the 1 based index of the value in the array
ArrayIndex() { ArrayDelimit "$1" '\n' | RemoveEnd '\n' | grep --line-number "^${2}$" | cut -d: -f1; }

# ArrayRemove ARRAY VALUES - remove items from the array except specified values.  If vaules is the name of a variable
# the contents of the variable are used.
ArrayRemove()
{
	local values="^$2$"; IsVar "$2" && values="$(ArrayShow $2 $'\n' '^' '$')"
	eval "$1=( $(ArrayDelimit $1 $'\n' | grep -v "$values") )"
}

# ArrayShow	NAME [DELIMITER]( ) [begin](") [end](") - show array elements quoted. 
#   If a delmiter is specified delimited the array is delmited by it, use $'\n' for newlines.
#   Each array element begins and end with the specified characters, i.e. $'\n' "^" "$" allows the array to be passed to grep
ArrayShow()
{
	IsAssociativeArray "$1" && { GetDef "$1"; return; }

	local arrayShow=(); ArrayCopy "$1" arrayShow || return;
	local result delimiter="${2:- }" begin="${3:-\"}" end="${4:-\"}"
	printf -v result "$begin%s$end$delimiter" "${arrayShow[@]}"
	printf "%s\n" "${result%$delimiter}" # remove delimiter from end
}

# IsInArray [-w|--wild] [-aw|--awild] STRING ARRAY_VAR
IsInArray() 
{ 
	local wild awild caseInsensitive
	local s isInArray=()

	while (( $# != 0 )); do
		case "$1" in "") : ;;
			-ci|--case-insensitive) caseInsensitive="true";;
			-a|--array-wild) awild="true";; 	# array contains glob patterns
			-w|--wild) wild="true";; 		# value contain glob patterns
			*)
				if ! IsOption "$1" && [[ ! $s ]]; then s="$1"
				elif ! IsOption "$1" && [[ ! $isInArray ]]; then ArrayCopy "$1" isInArray
				else UnknownOption "$1" "IsInArray"; return
				fi
		esac
		shift
	done

	[[ $caseInsensitive ]] && LowerCase "$s" s;

	for value in "${isInArray[@]}"; do
		[[ $caseInsensitive ]] && LowerCase "$value" value
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

# GetDateStampNext PREFIX SUFFIX
GetDateStampNext()
{
	local prefix="$1" suffix="$2" stamp="$(GetDateStamp)"
	[[ ! -d "$prefix" ]] && prefix+="."
	local f="$prefix$stamp.$suffix" i=1

	[[ ! -f "$f" ]] && { echo "$f"; return;}
	while [[ -f "$prefix$stamp-$i.$suffix" ]]; do (( ++i )); done
	echo "$prefix$stamp-$i.$suffix"
}

GetSeconds() # GetSeconds [<date string>](current time) - seconds from 1/1/1970 to specified time
{
	[[ "$1" == "-" ]] && set -- "$(cat)"
	[[ $1 ]] && { ${G}date +%s.%N -d "$1"; return; }
	[[ $# == 0 ]] && ${G}date +%s.%N; # only return default date if no argument is specified
}

# integer
IsInteger() { [[ "$1" =~ ^[0-9]+$ ]]; }
HexToDecimal() { echo "$((16#${1#0x}))"; }

# string
CharCount() { GetArgs2; local charCount="${1//[^$2]}"; echo "${#charCount}"; }
IsInList() { [[ $1 =~ (^| )$2($| ) ]]; }
IsWild() { [[ "$1" =~ (.*\*|\?.*) ]]; }
NewlineToSpace()  { tr '\n' ' '; }
StringRepeat() { printf "$1%.0s" $(eval "echo {1.."$(($2))"}"); } # StringRepeat S N - repeat the specified string N times

RemoveCarriageReturn()  { sed 's/\r//g'; }
RemoveNewline()  { tr -d '\n'; }
RemoveEmptyLines() { ${G}sed -r '/^\s*$/d'; }

RemoveChar() { GetArgs2; echo "${1//${2:- }/}"; }
RemoveEnd() { GetArgs2; echo "${1%%*(${2:- })}"; }
RemoveFront() { GetArgs2; echo "${1##*(${2:- })}"; }
RemoveTrim() { GetArgs2; echo "$1" | RemoveFront "${2:- }" | RemoveEnd "${2:- }"; }

RemoveAfter() { GetArgs2; echo "${1%%$2*}"; }
RemoveBefore() { GetArgs2; echo "${1##*$2}"; }

RemoveSpace() { GetArgs; RemoveChar "$1" " "; }
RemoveSpaceEnd() { GetArgs; RemoveEnd "$1" " "; }
RemoveSpaceFront() { GetArgs; RemoveFront "$1" " "; }
RemoveSpaceTrim() { GetArgs; RemoveTrim "$1" " "; }

QuoteBackslashes() { sed 's/\\/\\\\/g'; } # escape (quote) backslashes
QuotePath() { sed 's/\//\\\//g'; } # escape (quote) path (forward slashes - /) using a back slash (\)
QuoteSpaces() { GetArgs; echo "$@" | sed 's/ /\\ /g'; } # escape (quote) spaces using a back slash (\)
RemoveQuotes() { sed 's/"//g'; }

BackToForwardSlash() { GetArgs; echo "${@//\\//}"; }
ForwardToBackSlash() { GetArgs; echo "${@////\\}"; }
RemoveBackslash() { GetArgs; echo "${@//\\/}"; }

GetAfter() { GetArgs2; [[ "$1" =~ ^[^$2]*$2(.*)$ ]] && echo "${BASH_REMATCH[1]}"; } # GetAfter STRING CHAR - get all text in STRING after the first CHAR

GetWordUsage() { (( $# == 2 || $# == 3 )) && IsInteger "$2" && return 0; EchoErr "usage: GetWord STRING|- WORD [DELIMITER]( ) - 1 based"; return 1; }

if IsZsh; then
	LowerCase() { GetArgs; r "${1:l}" $2; }
	ProperCase() { GetArgs; r "${(C)1}" $2; }
	UpperCase() { echo "${(U)1}"; }
	UpperCaseFirst() { echo "${(U)1:0:1}${1:1}"; }

	GetWord()
	{
		GetArgDash; GetWordUsage "$@" || return
		local gwa gw="$1" word="$2" delimiter="${3:- }"; gwa=( "${(@ps/$delimiter/)gw}" ); printf "${gwa[$word]}"
	}

else
	LowerCase() { GetArgs; r "${1,,}" $2; }
	ProperCase() { GetArgs; local arg="${1,,}"; r "${arg^}" $2; }
	UpperCase() { echo "${1^^}"; }
	UpperCaseFirst() { echo "${1^}"; }

	GetWord() 
	{ 
		GetArgDash; GetWordUsage "$@" || return; 
		local word=$(( $2 + 1 )); IFS=${3:- }; set -- $1; 
		((word-=1)); (( word < 1 || word > $# )) && printf "" || printf "${!word}"
	}

fi

# time
ShowTime() { ${G}date '+%F %T.%N %Z' -d "$1"; }
ShowSimpleTime() { ${G}date '+%D %T' -d "$1"; }
TimerOn() { startTime="$(${G}date -u '+%F %T.%N %Z')"; }
TimestampDiff () { ${G}printf '%s' $(( $(${G}date -u +%s) - $(${G}date -u -d"$1" +%s))); }
TimerOff() { s=$(TimestampDiff "$startTime"); printf "%02d:%02d:%02d\n" $(( $s/60/60 )) $(( ($s/60)%60 )) $(( $s%60 )); }

# TimeCommand - return the time it takes to execute a command in milliseconds to three decimal places
# Command output is supressed.  The status of the command is returned.
if IsBash; then
	TimeCommand() { { time command "$@"; } |& tail -3 | head -1 | cut -d$'\t' -f2 | sed 's/m/:/' | sed 's/s//' | awk -F: '{ print ($1 * 60) + $2 }'; return ${PIPESTATUS[0]}; }
else
	TimeCommand() { { time "$@"; } |& tail -1 | rev | cut -d" " -f2 | rev; return $pipestatus[1]; }
fi

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
FileExists() { local f; for f in "$@"; do [[ ! -f "$f" ]] && return 1; done; return 0; }
FileExistsAny() { local f; for f in "$@"; do [[ -f "$f" ]] && return 0; done; return 1; }
HasFilePath() { GetArgs; [[ $(GetFilePath "$1") ]]; }
IsDirEmpty() { GetArgs; [[ "$(find "$1" -maxdepth 0 -empty)" == "$1" ]]; }
InPath() { local f option; IsZsh && option="-p"; for f in "$@"; do ! which $option "$f" >& /dev/null && return 1; done; return 0; }
InPathAny() { local f option; IsZsh && option="-p"; for f in "$@"; do which $option "$f" >& /dev/null && return; done; return 1; }
IsFileSame() { [[ "$(GetFileSize "$1" B)" == "$(GetFileSize "$2" B)" ]] && diff "$1" "$2" >& /dev/null; }
IsWindowsLink() { [[ "$PLATFORM" != "win" ]] && return 1; lnWin -s "$1" >& /dev/null; }
RemoveTrailingSlash() { GetArgs; r "${1%%+(\/)}" $2; }

GetFiles() { find "${2:-.}" -maxdepth 1 -name "$1" -type f -print0; } # for while loop
ReadFile() { read -d $'\0' file; }

fpc() { local arg; [[ $# == 0 ]] && arg="$PWD" || arg="$(GetRealPath "$1")"; echo "$arg"; clipw "$arg"; } # full path to clipboard
pfpc() { local arg; [[ $# == 0 ]] && arg="$PWD" || arg="$(GetRealPath "$1")"; clipw "$(utw "$arg")"; } # full path to clipboard in platform specific format

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

# File<Life|Right|Intersect> FILE1 FILE2 - return the lines only in the left file, right file, or not in either file
FileIntersect() { awk '{NR==FNR?a[$0]++:a[$0]--} END{for(k in a)if(a[k])print k}' "$1" "$2"; }
FileLeft() { comm -23 <(sort "$1") <(sort "$2"); }
FileRight() { comm -13 <(sort "$1") <(sort "$2"); }

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
			[[ ! -d "$dir" ]] && { EchoErr "FileCommand: accessing '$dir': No such directory"; return 1; }
			"$command" -t "$dir" "${args[@]}";;
		*) EchoErr "FileCommand: unknown command $command"; return 1;;
	esac
}

FileToDesc() # short description for the file, mounted volumes are converted to UNC,i.e. //server/share.
{
	GetArgs
	local file="$1"; [[ ! $1 ]] && return

	# if the file is a UNC mounted share get the UNC format
	if [[ -e "$file" ]] && unc IsMounted "$file"; then
		file="$(unc get unc "$file")"
	fi

	# remove the server DNS suffix from UNC paths
	IsUncPath "$file" && file="//$(GetUncServer "$file" | RemoveDnsSuffix)/$(GetUncShare "$file")/$(GetUncDirs "$file")"

	# replace $HOME with ~, $USERS/ with ~
	if IsBash; then
		file="${file/#${HOME}/\~}"
		file="${file/#$USERS\//\~}"
	else
		file="${file/#${HOME}/~}"
		file="${file/#$USERS\//~}"
	fi

	[[ "$file" != "/" ]] && file="$(RemoveTrailingSlash "$file")"

	echo "$file"
}

FindInPath()
{
	local file="$1" 

	[[ -f "$file" ]] && { echo "$(GetFullPath "$file")"; return; }

	if IsZsh; then
		whence -p "${file}" && return
		IsPlatform wsl && { whence -p "${file}.exe" && return; }
	else
		type -P "${file}" && return
		IsPlatform wsl && { type -P "${file}.exe" && return; }
	fi

	return 1
}

# GetRealPath - resolve symbolic links in path, the full path need not exist
GetRealPath()
{
	# use -m so directory existence is not checked (which can error out for mounted network volumes)
	InPath ${G}realpath && { ${G}realpath -m "$1"; return; }

	# readlink returns nothing if the path does not exist, 
	# so don't resolve symbolic links in this case
	[[ ! -e "$1" ]] && { echo "$1"; return; }
	
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

rsync()
{
	IsPlatform mac && { "$HOMEBREW_PREFIX/bin/rsync" "$@"; return; }
	command rsync "$@"
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
		local unc; unc="$(unc get unc "$file" --quiet)" && { ptw "$unc"; return; }
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
# File - Compression
#

UnzipStdin() { unzip -q -c "$1"; }
ZipStdin() { cat | zip "$1" -; } 		# echo "Test Text" | ZipStdin "test.txt"

# UnzipPlatform - use platform specific unzip to fix unzip errors syncing metadata on Windows drives
UnzipPlatform()
{
	local sudo zip dest

	# arguments
	while (( $# != 0 )); do
		case "$1" in "") : ;;
			-s|--sudo) sudo="sudoc";;
			*)
				! IsOption "$1" && [[ ! $zip ]] && { zip="$1"; shift; continue; }
				! IsOption "$1" && [[ ! $dest ]] && { dest="$1"; shift; continue; }
				UnknownOption "$1" "UnzipPlatform"; return
		esac
		shift
	done
	[[ ! "$zip" ]] && { MissingOperand "zip" "UnzipPlatform"; return 1; }
	[[ ! "$dest" ]] && { MissingOperand "dest" "UnzipPlatform"; return 1; }

	# unzip
	if IsPlatform win; then
		7z.exe x "$(utw "$zip")" -o"$(utw "$dest")" -y -bb3 || return
	else
		$sudo unzip -o "$zip" -d "$dest" || return
	fi

	return 0
}

#
# Monitoring
#

# LogShow FILE [PATTERN]
LogShow()
{ 
	local sudo file="$1" pattern="$2"; [[ $pattern ]] && pattern=" $pattern"

	LineWrap "off"
	SudoCheck "$1"; $sudo tail -f "$1" | grep "$pattern"
	LineWrap "on"
}

#
# Network
#

GetDefaultGateway() { CacheDefaultGateway && echo "$NETWORK_DEFAULT_GATEWAY"; }	# GetDefaultGateway - default gateway
GetMacAddress() { grep -i " ${1:-$HOSTNAME}$" "/etc/ethers" | cut -d" " -f1; }			# GetMacAddress - MAC address of the primary network interface
GetHostname() { SshHelper connect "$1" -- hostname; } 													# GetHostname NAME - hosts configured name
HostUnknown() { ScriptErr "$1: Name or service not known" "$2"; }
HostUnresolved() { ScriptErr "Could not resolve hostname $1: Name or service not known" "$2"; }
IsHostnameVm() { [[ "$(GetWord "$1" 1 "-")" == "$(os name)" ]]; } 							# IsHostnameVm NAME - true if name follows the virtual machine syntax HOSTNAME-name
IsInDomain() { [[ $USERDOMAIN && "$USERDOMAIN" != "$HOSTNAME" ]]; }							# IsInDomain - true if the computer is in a network domain
RemovePort() { GetArgs; echo "$1" | cut -d: -f 1; }															# RemovePort NAME:PORT - returns NAME
UrlExists() { curl --output /dev/null --silent --head --fail "$1"; }						# UrlExists URL - true if the specified URL exists

CacheDefaultGateway()
{
	[[ $NETWORK_DEFAULT_GATEWAY ]] && return

	if IsPlatform win; then
		local g="$(route.exe -4 print | RemoveCarriageReturn | grep ' 0.0.0.0 ' | head -1 | awk '{ print $3; }')" || return
	elif IsPlatform mac; then
		local g="$(netstat -rnl | grep '^default' | head -1 | awk '{ print $3; }')" || return
	else
		local g="$(route -n | grep '^0.0.0.0' | head -1 | awk '{ print $2; }')" || return
	fi

	export NETWORK_DEFAULT_GATEWAY="$g"
}

# DhcpRenew ADDRESS(primary) - renew the IP address of the specified adapter
DhcpRenew()
{
	local adapter="$1";  [[ ! $adapter ]] && adapter="$(GetPrimaryAdapterName)"
	local oldIp="$(GetAdapterIpAddress "$adapter")"

	if IsPlatform win; then
		ipconfig.exe /release "$adapter" || return
		ipconfig.exe /renew "$adapter" || return
		echo

	elif IsPlatform debian && InPath dhclient; then
		sudoc dhclient -r || return
		sudoc dhclient || return
	fi

	echo "Adapter $adapter IP: $oldIp -> $(GetAdapterIpAddress "$adapter")" || return
}

# GetAdapterIpAddres [ADAPTER](primary) - get specified network adapter address
# -w|--wsl	get the IP address used by WSL (Windows only)
GetAdapterIpAddress() 
{
	local adapter wsl; 

	# options
	while (( $# != 0 )); do
		case "$1" in "") : ;;
			-w|--wsl) wsl="--wsl";;
			*)
				if ! IsOption "$1" && [[ ! $adapter ]]; then adapter="$1"
				else UnknownOption "$1" "GetAdapterIpAddress"; return
				fi
		esac
		shift
	done

	local isWin; IsPlatform win && [[ ! $wsl ]] && isWin="true"
	[[ ! $adapter && ! $isWin ]] && { adapter="$(GetInterface)" || return; }

	# get IP address for the specified adapter
	if [[ $isWin ]]; then

		if [[ ! $adapter ]]; then
			# - use default route (0.0.0.0 destination) with lowest metric
			# - Windows build 22000.376 adds "Default " route
			route.exe -4 print | RemoveCarriageReturn | grep ' 0.0.0.0 ' | grep -v "Default[ ]*$" | sort -k5 --numeric-sort | head -1 | awk '{ print $4; }'
		else
			ipconfig.exe | RemoveCarriageReturn | grep -E "Ethernet adapter $adapter:|Wireless LAN adapter $adapter:" -A 9 | grep "IPv4 Address" | head -1 | cut -d: -f2 | RemoveSpace
		fi

	elif InPath ifdata; then
		ifdata -pa "$adapter"

	elif IsPlatform entware; then
		ifconfig "$adapter" | grep inet | grep -v 'inet6|127.0.0.1' | head -n 1 | awk '{ print $2 }' | cut -d: -f2

	else
		ifconfig "$adapter" | grep inet | grep -v 'inet6|127.0.0.1' | head -n 1 | awk '{ print $2 }'

	fi
}

# GetBroadcastAddress - get the broadcast address for the first network adapter
GetBroadcastAddress()
{
	if InPath ifdata; then
		ifdata -pb "$(GetInterface)"
	elif IsPlatform mac; then
		ifconfig "$(GetInterface)" | grep broadcast | head -1 |  awk '{ print $6; }'
	else
		ifconfig "$(GetInterface)" | head -2 | tail -1 | awk '{ print $6; }'
	fi
}

GetEthernetAdapters()
{
	if IsPlatform win; then
		ipconfig.exe /all | grep -e "^Ethernet adapter" | cut -d" " -f3- | cut -d: -f1	
	elif IsPlatform mac; then 
		netstat -rn | grep '^default' | awk '{ print $4; }' | grep -v '^utun' # utunN - IPv6 adapters
	else
		ip -4 -oneline -br address | cut -d" " -f 1
	fi
}

# GetInterface - name of the primary network interface
GetInterface()
{
	if IsPlatform mac; then netstat -rn | grep '^default' | head -1 | awk '{ print $4; }'
	else route | grep "^default" | head -1 | tr -s " " | cut -d" " -f8
	fi
}

# GetIpAddress [HOST] - get the IP address of the current or specified host
# -a|--all 						resolve all hosts not just the first
# -ra|--resolve-all 	resolve host using all methods (DNS, MDNS, and local virtual machine names)
# -m|--mdns						resolve host using MDNS
# -v|--vm 						resolve host using local virtual machine names (check $HOSTNAME-HOST)
# -w|--wsl						get the IP address used by WSL (Windows only)
# test cases: 10.10.100.10 web.service pi1 pi1.butare.net pi1.hagerman.butare.net
GetIpAddress() 
{
	local host mdns quiet vm wsl all=(head -1); 

	while (( $# != 0 )); do
		case "$1" in "") : ;;
			-a|--all) all=(cat);;
			-ra|--resolve-all) mdsn="true" vm="true";;
			-m|--mdns) mdns="true";;
			-q|--quiet) quiet="true";;
			-v|--vm) vm="true";;
			-w|--wsl) wsl="--wsl";;
			*)
				if ! IsOption "$1" && [[ ! $host ]]; then host="$(GetSshHost "$1")"
				else UnknownOption "$1" "GetIpAddress"; return 1
				fi
		esac
		shift
	done

	IsIpAddress "$host" && { echo "$host"; return; }
	IsLocalHost "$host" && { GetAdapterIpAddress $wsl; return; }

	# Resolve mDNS (.local) names exclicitly as the name resolution commands below can fail on some hosts
	# In Windows WSL the methods below never resolve mDNS addresses
	IsMdnsName "$host" && { ip="$(MdnsResolve "$host" 2> /dev/null)"; [[ $ip ]] && echo "$ip"; return; }

	# lookup IP address using various commands
	# - -N 3 and -ndots=2 allow the default domain names for partial names like consul.service
	# - getent on Windows sometimes holds on to a previously allocated IP address.   This was seen with old IP address in a Hyper-V guest on test VLAN after removing VLAN ID) - host and nslookup return new IP.
	# - host and getent are fast and can sometimes resolve .local (mDNS) addresses 
	# - host is slow on wsl 2 when resolv.conf points to the Hyper-V DNS server for unknown names
	# - nslookup is slow on macOS if a name server is not specified
	if InPath getent; then ip="$(getent ahostsv4 "$host" |& grep "STREAM" | "${all[@]}" | cut -d" " -f 1)"
	elif InPath host; then ip="$(host -N 2 -t A -4 "$host" |& ${G}grep -v "^ns." | grep "has address" | "${all[@]}" | cut -d" " -f 4)"
	elif InPath nslookup; then ip="$(nslookup -ndots=2 -type=A "$host" |& tail +4 | grep "^Address:" | "${all[@]}" | cut -d" " -f 2)"
	fi

	# if an IP address was not found, check for a local virtual hostname
	[[ ! $ip && $vm ]] && ip="$(GetIpAddress --quiet "$HOSTNAME-$host")"

	# resolve using .local only if --all is specified to avoid delays
	[[ ! $ip && $mdns ]] && ip="$(MdnsResolve "${host}.local" 2> /dev/null)"

	# return
	[[ ! $ip ]] && { [[ ! $quiet ]] && HostUnresolved "$host"; return 1; }
	echo "$(echo "$ip" | RemoveCarriageReturn)"
}

# GetPrimaryAdapterName - get the descriptive name of the primary network adapter used for communication
GetPrimaryAdapterName()
{
	if IsPlatform win; then
		ipconfig.exe | grep $(GetAdapterIpAddress) -B 8 | grep "Ethernet adapter" | awk -F adapter '{ print $2 }' | sed 's/://' | sed 's/ //' | RemoveCarriageReturn
	else
		GetInterface
	fi
}

GetServer()
{
	local server="$1"; shift; [[ ! $server ]] && { MissingOperand "server" "GetServer"; return 1; }
	local ip; ip="$(GetIpAddress "$server.service" "$@")" || return
	DnsResolve "$ip" "$@"
}

GetServers() { GetIpAddress --all "$1.service" | xargs -n 1 RunScript DnsResolve; }

# ipconfig [COMMAND] - show or configure network
ipconfig() { IsPlatform win && { ipconfig.exe "$@"; } || ip -4 -oneline -br address; }

# ipinfo - show network configuration
ipinfo()
{
	! IsPlatform win && { ip -4 -br address; return; }
	
	{
		local adapter adapters

		PrintErr "searching..."

		hilight "Name:IP"
		{
			IFS=$'\n' adapters=( $(GetEthernetAdapters) )
			for adapter in "${adapters[@]}"; do
				local ip="$(GetAdapterIpAddress "$adapter")"
				echo $adapter:$ip
				PrintErr "."
			done
		} | sort

		EchoErr "done"
	} | column -c $(tput cols) -t -s: -n

}

# IsIpAddress IP - return true if the specified IP is an IP address
IsIpAddress()
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

# IsIpLocal - return true if the specified IP is reachable on the local network (does not use the default gateway in 5 hops or less)
IsIpLocal() { GetArgs; CacheDefaultGateway || return; ! traceroute "$1" -4 --max-hops=5 | grep --quiet "($(GetDefaultGateway))"; } 

# IsLocalHost HOST - true if the specified host refers to the local host
IsLocalHost() { local host="$(RemoveSpace "$1")"; [[ "$host" == "" || "$host" == "localhost" || "$host" == "127.0.0.1" || "$(RemoveDnsSuffix "$host")" == "$(RemoveDnsSuffix $(hostname))" ]]; }

# IsLocalHostIp HOST - true if the specified host refers to the local host.  Also check the IP address of the host.
IsLocalHostIp() { IsLocalHost "$1" || [[ "$(GetIpAddress "$1" --quiet)" == "$(GetIpAddress)" ]] ; }

#
# Network: Host Availability
#

# IsAvailable HOST [TIMEOUT_MILLISECONDS] - returns true if the host is available
IsAvailable() 
{ 
	local host="$1" timeout="${2:-$(ConfigGet "hostTimeout")}"

	IsLocalHost "$host" && return 0

	# resolve the IP address explicitly:
	# - mDNS name resolution is intermitant (double check this on various platforms)
	# - Windows ping.exe name resolution is slow for non-existent hosts
	local ip; ip="$(GetIpAddress --quiet "$host")" || return
	
	if IsPlatform wsl1; then # WSL 1 ping and fping do not timeout quickly for unresponsive hosts so use ping.exe
		ping.exe -n 1 -w "$timeout" "$ip" |& grep "bytes=" &> /dev/null 
	elif InPath fping; then
		fping -r 1 -t "$timeout" -e "$ip" &> /dev/null
	else
		ping -c 1 -W 1 "$ip" &> /dev/null # -W timeoutSeconds
	fi
}

# IsPortAvailable HOST PORT [TIMEOUT_MILLISECONDS] - return true if the host is available on the specified TCP port
IsAvailablePort()
{
	local host="$1" port="$2" timeout="${3-$(ConfigGet "hostTimeout")}"; host="$(GetIpAddress "$host" --quiet)" || return

	if InPath ncat; then
		ncat --exec "BOGUS" --wait ${timeout}ms "$host" "$port" >& /dev/null
	elif InPath nmap; then
		nmap "$host" -p "$port" -Pn -T5 |& grep -q "open" >& /dev/null
	elif IsPlatform win; then	
		chkport-ip.exe "$host" "$port" "$timeout" >& /dev/null
	else
		return 0 
	fi
}

# IsPortAvailableUdp HOST PORT [TIMEOUT_MILLISECONDS] - return true if the host is available on the specified UDP port
IsAvailablePortUdp()
{
	local host="$1" port="$2" timeout="${3-$(ConfigGet "hostTimeout")}"; host="$(GetIpAddress "$host" --quiet)" || return

	if InPath nmap; then
		sudoc nmap "$host" -p "$port" -Pn -T5 -sU |& grep -q "open" >& /dev/null
	else
		return 0 
	fi
}

# PingResponse HOST [TIMEOUT_MILLISECONDS] - returns ping response time in milliseconds
PingResponse() 
{ 
	local host="$1" timeout="${2-$(ConfigGet "hostTimeout")}"; host="$(GetIpAddress "$host")" || return

	if InPath fping; then
		fping -r 1 -t "$timeout" -e "$host" |& grep " is alive " | cut -d" " -f 4 | tr -d '('
		return ${PIPESTATUS[0]}
	else
		ping -c 1 -W 1 "$host" |& grep "time=" | cut -d" " -f 7 | tr -d 'time=' # -W timeoutSeconds
		return ${PIPESTATUS[0]}
	fi

}

# PortResponse HOST PORT [TIMEOUT_MILLISECONDS] - return host port response time in milliseconds
PortResponse() 
{
	local host="$1" local port="$2" timeout="${3-$(ConfigGet "hostTimeout")}"; host="$(GetIpAddress "$host")" || return

	if InPath ncat; then
		TimeCommand ncat --exec "BOGUS" --wait ${timeout}ms "$host" "$port"
	elif InPath nmap; then
		local line="$(nmap "$host" -p "$port" -Pn -T5)"
		echo "$line" | grep -q "open" || return
		line="$(echo "$line" | grep "Host is up")"; (( ${PIPESTATUS[0]} != 0 )) && return # "Host is up (0.049s latency)."
		line="${line##*\(}" # remove "Host is up ("
		line="${line%%s*}" 	# remove "s latency"
		printf "%.*f\n" 3 "$(echo "$line * 1000" | bc)" # seconds to milliseconds, round to 3 decimal places
	else
		echo "0"; return 0 
	fi
}

WaitForAvailable() # WaitForAvailable HOST [TIMEOUT_MILLISECONDS] [WAIT_SECONDS]
{
	local host="$1"; [[ ! $host ]] && { MissingOperand "host" "WaitForAvailable"; return 1; }
	local timeout="${2-$(ConfigGet "hostTimeout")}" seconds="${3-$(ConfigGet "hostTimeout")}"

	printf "Waiting for $host..."
	for (( i=1; i<=$seconds; ++i )); do
 		ReadChars 1 1 && { echo "cancelled after $i seconds"; return 1; }
		printf "."
		IsAvailable "$host" "$timeout" && { echo "found"; return; }
	done

	echo "not found"; return 1
}

WaitForPort() # WaitForPort HOST PORT [TIMEOUT_MILLISECONDS] [WAIT_SECONDS]
{
	local host="$1"; [[ ! $host ]] && { MissingOperand "host" "WaitForPort"; return 1; }
	local port="$2"; [[ ! $port ]] && { MissingOperand "port" "WaitForPort"; return 1; }
	local timeout="${3-$(ConfigGet "hostTimeout")}" seconds="${4-$(ConfigGet "hostTimeout")}"
	
	IsAvailablePort "$host" "$port" "$timeout" && return

	printf "Waiting for $host port $port..."
	for (( i=1; i<=$seconds; ++i )); do
 		ReadChars 1 1 && { echo "cancelled after $i seconds"; return 1; }
		printf "."
		IsAvailablePort "$host" "$port" "$timeout" && { echo "found"; return; }
	done

	echo "not found"; return 1
}

#
# Network: DNS Names
#

AddDnsSuffix() { HasDnsSuffix "$1" && echo "$1" || echo "$1.$2"; } 						# AddDnsSuffix HOST DOMAIN - add the specified domain to host if a domain is not already  present
GetDnsSuffix() { GetArgs; ! HasDnsSuffix "$1" && return; printf "${@#*.}"; }	# GetDnsSuffix HOST - the DNS suffix of the HOST
HasDnsSuffix() { GetArgs; local p="\."; [[ "$1" =~ $p ]]; }										# HasDnsSuffix HOST - true if the specified host includes a DNS suffix
RemoveDnsSuffix() { GetArgs; [[ ! $@ ]] && return; printf "${@%%.*}"; }				# RemoveDnsSuffix HOST - remove the DNS suffix if present

#
# Network: Name Resolution
#

# IsMdnsName NAME - return true if NAME is a local address (ends in .local)
IsMdnsName() { IsBash && [[ "$1" =~ .*'.'local$ ]] || [[ "$1" =~ .*\\.local$ ]]; }

ConsulResolve() { hashi resolve "$@"; }

# DnsResolve NAME|IP - resolve NAME or IP address to a fully qualified domain name
# test cases: 10.10.100.10 web.service pi1 pi1.butare.net pi1.hagerman.butare.net
DnsResolve()
{
	local name quiet

	while (( $# != 0 )); do
		case "$1" in "") : ;;
			-q|--quiet) quiet="true";;
			*)
				if ! IsOption "$1" && [[ ! $name ]]; then name="$1"
				else UnknownOption "$1" "DnsResolve"; return 1
				fi
		esac
		shift
	done

	[[ ! $name ]] && { MissingOperand "host" "DnsResolve"; return 1; } 

	# Resolve name using various commands
	# - -N 3 and -ndotes=3 allow the default domain names for partial names like consul.service

	# reverse DNS lookup for IP Address
	local lookup 
	if IsIpAddress "$name"; then

		if IsLocalHost "$name"; then
			lookup="localhost"
		elif InPath host; then
			lookup="$(host -t A -4 "$name" |& cut -d" " -f 5 | RemoveTrim ".")" || unset lookup
		else		
			lookup="$(nslookup -type=A $name |& grep "name =" | cut -d" " -f 3 | RemoveTrim ".")" || unset lookup
		fi

	# forward DNS lookup to get the fully qualified DNS address
	else

		if InPath getent; then lookup="$(getent ahostsv4 "$name" |& head -1 | tr -s " " | cut -d" " -f 3)" || unset lookup
		elif InPath host; then lookup="$(host -N 2 -t A -4 "$name" |& ${G}grep -v "^ns." | grep "has address" | head -1 | cut -d" " -f 1)" || unset lookup
		elif InPath nslookup; then lookup="$(nslookup -ndots=2 -type=A "$name" |& tail -3 | grep "Name:" | cut -d$'\t' -f 2)" || unset lookup
		fi
		
	fi

	[[ ! $lookup ]] && { [[ ! $quiet ]] && HostUnresolved "$name"; return 1; }
	[[ "$lookup" ]] && echo "$lookup" || return 1
}

MdnsResolve()
{
	local name="$1" result; [[ ! $name ]] && MissingOperand "host" "MdnsResolve"

	{ [[ ! $name ]] || ! IsMdnsName "$name"; } && return 1

	# Currently WSL does not resolve mDns .local address but Windows does
	if IsPlatform win; then
		result="$(dns-sd.exe -timeout 200 -Q "$name" |& grep "$name" | head -1 | rev | cut -d" " -f1 | rev)"
	elif IsPlatform mac; then
		result="$(ping -c 1 -W 200 "$name" |& grep "bytes from" | gcut -d" " -f 4 | sed s/://)"
	else
		result="$(avahi-resolve-address -4 -n "$name" | awk '{ print $2; }')"
	fi

	[[ ! $result ]] && { EchoErr "mDNS: Could not resolve hostname $host"; return 1; } 
	echo "$result"
}

MdnsNames() { avahi-browse -all -c -r | grep hostname | sort | uniq | cut -d"=" -f2 | RemoveSpace | sed 's/\[//' | sed 's/\]//'; }
MdnsServices() { avahi-browse --cache --all --no-db-lookup --parsable | cut -d';' -f5 | sort | uniq; }

#
# Network: SSH
#

GetSshUser() { echo "$1" | cut -s -d@ -f 1; } 							# GetSshUser USER@HOST:PORT -> USER
GetSshHost() { echo "$1" | cut -d@ -f 2 | RemovePort; }			# GetSshHost USER@HOST:PORT -> HOST
GetSshPort() { echo "$1" | cut -s -d: -f 2; }								# GetSshPort USER@HOST:PORT -> PORT

IsSsh() { [[ "$SSH_TTY" || "$XPRA_SERVER_SOCKET" ]]; }			# IsSsh - return true if connected over SSH
IsXpra() { [[ "$XPRA_SERVER_SOCKET" ]]; }										# IsXpra - return true if connected using XPRA
RemoteServer() { echo "${SSH_CONNECTION%% *}"; }						# RemoveServer - return the IP addres of the remote server that the SSH session is connected from
RemoteServerName() { DnsResolve "$(RemoteServer)"; }				# RemoveServerName - return the DNS name remote server that the SSH session is connected from

# IsInSshConfig HOST - return true if HOST matches an entry in ~/.ssh/config
IsInSshConfig() 
{
	local hostFull="$1" host="$(GetSshHost "$1")" defaultFull default="DEFAULT_CONFIG"
	defaultFull="${hostFull/$host/$default}"

	# if the SSH configuration changes a value other than the host, return 0 (host in SSH config)
	[[ "$(ssh -G "$defaultFull" | grep -i -v "^hostname ${default}$")" != "$(ssh -G "$hostFull" | grep -i -v "^hostname ${host}$")" ]] && return 0

	 # if the host is unchanged return 1 (host not in SSH config)
	ssh -G "$hostFull" | grep -i "^hostname ${host}$" >& /dev/null && return 1

	# the host is changed, return 0 (host is in SSH config)
	return 0
}

# SshConfigDiff HOST - show the changes for the host in ~/.ssh/config
SshConfigDiff() 
{
	local hostFull="$1" host="$(GetSshHost "$1")" defaultFull default="DEFAULT_CONFIG"
	defaultFull="${hostFull/$host/$default}"

	ssh -G "$defaultFull" | grep -i -v "^hostname ${default}$" > "/tmp/default.txt"
	ssh -G "$hostFull" | grep -i -v "^hostname ${host}$" > "/tmp/$host.txt"

	merge "/tmp/default.txt" "/tmp/$host.txt"
}

# SshAgentConfig - if the SSH Agent is started, add the configuration variables to the shell
SshAgentConfig() { [[ ! -f "$HOME/.ssh/environment" ]] && return; . "$HOME/.ssh/environment"; }

# SshAgentStart - start the SSH Agent if needed and add the configuration variables to the shell
SshAgentStart()
{
	ssh-add -L >& /dev/null && return
	SshAgentConfig
	SshAgent start "$@" || return
	SshAgentConfig
}

SshInPath() { SshHelper connect "$1" -- which "$2" >/dev/null; } # HOST FILE
SshIsAvailable() { local port="$(SshHelper config "$1" port)"; IsAvailablePort "$1" "${port:-22}"; } # HOST

#
# Network: UNC Shares - //[USER@]SERVER/SHARE[/DIRS][:PROTOCOL]
#

CheckNetworkProtocol() { [[ "$1" == @(|nfs|smb|ssh) ]] || IsInteger "$1"; }
GetUncRoot() { GetArgs; r "//$(GetUncServer "$1")/$(GetUncShare "$1")" $2; }															# //SERVER/SHARE
GetUncServer() { GetArgs; local gus="${1#*( )//}"; gus="${gus#*@}"; r "${gus%%/*}" $2; }									# SERVER
GetUncShare() { GetArgs; local gus="${1#*( )//*/}"; gus="${gus%%/*}"; r "${gus%:*}" $2; }									# SHARE
GetUncDirs() { GetArgs; local gud="${1#*( )//*/*/}"; [[ "$gud" == "$1" ]] && gud=""; r "${gud%:*}" $2; } 	# DIRS
IsUncPath() { [[ "$1" =~ ^\ *//.* ]]; }

# GetFullUnc UNC: return the UNC with server fully qualified domain name
GetFullUnc()
{
	local user="$(GetUncUser "$1")"
	local server="$(GetUncServer "$1")"
	local share="$(GetUncShare "$1")"
	local dirs="$(GetUncDirs "$1")"
	local protocol="$(GetUncProtocol "$1")"

	server="$(DnsResolve "$server")" || return
	UncMake "$user" "$server" "$share" "$dirs" "$protocol"
}

GetUncUser()
{
	GetArgs; ! [[ "$1" =~ .*\@.* ]] && { r "" $2; return; }
	local guu="${1#*( )//}"; guu="${guu%%@*}"; r "$guu" $2
}

# GetUncProtocol UNC - PROTOCOL=NFS|SMB|SSH|INTEGER - INTEGER is a custom SSH port
GetUncProtocol()
{
	GetArgs; local gup="${1#*:}"; [[ "$gup" == "$1" ]] && gup=""; r "$gup" $2
	CheckNetworkProtocol "$gup" || { EchoErr "'$gup' is not a valid network protocol"; return 1; }
}

# UncMake user server share dirs protocol
UncMake()
{
	local user="$1" server="$2" share="$3" dirs="$4" protocol="$5"
	local result="//"
	[[ $user ]] && result+="$user@"
	result+="$server/$share"
	[[ $dirs ]] && result+="/$(RemoveTrim "$dirs" "/")"
	[[ $protocol ]] && result+=":$protocol"
	echo "$result"
}

#
# Network: URI - PROTOCOL://SERVER:PORT[/DIRS]
#

GetUriProtocol() { GetArgs; local gup="${1%%\:*}"; r "$(LowerCase "$gup")" $2; }
GetUriServer() { GetArgs; local gus="${1#*//}"; gus="${gus%%:*}"; r "${gus%%/*}" $2; }
GetUriPort() { GetArgs; local gup="${1##*:}"; r "${gup%%/*}" $2; }
GetUriDirs() { GetArgs; local gud="${1#*//*/}"; [[ "$gud" == "$1" ]] && gud=""; r "$gud" $2; }
IsHttps() { GetArgs; [[ "$(GetUriProtocol "$@")" == "https" ]]; }

GetUrlPort()
{
	local gup="$(GetUriPort "$1")"
	[[ $gup ]] && { r "$gup" $2; return; }
	case "$(GetUriProtocol "$1")" in
		http) gup="80";;
		https) gup="443";;
	esac
	r "$gup" $2
}

#
# Package Manager
#

HasPackageManger() { IsPlatform debian,entware,mac; }
PackageFileInfo() { dpkg -I "$1"; } # information about a DEB package
PackageFileInstall() { sudo gdebi -n "$@"; } # install a DEB package with dependencies
PackageFileVersion() { PackageFileInfo "$1" | RemoveSpace | grep Version | cut -d: -f2; }
PackagePurge() { InPath wajig && wajig purgeremoved; }
PackageSize() { InPath wajig && wajig sizes | grep "$1"; }

# package PACKAGE - install the specified package
package() # package install
{
	# arguments
	local arg args=() force noPrompt quiet packages
	for arg in "$@"; do
		[[ "$arg" == @(-f|--force) ]] && { force="true"; continue; }
		[[ "$arg" == @(-np|--no-prompt) ]] && { noPrompt="true"; continue; }
		[[ "$arg" == @(-q|--quiet) ]] && { quiet="true"; continue; }
		args+=( "$arg" )
	done
	set -- "${args[@]}"

	local packages=( "$@" ); packageExclude || return

	if [[ ! $packages ]]; then
		[[ ! $quiet ]] && echo "all packages have been excluded"
		return 0
	fi

	# return if all of the packages are installed
	if [[ ! $force ]] && PackageInstalled "${packages[@]}"; then
		[[ ! $quiet ]] && echo "All packages have been installed"
		return 0
	fi

	# disable prompting
	[[ $noPrompt ]] && IsPlatform debian && noPrompt="DEBIAN_FRONTEND=noninteractive"

	# install the packages
	IsPlatform debian && { sudoc $noPrompt apt install -y "${packages[@]}"; return; }
	IsPlatform entware && { sudoc opkg install "${packages[@]}"; return; }
	IsPlatform mac && { HOMEBREW_NO_AUTO_UPDATE=1 brew install "${packages[@]}"; return; }

	return 0
}

# packageExclude - remove excludes packages fromthe packages array
packageExclude()
{	
	# Ubuntu excludes - ncat is not present on older distributions
	IsPlatform ubuntu && IsInArray "ncat" packages && [[ "$(os CodeName)" =~ ^(bionic|xenial)$ ]] && ArrayRemove packages "ncat"

	# Ubuntu - libturbojpeg0 is libturbojpeg in Ubuntu
	IsPlatform ubuntu && IsInArray "libturbojpeg0" packages && { ArrayRemove packages "libturbojpeg0"; packages+=( libturbojpeg ); }

	# macOS excludes
	! IsPlatform mac && return

	local mac=( atop fortune-mod hdparm inotify-tools iotop iproute2 ksystemlog ncat ntpdate squidclient unison-gtk virt-what )	
	local macArm=( bat bonnie++ pv rust traceroute )
	local macx86=( ncat traceroute )

	local p
	for p in "${packages[@]}"; do
		IsPlatform mac && IsInArray "$p" mac && ArrayRemove packages "$p"
		IsPlatformAll mac,arm && IsInArray "$p" macArm && ArrayRemove packages "$p"
		IsPlatformAll mac,x86 && IsInArray "$p" macx86 && ArrayRemove packages "$p"
	done

	return 0
}


# pakcageu PACKAGE - remove the specified package exists
# - allow removal prompt to view dependant programs being uninstalled, i.e. uninstall of mysql-common will remove kea
packageu() # package uninstall
{ 
	if IsPlatform debian; then sudo apt remove "$@"
	elif IsPlatform entware; then sudo opkg remove "$@"
	elif IsPlatform mac; then brew remove "$@"
	fi
}

PackageCleanup()
{
	ask "Clean packages"	&& { sudoc apt-get clean -y || return; } # cleanup downloaded package files in /var/cache/apt/archives
	ask "Remove packages" && { sudoc apt autoremove -y || return; }
	ask "Purge packages" && { PackagePurge || return; }
	return 0
}

# PackageExist PACKAGE - return true if the specified package exists
PackageExist()
{ 
	if IsPlatform debian; then [[ "$(apt-cache search "^$@$")" ]]
	elif IsPlatform mac; then brew search "/^$@$/" | grep -v "No formula or cask found for" >& /dev/null
	elif IsPlatform entware; then [[ "$(packagel "$1")" ]]
	fi
}

# PackageFiles PACKAGE - show files in the specified package
PackageFiles()
{
	if InPath "apt-file"; then apt-file list "$@"
	elif IsPlatform entware; then opkg files "$@"
	fi
}

# PackageInfo PACKAGE - show information about the specified package
PackageInfo()
{
	if IsPlatform debian; then
		apt show "$1" || return
		! PackageInstalled "$1" && return
		dpkg -L "$1"; echo
		dpkg -L "$1" | grep 'bin/'

	elif IsPlatform entware; then
		opkg info "$@"
	
	elif IsPlatform mac; then
		brew info "$1" || return
		! PackageInstalled "$1" && return
		brew list "$1"; echo
		brew list "$1" | grep 'bin/'

	fi
}

# PackageInstalled PACKAGE [PACKAGE]... - return true if all packages are installed
PackageInstalled() 
{ 
	[[ "$@" == "" ]] && return 0

	if InPath dpkg; then
		# ensure the package counts match, i.e. dpkg --get-selectations samba will not return anything if samba-common is installed
		[[ "$(dpkg --get-selections "$@" |& grep -v "no packages found" | wc -l)" == "$#" ]] && ! dpkg --get-selections "$@" | grep -q "deinstall$"
	
	elif IsPlatform mac; then
		InPath "$@" && return # faster if all packages are in the path
		brew list "$@" >& /dev/null

	else
		InPath "$@" # assumes each package name is in the path
	fi
}

# PackageSearch PATTERN - search for a package
PackageSearch() 
{ 
	if IsPlatform debian; then apt-cache search  "$@"
	elif IsPlatform entware; then opkg find "*$@*"
	elif IsPlatform mac; then brew search "$@"
	fi
}

# PackageSearchDetail PATTERN - search for a package showing installed and uninstalled matches
PackageSearchDetail() 
{ 
	if IsPlatform debian && InPath wajig && InPath apt-file; then wajig whichpkg "$@"
	elif IsPlatform entware; then opkg whatprovides "$@"
	fi
}

PackageListInstalled()
{
	local full; [[ "$1" == @(--full|-f) ]] && { full="true"; shift; }
	if IsPlatform debian && InPath dpkg; then dpkg --get-selections "$@"
	elif IsPlatform mac && [[ $full ]]; then brew info --installed --json
	elif IsPlatform mac && [[ ! $full ]]; then brew info --installed --json | jq -r '.[].name'
	elif IsPlatform entware; then opkg list-installed
	fi
}

# PackageUpdate - update packages
PackageUpdate() 
{
	IsPlatform debian && { sudo apt update || return; sudo apt dist-upgrade -y; return; }
	IsPlatform mac && { brew update || return; brew upgrade; return; }
	IsPlatform qnap && { sudo opkg update || return; sudo opkg upgade; return; }
	return 0
}

# PackageWhich FILE - show which package an installed file is located in
PackageWhich() 
{
	local file="$1"
	[[ -f "$file" ]] && file="$(GetFullPath "$1")"
	[[ ! -f "$file" ]] && InPath "$file" && file="$(FindInPath "$file")"
	if IsPlatform debian; then dpkg -S "$file"
	elif IsPlatform entware; then	opkg search "$file"
	fi
}

#
# Platform
# 

PlatformSummary() { echo "$(os architecture) $(PlatformDescription) $(os bits)"; }
PlatformDescription() { echo "$PLATFORM $PLATFORM_LIKE $PLATFORM_ID"; }

# GetPlatformVar VAR - return PLATFORM_VAR variable if defined, otherewise return VAR
if IsBash; then GetPlatformVar() { local v="$1" pv="${PLATFORM^^}_$1"; [[ ${!pv} ]] && echo "${!pv}" || echo "${!v}"; }
else GetPlatformVar() { local v="$1" pv="${(U)PLATFORM}_$1"; [[ ${(P)pv} ]] && echo "${(P)pv}" || echo "${(P)v}"; }
fi

# IsPlatform platform[,platform,...] [--host [HOST]] - return true if the host has one of the specified characteristics
# - if --host is specified, check the specified host instead of localhost.   If the HOST argument is not specified,
#   use the host from the last call to HostGetInfo.
function IsPlatform()
{
	local platforms=() p; StringToArray "$1" "," platforms; shift
	
	# set _platform variables
	if [[ "$1" == @(-h|--host) ]]; then		
		shift
		[[ $1 ]] && { ScriptEval HostGetInfo "$1" || return; }
	else
		local _platform="$PLATFORM" _platformLike="$PLATFORM_LIKE" _platformId="$PLATFORM_ID" _platformKernel="$PLATFORM_KERNEL" _machine="$MACHINE" _wsl="$WSL"
	fi

	# check if the host matches the specified platforms
	for p in "${platforms[@]}"; do
		LowerCase "$p" p

		case "$p" in 

			# platform, platformLike, and platformId
			win|mac|linux) [[ "$p" == "$_platform" ]] && return;;
			win11) IsPlatform win && (( $(os build) >= 22000 )) && return;;
			wsl) [[ "$_platform" == "win" && "$_platformLike" == "debian" ]] && return;; # Windows Subsystem for Linux
			wsl1|wsl2) [[ "$p" == "wsl$_wsl" ]] && return;;
			debian|mingw|openwrt|qnap|synology|ubiquiti) [[ "$p" == "$_platformLike" ]] && return;;
			dsm|qts|srm|pi|rock|ubuntu) [[ "$p" == "$_platformId" ]] && return;;

			# hardware
			cm4) grep -q "Raspberry Pi Compute Module" "/proc/cpuinfo" && return;;

			# kernel
			winkernel) [[ "$_platformKernel" == @(wsl1|wsl2) ]] && return;;
			linuxkernel) [[ "$_platformKernel" == "linux" ]] && return;;
			pikernel) [[ "$_platformKernel" == "pi" ]] && return;;

			# operating system
			32|64) [[ "$p" == "$(os bits "$_machine" )" ]] && return;;

			# package management
			apt) InPath apt && return;;
			entware) IsPlatform qnap,synology && return;;
			ipkg) InPath ipkg && return;;
			opkg) InPath opkg && return;;

			# processor
			arm|mips|x86) [[ "$p" == "$(os architecture "$_machine" | LowerCase)" ]] && return;;

			# software
			busybox) InPath busybox && return;;

			# virtualization
			container) IsContainer && return;;
			docker) IsDocker && return;;
			swarm) InPath docker && docker info |& command grep "^ *Swarm: active$" >& /dev/null && return;; # -q does not work reliably on pi2
			chroot) IsChroot && return;;
			host|physical) ! IsChroot && ! IsContainer && ! IsVm && return;;
			guest|vm|virtual) IsVm && return;;

		esac

		[[ "$p" == "${platform}${platformId}" ]] && return 0 # i.e. LinuxUbuntu WinUbuntu
	done

	return 1
}

# IsBusyBox FILE - return true if the specified file is using BusyBox
IsBusyBox() { [[ "$(readlink -f "$(which nslookup)")" == "$(which "busybox")" ]]; }

# IsPlatformAll platform[,platform,...]
# return true if the current platform has all of the listed characteristics
IsPlatformAll()
{
	local platforms=() p; StringToArray "$1" "," platforms; shift

	for p in "${platforms[@]}"; do
		! IsPlatform "$p" "$@" && return 1
	done

	return 0
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

PlatformTmp() { IsPlatform win && echo "$UADATA/Temp" || echo "$TMP"; }

# RunPlatform PREFIX [--host [HOST]] - call platform functions, i.e. prefixWin.  Sample order win -> debian -> ubuntu -> wsl
function RunPlatform()
{
	local function="$1"; shift

	# set _platform variables
	if [[ "$1" == @(-h|--host) ]]; then		
		shift
		[[ $1 ]] && { ScriptEval HostGetInfo "$1" || return; }
	else
		local _platform="$PLATFORM" _platformLike="$PLATFORM_LIKE" _platformId="$PLATFORM_ID" _platformKernel="$PLATFORM_KERNEL" _machine="$MACHINE" _wsl="$WSL"
	fi

	# run platform function
	[[ $_platform ]] && { RunFunction $function $_platform "$@" || return; }
	[[ $_platformLike ]] && { RunFunction $function $_platformLike "$@" || return; }
	[[ $_platformId ]] && { RunFunction $function $_platformId "$@" || return; }

	# run windows WSL functions
	if [[ "$PLATFORM" == "win" ]]; then
		IsPlatform wsl --host && { RunFunction $function wsl "$@" || return; }
		IsPlatform wsl1 --host && { RunFunction $function wsl1 "$@" || return; }
		IsPlatform wsl2 --host && { RunFunction $function wsl2 "$@" || return; }
	fi

	# run other functions
	IsPlatform entware --host && { RunFunction $function entware "$@" || return; }
	IsPlatform debian,mac --host && { RunFunction $function DebianMac "$@" || return; }
	IsPlatform pikernel --host && { RunFunction $function PiKernel "$@" || return; }
	IsPlatform vm --host && { RunFunction $function vm "$@" || return; }
	IsPlatform physical --host && { RunFunction $function physical "$@" || return; }

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
handle() { ProcessResource "$@"; }
InUse() { ProcessResource "$@"; }
IsRoot() { [[ "$USER" == "root" || $SUDO_USER ]]; }
IsSystemd() { cat /proc/1/status | grep -i "^Name:[	 ]*systemd$" >& /dev/null; } # systemd must be PID 1
RunQuiet() { "$@" > /dev/null; }
RunSilent() { "$@" >& /dev/null; }

IsExecutable()
{
	local p="$@"; [[ ! $p ]] && { EchoErr "usage: IsExecutable PROGRAM"; return 1; }
	local ext="$(GetFileExtension "$p")"

	# file $UADATA/Microsoft/WindowsApps/*.exe returns empty, so assume files that end in exe are executable
	[[ -f "$p" && "$ext" =~ (^exe$|^com$) ]] && return 0

	# executable file
	[[ -f "$p" ]] && { file "$(GetRealPath "$p")" | grep -E "executable|ELF" > /dev/null; return; }

	# alias, builtin, or function
	type -a "$p" >& /dev/null
}

IsTaskRunning() 
{
	local file="$1"

	! IsPlatform win && { IsTaskRunningDo ",$file$"; return; }

	# Windows - search with path only
	HasFilePath "$file" && { IsTaskRunningDo ",$(utwq "$file")$"; return; }

	# Windows - search with and without a path
	IsTaskRunningDo	",$file$" || IsTaskRunningDo ",.*\\\\$file$"
}

IsTaskRunningDo() { ProcessList | tgrep -v ",grep" | grep -iq  "$1"; }

# IsProcessRunning PROCESS - faster, no Windows processes
IsProcessRunning()
{
	local o="-snq"; IsPlatform mac && unset o; 
	pidof $o "$1"
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
	case "$PLATFORM" in

		win)		
			local p="${1/.exe/}.exe"; GetFileName "$p" p # ensure .exe extension
			cd "$PBIN" || return # process.exe only runs from the current directory in wsl
			./Process.exe -q "$p" $2 | grep "has been closed successfully." > /dev/null
			;;

		mac) osascript -e "quit app \"$1\"";;

		*) pkill "$p" > /dev/null;;
	esac
}

ProcessIdExists() {	kill -0 $1 >& /dev/null; } # kill is a fast check

# ProcessKill NAME - kill the specified process
# -a|--all 		kill all processes with NAME, not just the user process
# -w|--win		kill the Windows process with NAME
ProcessKill()
{
	local p all win; 

	while (( $# != 0 )); do
		case "$1" in "") : ;;
			-a|--all) all="true";;
			-w|--win) win="true";;
			*)
				if ! IsOption "$1" && [[ ! $p ]]; then p="$1"
				else UnknownOption "$1" "ProcessKill"; return
				fi
		esac
		shift
	done

	[[ "$(GetFileExtension "$p")" == "exe" ]] && win="true"

	if [[ $win ]]; then
		start pskill.exe "$p" > /dev/null
	elif [[ $all ]]; then
		pkill "$p" > "/dev/null"
	else
		pkill "$p" -U "$UID"  > "/dev/null"
	fi
}

ProcessList() # PID,NAME - show operating system native process ID and executable name with a full path
{ 
	case $PLATFORM in
		win) 
			if InPath ProcessList.exe; then
				ProcessList.exe | RemoveCarriageReturn
			elif InPath wmic.exe; then
				wmic.exe process get Name,ExecutablePath,ProcessID /format:csv | RemoveCarriageReturn | tail +3 | awk -F"," '{ print $4 "," ($2 == "" ? $3 : $2) }'
			else
				powershell --command 'Get-Process | select Name,Path,ID | ConvertTo-Csv' | RemoveCarriageReturn | awk -F"," '{ print $3 "," ($2 == "" ? $1 ".exe" : $2) }' | RemoveQuotes
			fi
			;;
		linux) ps -ef | awk '{ print $2 "," substr($0,index($0,$8)) }';;
		mac) ps -ef | ${G}cut -c7-11,50- --output-delimiter="," | sed -e 's/^[ \t]*//' | grep -v "NPID,COMMAND";;
	esac
}

ProcessResource()
{
	IsPlatform win && { start handle.exe "$@"; return; }
	InPath lsof && { lsof "$@"; return; }
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
	local elevate file force noPrompt sudo terminal test run verbose wait windowStyle

	while (( $# != 0 )); do
		case "$1" in "") : ;;
			-e|--elevate) ! IsElevated && IsPlatform win && elevate="--elevate";;
			-f|--force) force="--force";;
			-h|--help) startUsage; return 0;;
			-np|--no-prompt) noPrompt="--no-prompt";;
			-q|--quiet) quiet="--quiet";;
			-s|--sudo) sudo="sudoc";;
			-T|--terminal) [[ ! $2 ]] && { startUsage; return 1; }; terminal="$2"; shift;;
			-t|--test) test="--test"; $run="echo -E";;
			-v|-vv|-vvv|--verbose) verbose="$1";;
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
	[[ "$file" =~ \.app$ ]] && { open -a "$file" "${args[@]}"; return; }

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

		[[ ! $elevate ]] && IsConsoleProgram "$file" && { $run $sudo "$fullFile" "${args[@]}"; return; }

		# escape spaces for shell scripts so arguments are preserved when elevating - we must be elevating scripts here
		if IsShellScript "$fullFile"; then	
			IsBash && for (( i=0 ; i < ${#args[@]} ; ++i )); do args[$i]="${args[$i]// /\\ }"; done
			IsZsh && for (( i=1 ; i <= ${#args[@]} ; ++i )); do args[$i]="${args[$i]// /\\ }"; done	
		fi

		# start the program
		if IsShellScript "$fullFile"; then
			local p="wsl.exe -d $(wsl get name)"; [[ "$terminal" == "wt" ]] && InPath wt.exe && p="wt.exe -d \"$PWD\" wsl.exe -d $(wsl get name)"
			if IsSystemd; then
				$run RunProcess.exe $wait $elevate "${windowStyle[@]}" bash.exe -c \""$(FindInPath "$fullFile") "${args[@]}""\"
			else
				[[ $verbose ]] && echo -E "Running: " RunProcess.exe $wait $elevate "${windowStyle[@]}" $p --user $USER -e "$(FindInPath "$fullFile")" "${args[@]}"
				$run RunProcess.exe $wait $elevate "${windowStyle[@]}" $p --user $USER -e "$(FindInPath "$fullFile")" "${args[@]}"
			fi
		else
			[[ $verbose ]] && echo -E "Running:" RunProcess.exe $wait $elevate "${windowStyle[@]}" "$(utw "$fullFile")" "${args[@]}"
			$run RunProcess.exe $wait $elevate "${windowStyle[@]}" "$(utw "$fullFile")" "${args[@]}"
		fi
		result=$?

		return $result
	fi

 	# run a non-Windows program
	if [[ $wait ]]; then
		(
			$run nohup $sudo "$file" "${args[@]}" >& /dev/null &
			$run wait $!
		)
	else
		($run nohup $sudo "$file" "${args[@]}" >& /dev/null &)		
	fi
} 

#
# Scripts
#

FilterShellScript() { grep -E "shell script|bash.*script|Bourne-Again shell script|\.sh:|\.bash.*:"; }
IsInstalled() { type "$1" >& /dev/null && command "$1" IsInstalled; }
IsShellScript() { file "$1" | FilterShellScript >& /dev/null; }
IsDeclared() { declare -p "$1" >& /dev/null; } # IsDeclared NAME - NAME is a declared variable

# aliases
IsAlias() { type "-t $1" |& grep alias > /dev/null; } # IsAlias NAME - NAME is an alias
GetAlias() { local a=$(type "$1"); a="${a#$1 is aliased to \`}"; echo "${a%\'}"; }

# arguments
IsOption() { [[ "$1" =~ ^-.* && "$1" != "--" ]]; }
IsWindowsOption() { [[ "$1" =~ ^/.* ]]; }
MissingOperand() { ScriptErr "missing $1 operand" "$2"; ScriptTry "$2"; ScriptExit; }
MissingOption() { ScriptErr "missing $1 option" "$2"; ScriptExit; }
UnknownOption() { ScriptErr "unrecognized option '$1'" "$2"; EchoErr "Try '${2:-$(ScriptName)} --help' for more information.";	ScriptExit; }
ExtraOperand() { ScriptErr "extra operand '$1'" "$2"; ScriptTry "$2";	ScriptExit; }

# functions
IsFunction() { declare -f "$1" >& /dev/null; }	# IsFunction NAME - NAME is a function

# FindFunction NAME - find a function NAME case-insensitive
if IsBash; then
	FindFunction() { declare -F | grep -iE "^declare -f ${1}$" | sed "s/declare -f //"; return "${PIPESTATUS[1]}"; }
else
	FindFunction() { print -l ${(ok)functions} | grep -iE "^${1}$" ; }
fi

# RunFunction NAME [SUFFIX|--] [ARGS]- call a function if it exists, optionally with the specified suffix (i.e. nameSuffix)
RunFunction()
{
	local f="$1"; shift
	local suffix="$1";  [[ $suffix && "$suffix" != "--" ]] && { f+="$(UpperCaseFirst "$suffix")"; shift; }
	[[ "$1" == "--" ]] && shift
	! IsFunction "$f" && return
	"$f" "$@"
}

# scripts

ScriptCd() { local dir; dir="$("$@")" || return; dir="$(echo "$dir" | ${G}head --lines=1)" && { echo "cd $dir"; DoCd "$dir"; }; }  # ScriptCd <script> [arguments](cd) - run a script and change the directory returned
ScriptDir() { IsBash && GetFilePath "${BASH_SOURCE[0]}" || GetFilePath "$ZSH_SCRIPT"; }
ScriptErr() { InitColor; EchoErr "${RED}$(ScriptPrefix "$2")$1${RESET}"; }
ScriptExit() { [[ "$-" == *i* ]] && return "${1:-1}" || exit "${1:-1}"; }; 
ScriptPrefix() { local name="$(ScriptName "$1")"; [[ ! $name ]] && return; printf "$name: "; }
ScriptTry() { EchoErr "Try '$(ScriptName "$1") --help' for more information."; }

ScriptName()
{
	local name; func="$1"; [[ $func ]] && { printf "$func"; return; }
	IsBash && name="$(GetFileName "${BASH_SOURCE[-1]}")" || name="$(GetFileName "$ZSH_SCRIPT")"
	[[ "$name" == "function.sh" ]] && unset name
	printf "$name" 
}

# ScriptEval <script> [<arguments>] - run a script and evaluate the output.
#    Typically the output is variables to set, such as printf "a=%q;b=%q;" "result a" "result b"
ScriptEval() { local result; export SCRIPT_EVAL="true"; result="$("$@")" || return; eval "$result"; } 

# ScriptReturn [-v|--verbose] <var>... - return the specified variables as output from the script in a escaped format.
#    The script should be called using ScriptEval.
#   -e, --export		the returned variables should be exported
#   -s, --show			show the variables in a human readable format instead of a escpaed format
ScriptReturn() 
{
	local var avar fmt="%q" arrays export
	[[ "$1" == @(-e|--export) ]] && { export="export "; shift; }
	[[ "$1" == @(-v|-vv|-vvv|--verbose) ]] && { fmt="\"%s\""; shift; }

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

# certificates
CertView() { local c; for c in "$@"; do openssl x509 -in "$c" -text; done; }

# sudo

SudoCheck() { [[ ! -r "$1" ]] && sudo="sudoc"; } # SudoCheck FILE - set sudo variable to sudoc if user does not have read permissiont to the file
sudox() { sudoc XAUTHORITY="$HOME/.Xauthority" "$@"; }

# sudoc COMMANDS - use the credential store to get the password if available, --preserve|-p to preserve the existing path (less secure)
sudoc()
{ 
	IsRoot && { env "$@"; return; } # use env to support commands with variable prefixes, i.e. sudoc VAR=12 ls

	local p=( "$(FindInPath "sudo")" ) preserve; [[ "$1" == @(-p|--preserve) ]] && { preserve="true"; shift; }

	if [[ $preserve ]]; then
		if IsPlatform pi; then p+=( --preserve-env )
		elif ! IsPlatform mac; then p+=( --preserve-env=PATH )
		fi
	fi

	if credential --quiet exists secure default; then
		SUDO_ASKPASS="$BIN/SudoAskPass" "${p[@]}" --askpass "$@"; 
	else
		"${p[@]}" "$@"; 
	fi
} 

# sudoe FILE - sudoedit with credentials
sudoe()  
{ 
	IsRoot && { sudoedit "$@"; return; }

	if InPath sudoedit && credential -q exists secure default; then
		SUDO_ASKPASS="$BIN/SudoAskPass" sudoedit --askpass "$@"
	elif InPath sudoedit; then
		sudoedit "$@"
	else
		sudo nano "$@" 
	fi
} 

#
# Text Processing
#

tac() { InPath tac && command tac "$@" | cat "$@"; }
tgrep() { grep "$@"; true; } # true grep, always returns true, useful in pipelines if pipefail is set and grep returns to lines
Utf16toAnsi() { iconv -f utf-16 -t ISO-8859-1; }
Utf16to8() { iconv -f utf-16 -t UTF-8; }

GetTextEditor()
{
	if HasWindowManager; then
		IsInstalled sublime && { echo "$(sublime program)"; return 0; }
		IsPlatform win && InPath "$P/Notepad++/notepad++.exe" && { echo "$P/Notepad++/notepad++.exe"; return 0; }
		InPath geany && { echo "geany"; return 0; }
		IsPlatform mac && { echo "TextEdit.app"; return 0; }
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

#
# Virtual Machine
#

IsChroot() { GetChrootName; [[ $CHROOT_NAME ]]; }
ChrootName() { GetChrootName; echo "$CHROOT_NAME"; }
ChrootPlatform() { ! IsChroot && return; [[ $(uname -r) =~ [Mm]icrosoft ]] && echo "win" || echo "linux"; }

IsContainer() { ! InPath systemd-detect-virt && return 1; [[ "$(systemd-detect-virt --container)" != @(none|wsl) ]]; }
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

# GetVmType - cached to avoid multiple sudo calls
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
		local product

		if InPath wmic.exe; then
			procuct="$(wmic.exe baseboard get product | RemoveCarriageReturn | head -2 | tail -1 | RemoveSpaceTrim)"

		# wmic.exe is removed from Windows build  >= 22000.376
		# - PowerShell 5 (powershell.exe) is ~6X faster than PowerShell 7
		# - PowerShell 7 - use powershell without the .exe
		else
			product="$(powershell.exe 'Get-WmiObject -Class Win32_BaseBoard | Format-List Product' | RemoveCarriageReturn | grep Product | tr -s ' ' | cut -d: -f2 | RemoveSpaceTrim)"
		fi

		if [[ "$product" == "440BX Desktop Reference Platform" ]]; then result="vmware"
		elif [[ "$product" == "Virtual Machine" ]]; then result="hyperv"
		else result=""
		fi
	fi

	export VM_TYPE_CHECKED="true" VM_TYPE="$result"
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
		export DISPLAY="$(GetWslGateway):0"
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
			-a|--activate) wargs=( front ); args=( -a );;
			-c|--close) wargs=( /res /act ); args=( -c );;
			-max|--maximize) wargs=( maximized ) args=( -a );;
			-min|--minimize) wargs=( minimized );;
			-H|--hide) wargs=( hidden );;
			-uh|--unhide) wargs=( show_default );;
			-h|--help) WinSetStateUsage; return 0;;
			*)
				if [[ ! $title ]]; then title="$1"
				else UnknownOption "$1" "WinSetState"; return; fi
		esac
		shift
	done

	# Windows - see if the title matches a windows running in Windows
	if IsPlatform win; then
		WindowMode.exe -title "$title" -mode "${wargs[@]}"
		return
	fi

	# X Windows - see if title matches a windows running on the X server
	if [[ $DISPLAY ]] && InPath wmctrl; then
		id="$(wmctrl -l -x | grep -i "$title" | head -1 | cut -d" " -f1)"

		if [[ $id ]]; then
			[[ $args ]] && { wmctrl -i "${args[@]}" "$id"; return; }
			return 0
		fi
	fi

	return 1
}

# platform specific functions
SourceIfExistsPlatform "$BIN/function." ".sh" || return

FUNCTIONS="true"
