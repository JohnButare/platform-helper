# function.sh: common functions for non-interactive scripts

set -o pipefail # pipes return first non-zero result

# core setup
IsBash() { [[ $BASH_VERSION ]]; }
IsZsh() { [[ $ZSH_VERSION ]]; }

if IsZsh; then
	PLATFORM_SHELL="zsh"
	PLATFORM_DIR="${${(%):-%x}:h}"
	setopt EXTENDED_GLOB KSH_GLOB NO_NO_MATCH
else
	PLATFORM_SHELL="bash"
	PLATFORM_DIR="${BASH_SOURCE[0]%/*}"
	shopt -s extglob expand_aliases
	shopt -u nocaseglob nocasematch
	whence() { type "@$"; }
fi

SHELL_DIR="${SHELL%/*}"

# dependant commands - these commands are used below
IsDefined() { def "$1" >& /dev/null; }						# IsDefined NAME - NAME is a an alias or function

# PlatformConf - source bash.bashrc now if needed
PlatformConf()
{	
	[[ ! $force && $BASHRC ]] && return
	
	# variables
	local file="$PLATFORM_DIR/bash.bashrc"	
	local notSet; [[ ! $force && ! $BASHRC ]] && notSet="true"

	# validate
	[[ ! -f "$file" ]] && { echo "PlatformConf: the platform configuration file '$file' does not exist" >&2; return; }

	# source
	. "$file" || return

	# warn
	[[ $notSet && ! $quiet ]] && echo "PlatformConf: bash.bashrc was not set" >&2

	return 0
}
PlatformConf || return

#
# arguments
#

# GetAregs - get argument from standard input if not specified on command line
# - must be an alias in order to set the arguments of the caller
# - GetArgsN will read the first argument from standard input if there are not at least N arguments present
# - aliases must be defiend before used in a function
alias GetArgs='[[ $# == 0 ]] && set -- "$(cat)"' 
alias GetArgs2='(( $# < 2 )) && set -- "$(cat)" "$@"'
alias GetArgs3='(( $# < 3 )) && set -- "$(cat)" "$@"'
alias GetArgDash='[[ "$1" == "-" ]] && shift && set -- "$(cat)" "$@"' 

# GetArgsPipe - get all arguments from a pipe
if IsZsh; then
	alias GetArgsPipe='{ local gap; gap=("${(@f)"$(cat)"}"); set -- "${gap[@]}"; unset gap; }'
else
	alias GetArgsPipe='{ local gap; mapfile -t gap <<<$(cat); set -- "${gap[@]}"; unset gap; }'
fi

ShowArgs() { local args=( "$@" ); ArrayShow args; } 	# ShowArgs [ARGS...] - show arguments from command line
SplitArgs() { local args=( $@ ); ArrayShow args; }		# SplitArgs [ARGS...] - split arguments from command line using IFS 

#
# other
#

AllConf() { HashiConf "$@" && CredentialConf "$@" && NetworkConf "$@" && SshAgentConf "$@"; }
EvalVar() { r "${!1}" $2; } # EvalVar <var> <variable> - return the contents of the variable in variable, or set it to var
IsInteractiveShell() { [[ "$-" == *i* ]]; } # 0 if we are running at the command prompt, 1 if we are running from a script
IsUrl() { [[ "$1" =~ ^[A-Za-z][A-Za-z0-9+-]+: ]]; }
r() { [[ $# == 1 ]] && echo "$1" || eval "$2=""\"${1//\"/\\\"}\""; } # result VALUE VAR - echo value or set var to value (faster), r "- '''\"\"\"-" a; echo $a
! IsDefined sponge && alias sponge='cat'

# TTY input and output
IsTty() { ${G}tty --silent;  }		# ??
IsTtyOk() {  { printf "" > "/dev/tty"; } >& "/dev/null"; } # 0 if /dev/tty is usable for reading input or sending output (useful when stdin or stdout is not available in a pipeline)
IsSshTty() { [[ $SSH_TTY ]]; }		# 0 if connected over SSH with a TTY
IsStdIn() { [[ -t 0 ]];  } 				# 0 if STDIN refers to a terminal, i.e. "echo | IsStdIn" is 1 (false)
IsStdOut() { [[ -t 1 ]];  } 			# 0 if STDOUT refers to a terminal, i.e. "IsStdOut | cat" is 1 (false)
IsStdErr() { [[ -t 2 ]];  } 			# 0 if STDERR refers to a terminal, i.e. "IsStdErr |& cat" is 1 (false)

UrlEncodeSpace()
{
	GetArgs
	echo "$1" | sed '
		s/ /%20/g 
  '
}

UrlEncode()
{
	GetArgs
	echo "$1" | sed '
		s / %2f g
		s : %3a g
		s \$ %24 g
		s/ /%20/g 
  '
}

UrlDecode()
{
	GetArgs
	echo "$1" | sed '
		s %2f / g
		s %3a : g
		s %24 \$ g
		s/%20/ /g 
  '
}

UrlDecodeAlt() { GetArgs; : "${*//+/ }"; echo -e "${_//%/\\x}"; }

# update - manage update state in a temporary file location
UpdateDate() { UpdateInit "$1" && [[ -f "$updateFile" ]] && GetFileDateStamp "$updateFile"; } 	# UpdateDate FILE - return the last updated date
UpdateDone() { UpdateInit "$1" && ${G}touch "$updateFile"; }																		# UpdateDone FILE - update the last updated date
UpdateGet() { ! UpdateNeeded "$@" && UpdateGetForce "$updateFile"; }														# UpdateGet FILE - if an update is not needed, get the contents of the update file 
UpdateGetForce() { UpdateInit "$1" && [[ ! -f "$updateFile" ]] && return; cat "$updateFile"; }	# UpdateGetForce FILE - get the contents of the update file 
UpdateRm() { UpdateInit "$1" && rm -f "$updateFile"; }																					# UpdateRm FILE - remove the update file
UpdateRmAll() { UpdateInitDir && DelDir --contents --hidden --files "$updateDir"; }							# UpdateRmAll - remove all update files
UpdateSet() { UpdateInit "$1" && printf "$2" > "$updateFile"; }																	# UpdateSet FILE TEXT - set the contents of the update file
UpdateSince() { ! UpdateNeeded "$@"; }																													# UpdateSince FILE [DATE_SECONDS](TODAY) - return true if the file was updated since the date, or today

# UpdateInit [FILE] - initialize update system, sets updateDir, updateFile
UpdateInit() { UpdateInitDir && UpdateInitFile "$1"; }

# UpdateInitDir [dir]($DATA/update) - initialize update directory, sets updateDir
UpdateInitDir()
{
	[[ $1 || ! $updateDir ]] && updateDir="${1:-$DATA/update}"
	[[ -d "$updateDir" ]] && return
	${G}mkdir --parents "$updateDir" || return
	InPath setfacl && { setfacl --default --modify o::rw "$updateDir" || return; }
	sudoc chmod -R o+w "$updateDir" || return
}

# UpdateInitFile FILE - if specified initialize update file, sets updateFile
UpdateInitFile()
{
	[[ ! $1 ]] && { MissingOperand "file" "UpdateInitFile"; return 1; }
	HasFilePath "$1" && updateFile="$1" || updateFile="$updateDir/$1"
}

# UpdateNeeded FILE [DATE_SECONDS](TODAY) - return true if an update is needed based on the last file modification time.
# - SECONDS - if specified, an update is needed if the file was not modified since the date or today if not specified
# - examples - UpdateNeeded 'update-os', UpdateNeeded 'update-os' "$(GetSeconds '-10 min')"
UpdateNeeded()
{
	local file="$1" seconds="$2"

	# return if update needed
	{ [[ $force ]] || ! UpdateInit "$file" || [[ ! -f "$updateFile" ]]; } && return

	# update is needed if file was not changed 1) in the last seconds (if specified) 2) today
	if [[ $seconds ]]; then
		(( $(echo "$(GetFileModSeconds "$updateFile") <= $seconds" | bc) )) # bc required for Bash since seconds is a float
	else
		[[ "$(GetDateStamp)" != "$(GetFileDateStamp "$updateFile")" ]]; 
	fi
}


# clipboard

clipok()
{ 
	case "$PLATFORM_OS" in 
		linux) [[ "$DISPLAY" ]] && InPath xclip;;
		mac) InPath pbcopy;; 
		win) InPath clip.exe;;
	esac	
}

clipr() 
{ 
	case "$PLATFORM_OS" in
		linux) clipok && xclip -o -sel clip;;
		mac) clipok && pbpaste;;
		win) InPath paste.exe && { RunWin paste.exe | ${G}tail --lines=+2; return; }; RunWin powershell.exe -c Get-Clipboard;;
	esac
}

clipw() 
{ 
	case "$PLATFORM_OS" in 
		linux) clipok && printf "%s" "$@" | xclip -sel clip;;
		mac) clipok && printf "%s" "$@" | pbcopy;; 
		win) InPath clip.exe && printf "%s" "$@" | RunWin clip.exe;; # cd / to fix WSL 2 error running from network share
	esac
}

# logging

header() { InitColor; printf "${RB_BLUE}*********************************** ${RB_INDIGO}$1${RB_BLUE} ***********************************${RESET}\n"; headerDone="$((52 + ${#1}))"; return 0; }
HeaderBig() { InitColor; printf "${RB_BLUE}************************************************************\n* ${RB_INDIGO}$1${RB_BLUE}\n************************************************************${RESET}\n"; }
HeaderDone() { InitColor; printf "${RB_BLUE}$(StringRepeat '*' $headerDone)${RESET}\n"; }
HeaderFancy() { ! InPath pyfiglet lolcat && { HeaderBig "$1"; return; }; pyfiglet --justify=center --width=$COLUMNS "$1" | lolcat; }
hilight() { InitColor; EchoWrap "${GREEN}$@${RESET}"; }
hilightp() { InitColor; printf "${GREEN}$@${RESET}"; } # hilight with no newline

# set color variables if colors are supported (using a terminal, or FORCE_COLOR is set)
InitColor() { { [[ $FORCE_COLOR ]] || IsStdOut; } && InitColorForce || InitColorClear; }
InitColorErr() { { [[ $FORCE_COLOR ]] || IsStdErr; } && InitColorForce || InitColorClear; }
InitColorForce() { GREEN=$(printf '\033[32m'); RB_BLUE=$(printf '\033[38;5;021m') RB_INDIGO=$(printf '\033[38;5;093m') RED=$(printf '\033[31m') RESET=$(printf '\033[m'); PAD=$(printf '\033[25m'); }
InitColorClear() { unset -v GREEN RB_BLUE RB_INDIGO RED RESET PAD; }

# CurrentColumn - return the current cursor column, https://stackoverflow.com/questions/2575037/how-to-get-the-cursor-position-in-bash/2575525#2575525
if IsTtyOk; then
	if IsZsh; then		
		CurrentColumn()
		{
			exec < "/dev/tty"; local old="$(${G}stty -g)"; ${G}stty raw -echo min 0; echo -en "\033[6n" > "/dev/tty"
			IFS=';' read -r -d R -A pos
			${G}stty "$old" >& /dev/null
			[[ ! ${pos[2]} ]] && { echo "0"; return; }
			echo $(( ${pos[2]%%$'\n'*} - 1 ))
		}
	else
		CurrentColumn()
		{
			exec < "/dev/tty"; local old="$(${G}stty -g)"; ${G}stty raw -echo min 0; echo -en "\033[6n" > "/dev/tty"
			IFS=';' read -r -d R -a pos
			${G}stty "$old" >& /dev/null
			[[ ! ${pos[1]} ]] && { echo "0"; return; }
			echo $(( ${pos[1]} - 1 ))
		}
	fi
else
	CurrentColumn() { echo "0"; }
fi

#
# account
#

ActualUser() { echo "${SUDO_USER-$USER}"; }
CreateId() { echo "$((1000 + RANDOM % 9999))"; }
UserDelete() { local user="$1"; ! UserExists "$user" && return; IsPlatform mac && { sudoc dscl . delete "/Users/$group"; return; }; sudoc userdel "$user"; }
UserExists() { IsPlatform mac && { dscl . -list "/Users" | ${G}grep --quiet "^${1}$"; return; }; getent passwd "$1" >& /dev/null; }
UserExistsWin() { IsPlatform win || return; net.exe user "$1" >& /dev/null; }
UserInGroup() { id "$1" 2> /dev/null | ${G}grep --quiet "($2)"; } # UserInGroup USER GROUP
UserList() { IsPlatform mac && { dscl . -list "/Users"; return; }; getent passwd | cut -d: -f1 | sort; }
GroupDelete() { local group="$1"; ! GroupExists "$group" && return; IsPlatform mac && { sudoc dscl . delete "/Groups/$group"; return; }; sudoc groupdel "$group"; }
GroupExists() { IsPlatform mac && { dscl . -list "/Groups" | ${G}grep --quiet "^${1}$"; return; }; getent group "$1" >& /dev/null; }
GroupList() { IsPlatform mac && { dscl . -list "/Groups"; return; }; getent group; }

GroupAdd()
{
	local group="$1"; GroupExists "$group" && return
	if IsPlatform mac; then sudoc dscl . create "/Groups/$group" gid "$(CreateId)"
	else sudoc groupadd "$group"
	fi
}

GroupAddUser()
{
	local group="$1" user="${2:-$USER}"
	GroupAdd "$group" || return
	UserInGroup "$user" "$group" && return

	if IsPlatform mac; then sudoc dscl . create "/Groups/$group" GroupMembership "$user"
	else sudo adduser "$user" "$group"; 
	fi
}

# PasswordGet - get a password from the tty, which works when we are run from a pipeline, i.e. echo test | PasswordGet password
PasswordGet()
{
	! IsTtyOk && { ScriptErr "unable to get a password" "PasswordGet"; return 1; }
	ask password "password" < "/dev/tty"
}

PasswordSet() { PasswordGet | cred set "$@" - ; }

# UserCreate USER PASSWORD [-s|--system] [--ssh-copy]
# --system|-s 		create a system user
# --admin|-a			make the user an administrator
# --ssh-copy			copy the current users SSH configuration to the new user
UserCreate() 
{
	local admin system sslCopy user password passwordShow; 

	# options
	while (( $# != 0 )); do
		case "$1" in "") : ;;
			--admin|-a) admin="--admin";;
			--system|-s) system="--system";;
			--ssh-copy) sshCopy="--ssh-copy";;
			*)
				if ! IsOption "$1" && [[ ! $user ]]; then user="$1"
				elif ! IsOption "$1" && [[ ! $password ]]; then password="$1"
				else UnknownOption "$1" "UserCreate"; return
				fi
		esac
		shift
	done

	[[ ! $user ]] && { MissingOperand "user" "UserCreate"; return 1; }
	[[ ! $password ]] && { passwordShow="true"; password="$(pwgen 14 1)" || return; }

	# create user
	if ! UserExists "$user"; then
		hilight "Creating user '$user'..."

		if IsPlatform mac; then
			local adminArg; [[ $admin || $system ]] && adminArg="-admin"			
			sudoc sysadminctl -addUser "$user" -password "$password" $admin || return

		elif [[ $system ]]; then
			sudoc useradd --create-home --system "$user" || return
			password linux --user "$user" --password "$password" || return

		else
			sudoc adduser $user --disabled-password --gecos "" || return
			echo "$user:$password" | sudo chpasswd || return

		fi		

		[[ "$passwordShow" ]] && echo "User '$user' password is $password"
	fi

	# make user administrator	
	local group="sudo"; IsPlatform mac && group="admin"

	if [[ $admin || $system ]] && ! UserInGroup "$user" "$group"; then
		echo "Adding user '$user' to group '$group'..."
		if IsPlatform mac; then GroupAddUser "$group" "$user" || return
		else sudo usermod -aG sudo $user || return
		fi
	fi

	# don't require sudo password for system users
	if [[ $system ]] && ! IsPlatform mac; then
		local file="/etc/sudoers.d/020_$user-nopasswd"

		if ! sudoc ls "$file" >& /dev/null; then
			echo "Adding user '$user' to sudoers..."
			echo "$user ALL=(ALL) NOPASSWD: ALL" | sudo ${G}tee "/etc/sudoers.d/020_$user-nopasswd" || return
		fi
	fi

	# SSH configuration - copy or create
	if [[ $sshCopy && ! -d "$USERS/$user/.ssh" ]]; then
		echo "Copying user '$user' SSH configuration from $USER..."
		sudoc cp -r "$HOME/.ssh" "$USERS/$user/.ssh" || return

	elif ! sudo ls "$USERS/$user/.ssh/id_ed25519" >& /dev/null; then
		echo "Creating user '$user' SSH keys..."
		sudo ssh-keygen -t "ed25519" -C "$user" -f "$USERS/$user/.ssh/id_ed25519" -P "$password" || return
		echo "Private key passphrase is password is $password"
	fi

	# update SSH configuration permissions
	SshHelper permission "$user" || return
}

# UserFullName - return the full name of the user, or the user id if the full name is not available
UserFullName() 
{ 
	local s
	case "$PLATFORM_OS" in
		win) s="$(net.exe user "$USER" |& grep "Full Name" | RemoveCarriageReturn | ${G}sed 's/Full Name//' | RemoveSpaceTrim)";;
		mac)  s="$(dscl . -read "/Users/$USER" RealName  | ${G}tail --lines=1 | RemoveSpaceTrim)";;
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
		EchoErr "GetLoginShell: cannot determine current shell"
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

# SetCurrentShell SHELL - bash|zsh
SetLoginShell()
{
	local shell; shell="$(FindLoginShell "$1")" || return

	[[ "$(GetLoginShell)" == "$shell" ]] && return 0

	if InPath chsh; then
		sudoc chsh -s "$shell" $USER
	elif InPath usermod; then
		sudoc usermod --shell "$shell" $USER
	elif [[ -f /etc/passwd ]]; then
		clipw "$shell" || { echo "Change the $USER login shell (after last :) to $shell"; pause; }
		sudoe "/etc/passwd"
	else
		EchoErr "SetLoginShell: unable to change login shell to $1"
	fi
}

FindLoginShell() # FindShell SHELL - find the path to a valid login shell
{
	local shell shells="/etc/shells";  IsPlatform entware && shells="/opt/etc/shells"

	[[ ! $1 ]] && { MissingOperand "shell" "FindLoginShell"; return 1; }

	if [[ -f "$shells" ]]; then
		shell="$(grep "/$1" "$shells" | ${G}tail --lines=-1)" # assume the last shell is the newest
	else
		shell="$(which "$1")" # no valid shell file, assume it is valid and search for it in the path
	fi

	[[ ! -f "$shell" ]] && { EchoErr "FindLoginShell: $1 is not a valid default shell"; return 1; }
	echo "$shell"
}

# UserHome USER - return users home directory
UserHome()
{
	IsPlatform mac && { dscl . -read "/users/$1" | grep "^NFSHomeDirectory:" | cut -d" " -f2; return; }
	InPath getent && { getent passwd "$1" | cut -d":" -f6; return; }
	${G}grep "^$1:" "/etc/passwd" | cut -d":" -f6
}

#
# applications
#

IsiTerm() { [[ "$LC_TERMINAL" == "iTerm2" ]]; }
IsWarp() { [[ "$TERM_PROGRAM" == "WarpTerminal" ]]; }

# AppVersion app - return the version of the specified application
AppVersion()
{
	# arguments
	local allowAlpha alternate app appOrig cache force forceLevel forceLess quiet version

	while (( $# != 0 )); do
		case "$1" in "") : ;;
			--cache|-c) cache="--cache";;
			--force|-f|-ff|-fff) ScriptOptForce "$1";;
			--quiet|-q) quiet="--quiet";;
			--alternate|-a) alternate="--alternate";;
			--allow-alpha|-aa) allowAlpha="--allow-alpha";;
			*)
				! IsOption "$1" && [[ ! $app ]] && { app="$(AppToCli "$1")" appOrig="$1"; shift; continue; }
				UnknownOption "$1" "AppVersion"; return
		esac
		shift
	done

	[[ ! $app ]] && { MissingOperand "app" "AppVersion"; return 1; }

	# cache
	local appCache="version-$(GetFileName "$app" | LowerCase)"
	[[ $alternate ]] && appCache+="-alternate"
	[[ $cache ]] && UpdateGet "$appCache" && return

	# get version with helper script
	local helper; helper="$(AppHelper "$app")" && { version="$(alternate="$alternate" "$helper" $quiet --version)" || return; }

	# find and get mac application versions
	local dir
	if [[ ! $version ]] && IsPlatform mac && dir="$(FindMacApp "$app")" && [[ -f "$dir/Contents/Info.plist" ]]; then
		version="$(defaults read "$dir/Contents/Info.plist" CFBundleShortVersionString)" || return
	fi

	# check if the app exists
	if [[ ! $version ]]; then
		local file; file="$(FindInPath "$app")"

		# not found if cannot find in path or if is excluded
		# - Homebrew speedtest conflicts with the GUI speedtest
		# - /usr/bin/dash conflicts with the Dash mac application
		[[ "$?" != "0" || "$file" == @(/opt/homebrew/bin/speedtest|/bin/dash|/usr/bin/dash) ]] && { ScriptErrQuiet "application '$appOrig' is not installed" "AppVersion"; return 1; }
	fi

	# special cases
	if [[ ! $version ]]; then
		case "$(LowerCase "$(GetFileName "$app")")" in
			cowsay|gtop|kubectl|parallel) return;; # excluded, cannot get version
			7z) version="$(7z | head -2 | ${G}tail --lines=-1 | cut -d" " -f 3)" || return;;
			apt) version="$(apt --version | cut -d" " -f2)" || return;;
			bash) version="$(bash -c 'echo ${BASH_VERSION}' | cut -d"-" -f 1 | RemoveAfter "(")" || return;;
			bat) version="$(bat --version | cut -d" " -f2)";;
			cfssl) version="$(cfssl version | head -1 | cut -d':' -f 2 | RemoveSpaceTrim)" || return;;
			consul) version="$(consul --version | head -1 | cut -d" " -f2 | RemoveFront "v")" || return;;
			cryfs|cryfs-unmount) version="$(cryfs --version | head -1 | cut -d" " -f3)";;
			damon) version="$(damon --version | head -1 | cut -d"v" -f2 | cut -d"-" -f1)" || return;;
			dbxcli) version="$(dbxcli version | head -1 | sed 's/.* v//')" || return;;
			dog) version="$(dog --version | head -2 | ${G}tail --lines=-1 | cut -d"v" -f2)" || return;;
			duf) version="$(duf --version | cut -d" " -f2)" || return;;
			exa) version="$(exa --version | head -2 | ${G}tail --lines=-1 | cut -d"v" -f2 | cut -d" " -f1)" || return;;
			figlet|pyfiglet) version="$(pyfiglet --version | RemoveEnd ".post1")" || return;;
			fortune) version="$(fortune --version | cut -d" " -f2)" || return;;
			gcc) version="$(gcc --version | head -1 | cut -d" " -f4)" || return;;
			git-credential-manager) version="$(git-credential-manager --version | cut -d"+" -f1)" || return;;
			go) version="$(go version | head -1 | cut -d" " -f3 | RemoveFront "go")" || return;;
			java) version="$(java --version |& head -1 | cut -d" " -f2)" || return;;
			jq) version="$(jq --version |& cut -d"-" -f2)" || return;;
			keepalived) version="$(keepalived --version |& shead -1 | sed 's/.* v//' | cut -d" " -f1)" || return;;
			minikube) version="$(echo "$(minikube version)" | head -1 | sed 's/.* v//')" || return;; # minicube pipe returns error on mac
			nginx) version="$(nginx -v |& sed 's/.*nginx\///' | cut -d" " -f1)";;
			node) version="$(node --version | RemoveFront "v")";;
			nomad) version="$(nomad --version | head -1 | cut -d" " -f2 | RemoveFront "v")" || return;;
			pip) version="$(pip --version | cut -d" " -f2)" || return;;
			procs) version="$(procs --version | cut -d" " -f2 | RemoveFront "\"")" || return;;
			python3) version="$(python3 --version | cut -d" " -f2)" || return;;
			rg) version="$(rg --version | shead -1 | cut -d" " -f 2)" || return;;
			ruby) version="$(ruby --version | cut -d" " -f2 | cut -d"p" -f 1)" || return;;
			speedtest-cli) allowAlpha="--allow-alpha"; version="$(speedtest-cli --version | head -1 | cut -d" " -f2)" || return;;
			sshfs) version="$(sshfs --version |& ${G}tail --lines=-1 | cut -d" " -f3)" || return;;
			tmux) version="$(tmux -V | cut -d" " -f2)" || return;;
			vault) version="$(vault --version | cut -d" " -f2 | RemoveFront "v")" || return;;
			zsh) version="$("$app" --version | cut -d" " -f2)" || return;;
		esac
	fi

	# get Windows executable version
	if [[ ! $version ]] && IsPlatform win && [[ "$(GetFileExtension "$file" | LowerCase)" == "exe" ]]; then
		if InPath "wmic.exe"; then # WMIC is deprecated but does not require elevation
			version="$(RunWin wmic.exe datafile where name="\"$(utw "$file" | QuoteBackslashes)\"" get version /value | RemoveCarriageReturn | grep -i "Version=" | cut -d= -f2)" || return
		elif CanElevate; then
			version="$(RunWin powershell.exe "(Get-Item -path \"$(utw "$file")\").VersionInfo.FileVersion" | RemoveCarriageReturn)" || return

			# use major, minor, build, revision - for programs like speedcrunch.exe
			if ! IsNumeric "$version"; then
				version="$(RunWin powershell.exe "(Get-Item -path \"$(utw "$file")\").VersionInfo.FileVersionRaw" | RemoveCarriageReturn | RemoveEmptyLines | tail -1 | tr -s " " | RemoveSpaceTrim | sed 's/ /\./g')" || return
			fi
		fi
	fi

	# call APP --version - where the version number is the last word of the first line
	[[ ! $version ]] && { version="$("$file" --version | head -1 | awk '{print $NF}' | RemoveCarriageReturn)" || return; }

	# validation
	[[ ! $version ]] && { ScriptErrQuiet "application '$appOrig' version was not found" "AppVersion"; return 1; }	
	[[ ! $allowAlpha ]] && ! IsNumeric "$version" && { ScriptErrQuiet "application '$appOrig' version '$version' is not numeric" "AppVersion"; return 1; }
	UpdateSet "$appCache" "$version" && echo "$version"
}

# AppHelper APP - return the helper application for the app in $BIN
AppHelper()
{
	local app="$1" appCheck

	# return if a full path to BIN was specified
	[[ "$app" =~ ^$BIN ]] && { echo "$app"; return; }
	HasFilePath "$app" && return 1
	
	# find $app or ${app}Helper in $BIN
	appCheck="$(${G}find "$BIN" -iname "$app")" && [[ -f "$appCheck" ]] && { echo "$appCheck"; return; }
	appCheck="$(${G}find "$BIN" -iname "${app}Helper")" && [[ -f "$appCheck" ]] && { echo "$appCheck"; return; }

	# not found
	return 1
}

AppToCli()
{
	local app="$1"
	case "$(LowerCase "$app")" in
		1passwordcli) echo "op";;
		7zip) echo "7z";;
		apache) echo "";; # no program for Apache
		apt) ! IsPlatform mac && echo "apt";; # /usr/bin/apt in Mac is legacy
		chroot) echo "schroot";;
		python) echo "python3";;
		*) InPath "$(LowerCase "$app")" && echo "$(LowerCase "$app")" || echo "$app";;
	esac
}

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

# Borg Backup
BorgConf() { ScriptEval BorgHelper environment "$@"; }

# Cloud
CloudConf()
{
	# arguments
	local quiet

	while (( $# != 0 )); do
		case "$1" in "") : ;;
			--quiet|-q) quiet="--quiet";;
			*) UnknownOption "$1" "CloudConf"; return
		esac
		shift
	done

	# find a cloud directory
	local cloud; unset CLOUD CLOUD_ROOT

	if [[ -d "$HOME/Dropbox" ]]; then
		export CLOUD="$HOME/Dropbox"
	elif [[ -d "$HOME/OneDrive" ]]; then
		export CLOUD="$HOME/OneDrive"
	fi

	[[ $CLOUD ]] && { export CLOUD_ROOT="$CLOUD"; [[ -d "${CLOUD}Root" ]] && export CLOUD_ROOT="${CLOUD}Root"; }
	[[ ! $CLOUD ]] && { [[ ! $quiet ]] && ScriptErr "unable to find a cloud directory" "CloudConf"; return 1; }
	return 0
}

# Cron
CronLog() { local severity="${2:-info}"; logger -p "cron.$severity" "$1"; }

# CronAdd [--root] JOB - add a job to the Cron table if it does not exist
CronAdd()
{
	local root; [[ "$1" == @(-r|--root) ]] && { shift; root="sudoc"; }
	local job="$1"

	# return if the job exists
	$root crontab -l |& grep --quiet "^${job}$" && return

	# add the job
	local file; file="${G}mktemp" || return
	$root crontab -l &> /dev/null && { $root crontab -l > "$file" || return; } 	# add existing crontab
	echo "$job" >> "$file" || return																						# add new job
	$root crontab "$file" || return																							# save new crontab
	rm "$file" || return																												# cleanup
}

# D-Bus
DbusConf()
{
	local force forceLevel forceLess; ScriptOptForce "$@"
	local verbose verboseLevel verboseLess; ScriptOptVerbose "$@"

	# initialize
	(( verboseLevel > 1 )) && header "D-BUS Configuration"

	if IsPlatform wsl; then
		export XDG_RUNTIME_DIR="/run/user/$(${G}id -u)"
		export DBUS_SESSION_BUS_ADDRESS="unix:path=$XDG_RUNTIME_DIR/bus"
		SystemdConf || return
	elif IsPlatform linux; then
		if [[ $DBUS_SESSION_BUS_ADDRESS ]]; then :
		elif [[ $XDG_RUNTIME_DIR ]]; then export DBUS_SESSION_BUS_ADDRESS="$XDG_RUNTIME_DIR/bus"
		else export DBUS_SESSION_BUS_ADDRESS="/dev/null"
		fi
	elif IsPlatform mac; then # ignore systems without D-BUS
		:
	else
		ScriptMessage "D-BUS is not installed"
		return
	fi

	# logging
	(( verboseLevel > 1 )) && ScriptMessage "DBUS_SESSION_BUS_ADDRESS=$DBUS_SESSION_BUS_ADDRESS" "DbusConf"
	
	return 0
}

# DirenvConf - confiogure direnv if it is installed
DirenvConf()
{
	InPath direnv || { ScriptErr "direnv is not installed" "DirenvConf"; return 1; }
	def _direnv_hook >& /dev/null && return
	eval "$(direnv hook "$PLATFORM_SHELL")"
}

# .NET
DotNetConf()
{
	local force forceLevel forceLess; ScriptOptForce "$@"	
	[[ ! $force && $DOTNET_CHECKED ]] && return
	unset -v DOTNET DOTNET_ROOT

	# find .NET root directory
	if ! InPath dotnet || { IsPlatform win && ! InPath dotnet.exe; }; then
		if [[ -d "/usr/local/share/dotnet" ]]; then
			export DOTNET_ROOT="/usr/local/share/dotnet" # .NET on mac fails if DOTNET_ROOT is $HOME/.dotnet
		elif [[ -d "$HOME/.dotnet" ]]; then
			export DOTNET_ROOT="$HOME/.dotnet"
		elif [[ -d "$P/dotnet" ]]; then
			export DOTNET_ROOT="$P/dotnet"	
		else
			DOTNET_CHECKED="true"; return
		fi
	fi

	# initialize
	PathAdd "$DOTNET_ROOT"
	export DOTNET="$DOTNET_ROOT/dotnet"
	IsPlatform win && { export DOTNET="$DOTNET.exe"; alias dotnet="dotnet.exe"; }
	
	DOTNET_CHECKED="true"
}

# HashiCorp

HashiConf()
{
	local force forceLevel forceLess; ScriptOptForce "$@"
	local verbose verboseLevel verboseLess; ScriptOptVerbose "$@"

	# configure D-BUS - as root avoid vault error "DBUS_SESSION_BUS_ADDRESS envvar looks to be not set, this can lead to runaway dbus-daemon processes"
	# - run before return to ensure D-BUS is configured when running from Nomad job with VAULT_TOKEN set
	[[ "$USER" == "root" ]] && { DbusConf $force $verbose || return; }

	# return if needed
	[[ ! $force && $HASHI_CHECKED ]] && return
	[[ ! $force && $VAULT_TOKEN ]] && { HASHI_CHECKED="true"; return; }
	! HashiAvailable && return

	# initialize
	(( verboseLevel > 1 )) && header "Hashi Configuration"

	# set credential manager - use gnome-keyring if already selected or if in Windows (faster)
	local manager="local"
	if [[ "$CREDENTIAL_MANAGER" == "gk" ]] || ! UpdateNeeded "credential-manager-gk-ok"; then manager="gk"
	elif IsPlatform win && { service running dbus || app start dbus --quiet $force $verbose; } && credential manager IsAvailable -m=gk; then manager="gk"
	fi

	# set environment from credential store cache if possible (faster .5s, securely save tokens)
	if ! (( forceLevel > 1 )); then
		(( verboseLevel > 1 )) && ScriptMessage "trying to set Hashi environment from '$manager' credential store cache" "HashiConf"
		ScriptEval credential get hashi cache --quiet --manager="$manager" $force $verboseLess  && { HASHI_CHECKED="true"; return; }
	fi

	# set environment (slower 5s)
	(( verboseLevel > 1 )) && ScriptMessage "setting the Hashi environment manually" "HashiConf"
	local vars; vars="$(hashi config environment all --suppress-errors $force $verboseLess)" || return
	if ! eval "$vars"; then
		(( verboseLevel > 1 )) && { ScriptErr "invalid environment variables:"; ScriptMessage "$vars"; }
		ScriptErr "Hashi configuration variables are not valid" "HashiConf"
		return 1
	fi
	echo "$vars" | credential set hashi cache - --quiet --manager="$manager" $force $verbose

	HASHI_CHECKED="true"
}

HashiAvailable() { IsOnNetwork hagerman,sandia; }
HashiConfStatus() { ! HashiAvailable && return; HashiConf --config-prefix=prod "$@" && hashi config status; }
HashiConfConsul() { [[ $CONSUL_HTTP_ADDR || $CONSUL_HTTP_TOKEN ]] || HashiConf "$@"; }
HashiConfNomad() { [[ $NOMAD_ADDR || $NOMAD_TOKEN ]] || HashiConf "$@"; }
HashiConfVault() { [[ $VAULT_ADDR || $VAULT_TOKEN ]] || HashiConf "$@"; }

# HashiServiceRegister SERVICE HOST_NUMS - register consul service SERVICE<n> for all specified hosts, i.e. HashiServiceRegister web 1,2
HashiServiceRegister()
{
	local service="$1" hostNum hostNums; StringToArray "$2" "," hostNums; shift 2

	HashiConf || return
	for hostNum in "${hostNums[@]}"; do
		hashi consul service register "$(ConfigGet "confDir")/hashi/services/$service$hostNum.hcl" --host="$hostNum" "$@" 
	done
}

# git
IsGitDir() { git rev-parse --git-dir >& /dev/null; } # return true if the current directory is in a Git directory (current or parent has a .git directory)
IsGitWorkTree() { [[ "$(git rev-parse --is-inside-git-dir 2>&1)" == "false" ]]; } # return true if the current directory is in a Git work tree (current or parent has a .git directory, not in or under the .git directory)
GitBranch() { git rev-parse --abbrev-ref HEAD; }
GitClone() { ScriptCd GitHelper GitHub clone "$@"; }
GitRoot() { git rev-parse --show-toplevel; }
GitRun() { local git; GitSet && SshAgentConf && $git "$@"; }
GitSet() { git="git"; InPath git.exe && drive IsWin . && git="git.exe"; return 0; }

# i: invoke the installer script (inst) saving the INSTALL_DIR
i()
{ 
	# arguments
	local args=() command force forceLevel forceLess help noFind noRun select timeout verbose verboseLevel verboseLess

	while (( $# != 0 )); do
		case "$1" in "") : ;;	
			--force|-f|-ff|-fff) ScriptOptForce "$1";;
			--help|-h) help="--help";;
			--no-find|-nf) noFind="--no-find";;
			--no-run|-nr) noRun="--no-run";;
			--select|-s) select="--select";;
			--timeout|--timeout=*|-t|-t=*) . script.sh && ScriptOptTimeout "$@";;
			--verbose|-v|-vv|-vvv|-vvvv|-vvvvv) ScriptOptVerbose "$1";;
			*) args+=( "$1" ); ! IsOption "$1" && [[ ! $command ]] && command="$1";;
		esac
		shift
	done

	if [[ $help ]]; then EchoWrap "\
Usage: i [APP*|bak|cd|check|dir|info|select]
install commands.
  -nf, --no-find 	do not find the installation location
  -nr, --no-run 	do not find or run the installation program
  -s,  --select		select the install location"
		return 0
	fi

	case "$(LowerCase "${command:-cd}")" in
		bak) InstBak;;
		cd) InstFind && cd "$INSTALL_DIR";;
		check|select) InstFind;;
		dir) InstFind && echo "$INSTALL_DIR";;
		info) InstFind && echo "The installation directory is $INSTALL_DIR";;
		*) InstFind && inst install --hint "$INSTALL_DIR" $noRun $force $verbose "${args[@]}";;
	esac
}

InstFind()
{
	[[ ! $force && ! $select && $INSTALL_DIR && -d "$INSTALL_DIR" ]] && return
	[[ $noFind ]] && return
	ScriptEval FindInstallFile --eval $select $timeoutArg $verbose || return
	export INSTALL_DIR="$installDir"
	unset installDir file
}

# McflyConf - run after set prompt as this modifies the bash prompt
McflyConf()
{
	local force forceLevel forceLess; ScriptOptForce "$@"	
	[[ ! $force && $MCFLY_CHECKED ]] && return	

	{ ! InPath mcfly || [[ "$TERM_PROGRAM" == @(vscode|WarpTerminal) ]]; } && return

	export MCFLY_HISTFILE="$HISTFILE" MCFLY_RESULTS="50" MCFLY_DELETE_WITHOUT_CONFIRM="true" MCFLY_INTERFACE_VIEW="BOTTOM" MCFLY_RESULTS_SORT="LAST_RUN" MCFLY_PROMPT="❯"
	unset MCFLY_HISTORY MCFLY_SESSION_ID PROMPT_COMMAND
	eval "$(mcfly init "$PLATFORM_SHELL")" || return
	IsBash && PROMPT_COMMAND+=("history -r")
	MCFLY_CHECKED="true"
}

NodeConf()
{
	local force forceLevel forceLess; ScriptOptForce "$@"

	if [[ $force || ! $NODE_CHECKED ]]; then

		if [[ -d "$HOME/.nvm" ]]; then
			export NVM_DIR="$HOME/.nvm"
			SourceIfExists "$NVM_DIR/nvm.sh" || return
			SourceIfExists "$NVM_DIR/bash_completion" || return
		fi

		NODE_CHECKED="true"
	fi

	# configure virtual environments
	if [[ -f ".nvmrc" ]] && [[ -d "$HOME/.nvm" ]]; then
		export NVM_CURRENT="$(nvm current)"
		nvm use --silent || { nvm use; return; }
	elif [[ $NVM_CURRENT ]]; then
		nvm use --silent "$NVM_CURRENT" || return
		unset NVM_CURRENT
	fi

	return 0

}

# NodeNpmGlobal - run npm --global with sudo if needed, assume we do not need sudo if the global prefix is in the users home directory
NodeNpmGlobal()
{
	local sudo="sudoc"; npm --global prefix | qgrep "^$HOME" && sudo=""; 
	$sudo npm --global "$@"
}

NodeUpdate()
{
	# cleanup - update will fail if .bin directory existx, which is create from a failed update
	sudoc rm -fr "$(npm --global prefix)/lib/node_modules/.bin" || return

	# update npm - npm outdated returns false if there are updates
	{ npm outdated --global; true; } | qgrep '^npm ' && { NodeNpmGlobal install npm@latest || return; }

	# update other packages
	npm outdated --global >& /dev/null || { NodeNpmGlobal update || return; }

	return 0
}

powershell() 
{ 
	# return version
	[[ "$1" == @(--version|-v) ]] && { powershell -Command '$PSVersionTable'; return; }
	[[ "$1" == @(--version-short|-vs) ]] && { powershell --version | grep PSVersion | tr -s " " | cut -d" " -f2; return; }
	
	# find powershell in a specific location
	local f files=( "$P/PowerShell/7/pwsh.exe" "$WINDIR/system32/WindowsPowerShell/v1.0/powershell.exe" )
	for f in "${files[@]}"; do
		[[ -f "$f" ]] && { "$f" "$@"; return; }
	done

	# find in path
	FindInPath powershell.exe && { powershell.exe "$@"; return; }
	
	# could not find
	EchoErr "powershell: could not find powershell"; return 1;
}

store()
{
	IsPlatform win && { RunWin cmd.exe /c start ms-windows-store: >& /dev/null; }
	InPath gnome-software && { coproc gnome-software; }
	InPath snap-store && { coproc snap-store; }
	return 0
}

# Unison

UnisonConfDir() { local dir="$HOME/.unison"; IsPlatform mac && dir="$UADATA/Unison"; echo "$dir"; }
UnisonRootConfDir() { local dir="$(UserHome "root")/.unison"; IsPlatform mac && dir="$(UserHome "root")/Library/Application Support/Unison"; echo "$dir"; }

# Zoxide - configure zoxide if it is installed
ZoxideConf()
{
	{ ! InPath zoxide || IsDefined z; } && return
	eval "$(zoxide init $PLATFORM_SHELL)" # errors on bl3 on new shell
	return 0
}

#
# Config
#

ConfigExists() { local file; configInit "$2" && (. "$file"; IsVar "$1"); }							# ConfigExists VAR [FILE] - return true if a configuration variable exists
ConfigGet() { local file; configInit "$2" && (. "$file"; eval echo "\$$1"); }						# ConfigGet VAR [FILE] - get a configuration variable
ConfigGetCurrent() { ConfigGet "$(NetworkCurrent)$(UpperCaseFirst "$1")" "$2"; } 	# ConfigGetCurrent VAR [FILE] - get a configuration entry for the current network

# configInit [FILE] - set the configuration file, find in $BIN/bootstrap-config.sh or /usr/local/bin/bootstrap-config.sh
configInit()
{
	file="$1"

	# use the specified configuration file
	if [[ $file ]]; then
		[[ -f "$file" ]] && return
		EchoErr "configInit: configuration file '$file' does not exist"; return 1
	fi

	# locate the configuration file
	if [[ $BIN ]] && file="$BIN/bootstrap-config.sh" && [[ -f "$file" ]]; then return
	elif file="/usr/local/data/bin/bootstrap-config.sh" && [[ -f "$file" ]]; then return
	elif file="$(ScriptDir)/bootstrap-config.sh" && [[ -f "$file" ]]; then return
	else EchoErr "configInit: unable to locate a configuration file"; return 1
	fi
}

#
# console
#

beep() { echo -en "\007"; }
! IsWarp && clear() { echo -en $'\e[H\e[2J'; }
pause() { [[ $noPause ]] && { [[ $verbose ]] && EchoErr "pause skipped"; return; }; local response m="${@:-Press any key when ready...}"; ReadChars "" "" "$m"; }

LineWrap() { ! InPath setterm && return; setterm --linewrap "$1"; }

# ReadChars N [SECONDS] [MESSAGE] - silently read N characters into the response variable optionally waiting SECONDS
# - mask the differences between the read commands in bash and zsh
ReadChars() 
{ 
	local n="${1:-1}" timeoutSeconds="$2" message="$3"
	local args=() result; [[ $timeoutSeconds ]] && args=(-t "$timeoutSeconds")

	# message
	[[ $message ]] && echo -n "$m"

	# read
	if IsZsh; then # single line statement fails in zsh
		read -s -k $n "${args[@]}" "response"
	else
		read -n $n -s "${args[@]}" "response"
	fi
	result="$?"

	# message
	[[ $m ]] && echo

	return "$result"
}

# SleepStatus [seconds](5) [message](Waiting for n seconds)
SleepStatus()
{
	local i message seconds=5

	case "$#" in
		0) :;;
		1) IsInteger "$1" && seconds="$1" || message="$1";;
		2) message="$1"; seconds=$2;;
		*) EchoWrap "Usage: SleepStatus [MESSAGE](Waiting for n seconds) [SECONDS](5)"
	esac
	[[ ! $message ]] && message="Waiting for $seconds seconds"

	printf "$message..."
	for (( i=1; i<=$seconds; ++i )); do
 		ReadChars 1 1 && { echo "cancelled after $i seconds"; return 1; }
		printf "."
	done

	echo "done"
}

EchoReset() { (( $(CurrentColumn) == 0 )) && return; echo; } # reset to column 0 if not at column 0

# EchoWrap MESSAGE... - show messages wrapping at spaces
EchoWrap()
{
	[[ ! $@ ]] && { echo; return 0; }
	! InPath ${G}fold || ! IsInteger "$COLUMNS" || (( COLUMNS < 20 )) && { echo -e "$@"; return 0; }
	echo -e "$@" | expand -t $TABS | ${G}fold --space --width=$COLUMNS; return 0
}

EchoEnd() { echo -e "$@"; return 0; }																		# show message at the current cursor position
EchoErr() { [[ $@ ]] && EchoResetErr; EchoWrap "$@" >&2; return 0; }		# show error message at column 0
EchoErrEnd() { echo -e "$@" >&2; return 0; }														# show error message on the end of the line
EchoQuiet() { [[ $quiet ]] && return; EchoWrap "$1"; }									# echo a message if quiet is not set
EchoResetErr() { EchoReset "$@" >&2; return 0; } 												# reset to column 0 if not at column 0
HilightErr() { InitColorErr; EchoErr "${RED}$@${RESET}"; }							# hilight an error message
HilightErrEnd() { InitColorErr; EchoErrEnd "${RED}$@${RESET}"; }				# hilight an error message
HilightPrintErr() { InitColorErr; PrintErr "${RED}$@${RESET}"; }				# hilight an error message
PrintErr() { echo -n -e "$@" >&2; return 0; }														# print an error message without a newline or resetting to column 0
PrintEnd() { echo -n -e "$@"; return 0; }																# print message at the current cursor position
PrintQuiet() { [[ $quiet ]] && return; printf "$1"; }										# print a message if quiet is not set

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
# data types
#

IsVar() { declare -p "$1" >& /dev/null; }
IsAnyArray() { IsArray "$1" || IsAssociativeArray "$1"; }
GetDef() { local gd="$(declare -p "$1")"; gd="${gd#*\=}"; gd="${gd#\(}"; r "${gd%\)}" $2; } # GetDef VAR - get definition (value) of the variable

# GetCommandType NAME - return type of command: alias|builtin|function|file|keyword|, https://serverfault.com/questions/879222/get-on-zsh-the-same-result-you-get-when-executing-type-t-on-bash
if IsZsh; then
	GetCommandType()
	{
		local type; type="$(whence -w "$1" | cut -d" " -f2)" || return
		case "$type" in 
			alias|builtin|function) echo "$type";;
			command) echo "file";;
			reserved) echo "keyword";;
		esac
	}
else
	GetCommandType() { type -t "$1"; }
fi 

# ArrayMake VAR ARG... - make an array by splitting passed arguments using IFS
# ArrayMakeC VAR CMD... - make an array from the output of a command
# GetType VAR - show type option without -g (global), i.e. -a (array), -i (integer), -ir (read only integer).   Does not work for some special variables  like funcfiletrace, 
# SetVar VAR VALUE
# StringToArray STRING DELIMITER VAR
if IsZsh; then
	ArrayMake() { setopt sh_word_split; local arrayMake=() arrayName="$1"; shift; arrayMake=( $@ ); ArrayCopy arrayMake "$arrayName"; }
	ArrayMakeC() { setopt sh_word_split; local arrayMakeC=() arrayName="$1"; shift; arrayMakeC=( $($@) ) || return; ArrayCopy arrayMakeC "$arrayName"; }
	ArrayShift() { local arrayShiftVar="$1"; local arrayShiftNum="$2"; ArrayAnyCheck "$1" || return; set -- "${${(P)arrayShiftVar}[@]}"; shift "$arrayShiftNum"; local arrayShiftArray=( "$@" ); ArrayCopy arrayShiftArray "$arrayShiftVar"; }
	ArrayShowKeys() { local var; eval 'local getKeys=( "${(k)'$1'[@]}" )'; ArrayShow getKeys; }
	GetType()	{ local gt="$(declare -p "$1")"; gt="${gt#typeset }"; gt="${gt#-g }"; r "${gt%% *}" $2; }
	GetTypeFull() { eval 'echo ${(t)'$1'}'; }
	IsArray() { [[ "$(GetTypeFull "$1")" =~ ^(array|array-) ]]; }
	IsAssociativeArray() { [[ "$(GetTypeFull "$1")" =~ ^(association|association-) ]]; }
	IsVarHidden() { [[ "$(GetTypeFull "$1")" =~ (-hide) ]]; }
	SetVariable() { eval $1="$2"; }
	StringToArray() { GetArgs3; IFS=$2 read -A $3 <<< "$1"; }
else
	ArrayMake() { local -n arrayMake="$1"; shift; arrayMake=( $@ ); }
	ArrayMakeC() { local -n arrayMakeC="$1"; shift; arrayMakeC=( $($@) ); }
	ArrayShift() { local -n arrayShiftVar="$1"; local arrayShiftNum="$2"; ArrayAnyCheck "$1" || return; set -- "${arrayShiftVar[@]}"; shift "$arrayShiftNum"; arrayShiftVar=( "$@" ); }
	ArrayShowKeys() { local var getKeys="!$1[@]"; eval local keys="( \${$getKeys} )"; ArrayShow keys; }
	GetType() { local gt="$(declare -p $1)"; gt="${gt#declare }"; r "${gt%% *}" $2; }
	IsArray() { [[ "$(declare -p "$1" 2> /dev/null)" =~ ^declare\ \-a.* ]]; }
	IsAssociativeArray() { [[ "$(declare -p "$1" 2> /dev/null)" =~ ^declare\ \-A.* ]]; }
	SetVariable() { local -n var="$1"; var="$2"; }
	StringToArray() { GetArgs3; IFS=$2 read -a $3 <<< "$1"; } 
fi

# array
ArrayAnyCheck() { IsAnyArray "$1" && return; ScriptErr "'$1' is not an array"; return 1; }
ArrayReverse() { { ArrayDelimit "$1" $'\n'; printf "\n"; } | tac; } # last line of tac must end in a newline
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
	local IFS=$'\n'
	eval "$arrayAppendDest=( $(ArrayDelimit "$arrayAppendDest" $'\n' | sort | uniq) )"
}

# ArrayCopy SRC DEST
ArrayCopy()
{
	! IsAnyArray "$1" && { ScriptErr "'$1' is not an array"; return 1; }
	local ifsSave; IfsSave; declare -g $(GetType "$1") "$2"; IfsRestore # save and restore IFS in case it is set to - or a
	eval "$2=( $(GetDef "$1") )"
}

# ArrayDelimit [-q|--quote] NAME [DELIMITER](,) - show array with a delimiter, i.e. ArrayDelimit a $'\n'
ArrayDelimit()
{
	local quote; [[ "$1" == @(-q|--quote) ]] && { quote="\""; shift; }
	local arrayDelimit=(); ArrayCopy "$1" arrayDelimit || return;
	local result delimiter="${2:-,}"
	printf -v result "${quote}%s${quote}${delimiter}" "${arrayDelimit[@]}"
	printf "%s" "${result%$delimiter}" # remove delimiter from end
}

# ArrayDiff A1 A2 - return the items not in common
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

	! IsArray "$1" && return
	local arrayShow=(); ArrayCopy "$1" arrayShow || { IFS="$ifsSave"; return 1; }
	[[ "${#arrayShow[@]}" == "0" ]] && return
	local result delimiter="${2:- }" begin="${3:-\"}" end="${4:-\"}"
	printf -v result "$begin%s$end$delimiter" "${arrayShow[@]}"
	printf "%s\n" "${result%$delimiter}" # remove delimiter from end
}

# IsInArray [-ci|--case-insensitive] [-w|--wild] [-aw|--array-wild] STRING ARRAY_VAR
IsInArray() 
{ 
	# arguments
	local wild awild caseInsensitive
	local s arrayVar

	while (( $# != 0 )); do
		case "$1" in "") : ;;
			-ci|--case-insensitive) caseInsensitive="true";;
			-a|--array-wild) awild="true";; 	# array contains glob patterns
			-w|--wild) wild="true";; 					# string contain glob patterns
			*)
				[[ "$1" == "--" ]] && { shift; break; }
				if ! IsOption "$1" && [[ ! $s ]]; then s="$1"
				elif ! IsOption "$1" && [[ ! $isInArray ]]; then arrayVar="$1"
				else UnknownOption "$1" "IsInArray"; return
				fi
		esac
		shift
	done

	# get string to check
	[[ ! $s && $1 ]] && { s="$1"; shift; }
	[[ ! $s ]] && { MissingOperand "string" "IsInArray"; return 1; }
	[[ $caseInsensitive ]] && LowerCase "$s" s;

	# get array variable
	[[ ! $arrayVar && $1 ]] && { arrayVar="$1"; shift; }
	[[ ! $arrayVar ]] && { MissingOperand "array_var" "IsInArray"; return 1; }
	local isInArray=(); ArrayCopy "$arrayVar" isInArray
		
	# check if string is in the array
	local value
	for value in "${isInArray[@]}"; do
		[[ $caseInsensitive ]] && LowerCase "$value" value
		if [[ $wild ]]; then [[ "$value" =~ $s ]] && return 0;
		elif [[ $awild ]]; then [[ "$s" == $value ]] && return 0;
		else [[ "$s" == "$value" ]] && return 0; fi
	done;

	return 1
}

# date
CompareSeconds() { local a="$1" op="$2" b="$3"; (( ${a%.*}==${b%.*} ? 1${a#*.} $op 1${b#*.} : ${a%.*} $op ${b%.*} )); }
GetDate() { ${G}date --date "$1"; } 																											# GetDate DATE, i.e. @1683597765, @$(GetSeconds '-10 min') 
GetDateStamp() { ${G}date '+%Y%m%d'; }
GetTimeStamp() { ${G}date '+%Y%m%d_%H%M%S'; }
GetSeconds() { local args; [[ $1 ]] && args+=(--date "$1"); ${G}date "${args[@]}" +%s; } 	# GetSeconds [DATE](now) - i.e '-10 min'

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

# GetSeconds [--no-ns|--no-nanoseconds] [<date string>](current time) - return seconds from 1/1/1970 to specified time
# --no-ns|--no-nanoseconds - do not return nanoseconds (fractional date)
GetSeconds()
{
	local format="+%s.%N"; [[ "$1" == @(--no-nanoseconds|--no-ns) ]] && { format="+%s"; shift; }
	[[ "$1" == "-" ]] && set -- "$(cat)"

	[[ $1 ]] && { ${G}date "$format" -d "$1"; return; }
	[[ $# == 0 ]] && ${G}date "$format"; # only return default date if no argument is specified
}

# integer
IsHex() { [[ "$1" =~ ^[[:xdigit:]]+$ ]]; }
IsInteger() { [[ "$1" =~ ^[0-9]+$ ]]; }
IsNumeric() { [[ "$1" =~ ^-?[0-9.]+([.][0-9]+)?$ ]]; }
IsNumericEqual() { IsNumeric "$1" && IsNumeric "$2" && [[ "$(echo "$1 != $2" |& bc 2> /dev/null)" == "0" ]]; } # IsNumericEqual N1 N2 - return true (0) if N1 and N2 are numeric and are equal, i.e. IsNumeric 15.0 15 returns 0
HexToDecimal() { echo "$((16#${1#0x}))"; }

# string
CharCount() { GetArgs2; local charCount="${1//[^$2]}"; echo "${#charCount}"; } # CharCount STRING [CHAR]
IsWild() { [[ "$1" =~ (.*\*|\?.*) ]]; }
NewlineToComma()  { tr '\n' ','; }
NewlineToSpace()  { tr '\n' ' '; }
SpaceToNewline()  { tr ' ' '\n'; }
StringPad() { printf '%*s%s\n' "$(($2))" "$1" ""; } # StringPad S N - pad string s to N characters with spaces on the left
StringRepeat() { printf "$1%.0s" $(eval "echo {1.."$(($2))"}"); } # StringRepeat S N - repeat the specified string N times

ShowChars() { GetArgs; echo -n -e "$@" | ${G}od --address-radix=d -t x1 -t a; } # ShowChars STRING - show all characters in the string

RemoveCarriageReturn()  { sed 's/\r//g'; }
RemoveNewline()  { tr -d '\n'; }
RemoveEmptyLines() { awk 'NF { print; }'; }

RemoveChar() { GetArgs2; echo "${1//${2:- }/}"; }																		# RemoveChar STRING REMOVE
RemoveEnd() { GetArgs2; echo "${1%%*(${2:- })}"; }																	# RemoveEnd STRING REMOVE 
RemoveFront() { GetArgs2; echo "${1##*(${2:- })}"; }																# RemoveFront STRING REMOVE 
RemoveTrim() { GetArgs2; echo "$1" | RemoveFront "${2:- }" | RemoveEnd "${2:- }"; }	# RemoveTrim STRING REMOVE - remove from front and end

RemoveAfter() { GetArgs2; echo "${1%%$2*}"; }				# RemoveAfter STRING REMOVE - remove first occerance of REMOVE and all text after it
RemoveBefore() { GetArgs2; echo "${1##*$2}"; }			# RemoveBefore STRING REMOVE - remove last occerance of REMOVE and all text before it
RemoveBeforeFirst() { GetArgs2; echo "${1#*$2}"; }	# RemoveBeforeFirst STRING REMOVE - remove first occerance of REMOVE and all text before it

RemoveSpace() { GetArgs; RemoveChar "$1" " "; }
RemoveSpaceEnd() { GetArgs; RemoveEnd "$1" " "; }
RemoveSpaceFront() { GetArgs; RemoveFront "$1" " "; }
RemoveSpaceTrim() { GetArgs; RemoveTrim "$1" " "; }

QuoteBackslashes() { GetArgs; echo -E "$@" | sed 's/\\/\\\\/g'; } # escape (quote) backslashes
QuoteForwardslashes() { GetArgs; echo -E "$@" | sed 's/\//\\\//g'; } # escape (quote) forward slashes (/) using a back slash (\)
QuoteParens() { GetArgs; echo -E "$@" | sed 's/(/\\(/g' | sed 's/)/\\)/g'; } # escape (quote) parents
QuotePath() { GetArgs; echo -E "$@" | sed 's/\//\\\//g'; } # escape (quote) path (forward slashes - /) using a back slash (\)
QuoteQuotes() { GetArgs; echo -E "$@" | sed 's/\"/\\\"/g'; } # escape (quote) quotes using a back slash (\)
QuoteSpaces() { GetArgs; echo -E "$@" | sed 's/ /\\ /g'; } # escape (quote) spaces using a back slash (\)
RemoveQuotes() { sed 's/^\"//g ; s/\"$//g'; }
RemoveParens() { tr -d '()'; }
ReplaceString() { GetArgs3; echo "${1//$2/$3}"; } # ReplaceString TEXT STRING REPLACEMENT 
BackToForwardSlash() { GetArgs; echo "${@//\\//}"; }
ForwardToBackSlash() { GetArgs; echo -E "$@" | sed 's/\//\\/g'; }
RemoveBackslash() { GetArgs; echo "${@//\\/}"; }
UnQuoteQuotes() { GetArgs; echo "$@" | sed 's/\\\"/\"/g'; } # remove backslash before quotes

GetWordUsage() { (( $# == 2 || $# == 3 )) && IsInteger "$2" && return 0; EchoWrap "Usage: GetWord STRING|- WORD [DELIMITER](-) - 1 based"; return 1; }

if IsZsh; then
	GetAfter() { GetArgs2; echo "$1" | cut -d"$2" -f2-; } # GetAfter STRING CHAR - get all text in STRING after the first CHAR
	LowerCase() { GetArgs; [[ $# == 0 ]] && { tr '[:upper:]' '[:lower:]'; return; }; r "${1:l}" $2; }
	ProperCase() { GetArgs; r "${(C)1}" $2; }
	UpperCase() { GetArgs; echo "${(U)1}"; }
	UpperCaseFirst() { GetArgs; echo "${(U)1:0:1}${1:1}"; }

	GetWord()
	{
		GetArgDash; GetWordUsage "$@" || return
		local gwa gw="$1" word="$2" delimiter="${3:- }"; gwa=( "${(@ps/$delimiter/)gw}" ); printf "${gwa[$word]}"
	}

else
	GetAfter() { GetArgs2; [[ "$1" =~ ^[^$2]*$2(.*)$ ]] && echo "${BASH_REMATCH[1]}"; } # GetAfter STRING CHAR - get all text in STRING after the first CHAR
	LowerCase() { GetArgs; [[ $# == 0 ]] && { tr '[:upper:]' '[:lower:]'; return; }; r "${1,,}" $2; }
	ProperCase() { GetArgs; local arg="${1,,}"; r "${arg^}" $2; }
	UpperCase() { GetArgs; echo "${1^^}"; }
	UpperCaseFirst() { GetArgs; echo "${1^}"; }

	GetWord() 
	{ 
		GetArgDash; GetWordUsage "$@" || return; 
		local word=$(( $2 + 1 )); local IFS=${3:- }; set -- $1; 
		((word-=1)); (( word < 1 || word > $# )) && printf "" || printf "${!word}"
	}

fi

# time
ShowTime() { ${G}date '+%F %T.%N %Z' -d "$1"; }
ShowSimpleTime() { ${G}date '+%D %T' -d "$1"; }
TimestampDiff () { ${G}printf '%s' $(( $(${G}date -u +%s) - $(${G}date -u -d"$1" +%s))); }

# timer
TimerOn() { startTime="$(${G}date -u '+%F %T.%N %Z')" timerSplit=0 timerOn="true"; }
TimerSplit() { (( timerSplit++ )); printf "split $timerSplit: "; TimerOff; }
TimerStatus() { s=$(TimestampDiff "$startTime"); printf "%02dh:%02dm:%02ds\n" $(( $s/60/60 )) $(( ($s/60)%60 )) $(( $s%60 )); }
TimerOff() { TimerStatus; unset -v timerOn; }

# TimeCommand - return the time it takes to execute a command in seconds to three decimal places.
# Command output is supressed.  The status of the command is returned.
if IsZsh; then
	TimeCommand() { { time (command "$@" >& /dev/null); } |& cut -d" " -f9; return $pipestatus[1]; }
else
	TimeCommand() { TIMEFORMAT="%3R"; time (command "$@" >& /dev/null) 2>&1; }
fi

#
# File System
#

CanWrite() { [[ -w "$1" ]]; }
CopyFileProgress() { rsync --info=progress2 "$@"; }
DirCount() { local result; result="$(command ls "${1:-.}" |& wc -l)"; ! IsNumeric "$result" && result="0"; RemoveSpace "$result"; }
DirSave() { [[ ! $1 ]] && set -- "$TEMP"; pushd "$@" > /dev/null; }
DirRestore() { popd "$@" > /dev/null; }
EnsureDir() { GetArgs; echo "$(RemoveTrailingSlash "$@")/"; }
GetBatchDir() { GetFilePath "$0"; }
GetDirs() { [[ ! -d "$1" ]] && return; find "$1" -maxdepth 1 -type d -not -path "$1"; }
GetFileDateStamp() { ${G}date '+%Y%m%d' --reference "$1"; }
GetFileExtension() { GetArgs; local gfe="$1"; GetFileName "$gfe" gfe; [[ "$gfe" == *"."* ]] && r "${gfe##*.}" $2 || r "" $2; }
GetFileHash() { sha1sum "$1" | cut -d" " -f1; }
GetFileMod() { ${G}stat --format="%y" "$1"; }
GetFileModSeconds() { ${G}date +%s --reference "$1"; }
GetFileModTime() { ShowSimpleTime "@$(GetFileModSeconds "$1")"; }
GetFileSize() { GetArgs; [[ ! -e "$1" ]] && return 1; local size="${2-MB}"; [[ "$size" == "B" ]] && size="1"; s="$(${G}du --apparent-size --summarize -B$size "$1" |& cut -f 1)"; echo "${s%%*([[:alpha:]])}"; } # FILE [SIZE]
GetFilePath() { GetArgs; local gfp="${1%/*}"; [[ "$gfp" == "$1" ]] && gfp=""; r "$gfp" $2; }
GetFileName() { GetArgs; r "${1##*/}" $2; }
GetFileNameWithoutExtension() { GetArgs; local gfnwe="$1"; GetFileName "$1" gfnwe; r "${gfnwe%.*}" $2; }
GetFileTimeStamp() { ${G}date '+%Y%m%d_%H%M%S' --reference "$1"; }
GetFileTimeStampPretty() { ${G}date '+%Y-%m-%d %H:%M:%S' --reference "$1"; }
GetFullPath() { GetArgs; local gfp="$(GetRealPath "${@/#\~/$HOME}")"; r "$gfp" $2; } # replace ~ with $HOME so we don't lose spaces in expansion
GetLastDir() { GetArgs; echo "$@" | RemoveTrailingSlash | GetFileName; }
GetParentDir() { GetArgs; echo "$@" | GetFilePath | GetFilePath; }
FileExists() { local f; for f in "$@"; do [[ ! -f "$f" ]] && return 1; done; return 0; }
FileExistsAny() { local f; for f in "$@"; do [[ -f "$f" ]] && return 0; done; return 1; }
HasFilePath() { GetArgs; [[ $(GetFilePath "$1") ]]; }
IsDirEmpty() { GetArgs; [[ "$(${G}find "$1" -maxdepth 0 -empty)" == "$1" ]]; }
InPath() { local f option; IsZsh && option="-p"; for f in "$@"; do ! which $option "$f" >& /dev/null && return 1; done; return 0; }
InPathAny() { local f option; IsZsh && option="-p"; for f in "$@"; do which $option "$f" >& /dev/null && return; done; return 1; }
IsFileSame() { [[ "$(GetFileSize "$1" B)" == "$(GetFileSize "$2" B)" ]] && diff "$1" "$2" >& /dev/null; }
IsPath() { [[ ! $(GetFileName "$1") ]]; }
IsWindowsFile() { drive IsWin "$1"; }
IsWindowsLink() { ! IsPlatform win && return 1; lnWin -s "$1" >& /dev/null; }
RemoveTrailingSlash() { GetArgs; r "${1%%+(\/)}" $2; }

# FindAny DIR NAME [DEPTH](1) - find NAME (supports wildcards) starting from DIR for max of DEPTH directories
FindAny()
{
	local dir="$1" name="$2"; shift 2
	local depth="1"; IsInteger "$1" && { depth="$1"; shift; }
	[[ ! -d "$dir" ]] && return 1
	"${G}find" "$dir" -maxdepth "$depth" -name "$name" "$@" | "${G}grep" "" # grep returns error if nothing found
}

FindDir() { FindAny "${@:1:3}" -type d; }
FindFile() { FindAny "${@:1:3}" -type f; }

# (p)fpc - (platform) full path to clipboard
fpc() { local arg; [[ $# == 0 ]] && arg="$PWD" || arg="$(GetRealPath "$1")"; echo "$arg"; clipw "$arg"; } 
pfpc() { local arg; [[ $# == 0 ]] && arg="$PWD" || arg="$(GetRealPath "$1")"; clipw "$(utw "$arg")"; }

# CloudGet [--quiet] FILE... - force files to be downloaded from the cloud and return the file
# - mac: beta v166.3.2891+ triggers download of online-only files on move or copy
# - wsl: reads of the file do not trigger online-only file download in Dropbox
CloudGet()
{
	! IsPlatform win && return

	# arguments
	local file files=() quiet verbose verboseLevel verboseLess

	while (( $# != 0 )); do
		case "$1" in "") : ;;
			--quiet|-q) quiet="--quiet";;
			--verbose|-v|-vv|-vvv|-vvvv|-vvvvv) ScriptOptVerbose "$1";;
			-*) UnknownOption "$1" "CloudGet"; return 1;;
			*) files+=("$1"); shift; continue
		esac
		shift
	done

	for file in "${files[@]}"; do
		[[ $verbose ]] && EchoErr "CloudGet: processing '$file'"

		# directory
		if [[ -d "$file" ]]; then
			local newFiles=(); IFS=$'\n' ArrayMake newFiles "$(find "$file" -type f)"
			CloudGet $quiet $verbose "${newFiles[@]}" || return
			continue
		fi

		# ensure we have a file
		ScriptFileCheck "$file" || return

		# check if downloaded by checking blocks, does not work for small files
		local blocks="$(stat -c%b "$file")"
		[[ $verbose ]] && EchoErr "CloudGet: blocks=$blocks"
		((  $blocks > 0 )) && continue 	

		# check if downloaded by checking for one line
		local lines="$(wc --lines "$file" | cut -d" " -f1)"
		[[ $verbose ]] && EchoErr "CloudGet: lines=$lines"
		[[ "$lines" != "0" ]] && continue 		

		# download file
		[[ ! $quiet ]] && echo "Downloading file '$(GetFileName "$file")'..."
		( { ! HasFilePath "$file" || cd "$(GetFilePath "$file")"; } && cmd.exe /c type "$(GetFileName "$file")"; ) >& /dev/null || return

	done
}

explore() # explorer DIR - explorer DIR in GUI program
{
	local dir="$1"; [[ ! $dir ]] && dir="."

	IsPlatform mac && { open "$dir"; return; }
	IsPlatform wsl1 && { RunWin explorer.exe "$(utw "$dir")"; return; }
	IsPlatform wsl2 && { RunWin explorer.exe "$(utw "$dir")"; return 0; }
	InPath nautilus && { start nautilus "$dir"; return; }
	InPath mc && { mc; return; } # Midnight Commander

	EchoErr "The $(PlatformDescription) platform does not have a file explorer"; return 1
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

# FileCommand mv|cp|ren SOURCE... DIRECTORY - mv or cp files, ignore files that do not exist
FileCommand() 
{ 
	local command="$1"; shift
	local args=() files=() dir

	# arguments - ignore files that do not exist
	while (( $# > 1 )); do
		IsOption "$1" && args+=("$arg")
		[[ -e "$1" ]] && files+=("$1")
		shift
	done
	dir="$1" # last argument
	[[ ! $command ]] && { MissingOperand "command" "FileCommand"; return 1; }
	[[ ! $dir ]] && { MissingOperand "dir" "FileCommand"; return 1; }
	[[ ! "$command" =~ ^(cp|mv|ren)$ ]] && { ScriptErr "unknown command '$command'" "FileCommand"; return 1; }
	[[ ! $files ]] && return 0
	
	[[ ! -d "$dir" ]] && { ${G}mkdir --parents "$dir" || return; }

	# command
	case "$command" in
		ren) 'mv' "${args[@]}" "${files[@]}" "$dir";;
		cp|mv)
			[[ ! -d "$dir" ]] && { EchoErr "FileCommand: accessing '$dir': No such directory"; return 1; }
			${G}"$command" -t "$dir" "${args[@]}" "${files[@]}"
			;;		
	esac
}

# FileGetProcessesUsing FILE - get the processes using a file
FileGetProcessesUsing()
{
	local file="$1"

	IsPlatform wsl1 && return

	if IsPlatform mac; then
		fuser "$file" |& cut -d":" -f2 | sed "s/[cefFrm]//g" |  tr -s " " | RemoveSpaceFront
	else
		sudoc fuser -c "$file" |& cut -d":" -f2 | sed "s/[cefFrm]//g" |  tr -s " " | RemoveSpaceFront
	fi
}

# FileGetUnc FILE - get the UNC path for the file, faster than calling unc get unc
FileGetUnc()
{
	local file="$1"; [[ ! -e "$file" ]] && return 1
	
	! InPath findmnt && { unc get unc --quiet "$file"; return; }

	local parts; parts="$(findmnt --target="$file" --output=SOURCE,TARGET --types=cifs,drvfs,nfs,nfs4,fuse.sshfs --noheadings)" || return
	local source="$(GetWord "$parts" 1)" target="$(GetWord "$parts" 2)"	
	[[ ! $source || ! $target ]] && return 1
	echo "${file/$target/$source}"
}


# FileToDesc FILE - short description for the file
# - convert mounted volumes to UNC,i.e. //server/share
# - replace $HOME with ~, i.e. /home/CURRENT_USER/file -> ~/file
# - replace $USERS with ~, i.e. /home/OTHER_USER/file -> ~OTHER_USER/file
FileToDesc() 
{
	GetArgs
	local file="$1"; [[ ! $1 ]] && return

	# if the file is a UNC mounted share get the UNC format
	local unc; unc="$(FileGetUnc "$file")" && file="$unc"

	# remove the server DNS suffix from UNC paths
	IsUncPath "$file" && file="//$(GetUncServer "$file" | RemoveDnsSuffix)/$(GetUncShare "$file")/$(GetUncDirs "$file")"

	# replace $HOME with ~, $USERS/ with ~
	if IsZsh; then
		file="${file/#${HOME}/~}"
		file="${file/#$USERS\//~}"
	else
		file="${file/#${HOME}/\~}"
		file="${file/#$USERS\//\~}"
	fi

	[[ "$file" != "/" ]] && file="$(RemoveTrailingSlash "$file")"

	echo "$file"
}

# FileWait [-q|--quiet]  FILE [SECONDS](60) - wait for a file or directory to exist
# -p|--path		wait for the file to be in the path
FileWait()
{
	# arguments
	local file noCancel pathFind quiet sudo timeoutSeconds

	while (( $# != 0 )); do
		case "$1" in "") : ;;
			--no-cancel|-nc) noCancel="true";;
			--path|-p) pathFind="true";;
			--quiet|-q) quiet="true";;
			--sudo|-s) sudo="sudoc";;
			*)
				! IsOption "$1" && [[ ! $file ]] && { file="$1"; shift; continue; }
				! IsOption "$1" && [[ ! $timeoutSeconds ]] && { timeoutSeconds="$1"; shift; continue; }
				UnknownOption "$1" "FileWait"; return 1
		esac
		shift
	done
	[[ ! $file ]] && { MissingOperand "file" "FileWait"; return 1; }
	timeoutSeconds="${timeoutSeconds:-60}"
	! IsInteger "$timeoutSeconds" && { ScriptErr "seconds '$timeoutSeconds' is not an integer"; return 1; }

	# variables
	local dir="$(GetFilePath "$(GetFullPath "$file")")" fileName="$(GetFileName "$file")" fileDesc="$(FileToDesc "$file")"
	
	# find command
	local find=(FindAny "$dir" "$fileName")
	if [[ $pathFind ]]; then find=(InPath "$file")
	elif [[ $sudo ]]; then find=($sudo ls "$file")
	fi
	"${find[@]}" >& /dev/null && return

	# wait
	[[ ! $quiet ]] && PrintErr "Waiting $timeoutSeconds seconds for '$fileDesc'..."
	for (( i=1; i<=$timeoutSeconds; ++i )); do
		"${find[@]}" >& /dev/null && { [[ ! $quiet ]] && EchoErrEnd "found"; return 0; }
		if [[ $noCancel ]]; then
			sleep 1
		else
			ReadChars 1 1 && { [[ ! $quiet ]] && EchoErrEnd "cancelled after $i seconds"; return 1; }
		fi
		[[ ! $quiet ]] && PrintErr "."
		
	done

	[[ ! $quiet ]] && EchoErrEnd "not found"; return 1
}

# FileWait FILE [SECONDS](60) - wait for a file or directory to be deleted
# - useful if inotifywait is not available or cannot be used (gio mounts)
FileWaitDelete()
{
	# arguments
	local file="$1" timeoutSeconds="${2:-60}" i ii

	for (( i=1; i<=$timeoutSeconds; ++i )); do
		for  (( ii=1; ii<=10; ++ii )); do
			[[ ! -e "$file" ]] && return
			${G}sleep .1
		done	
	done

	return 1
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
	# use --canonicalize-missing so directory existence is not checked (which can error out for mounted network volumes)
	InPath ${G}realpath && { ${G}realpath --canonicalize-missing "$1"; return; }

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
	[[ ! $1 || ! $2 ]] && { EchoWrap "Usage: MoveAll SRC DEST"; return 1; }
	shopt -s dotglob nullglob
	mv "$1/"* "$2" && rmdir "$1"
}

InfoPathAdd() { for f in "$@"; do [[ -d "$f" && ! $INFOPATH =~ (^|:)$f(:|$) ]] && INFOPATH="${INFOPATH+$INFOPATH:}$f"; done; }
ManPathAdd() { for f in "$@"; do [[ -d "$f" && ! $MANPATH =~ (^|:)$f(:|$) ]] && MANPATH="${MANPATH+$MANPATH:}$f"; done; }	

PathAdd() # PathAdd [front] DIR...
{
	local front; [[ "$1" == "front" ]] && front="true"

	for f in "$@"; do 
		[[ ! -d "$f" ]] && continue
		[[ $front ]] && { PATH="$f:${PATH//:$f:/:}"; continue; } # force to front
		[[ ! $PATH =~ (^|:)$f(:|$) ]] && PATH+=":$f" # add to back if not present
	done

	return 0
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
IsUnixPath() { [[ "$1" =~ '/' ]]; }
IsZsh && IsWindowsPath() { [[ "$1" =~ '\\' ]]; } || IsWindowsPath() { [[ "$1" =~ '\' ]]; }
utwq() { utw "$@" | QuoteBackslashes; } # UnixToWinQuoted
ptw() { printf "%s\n" "${1//\//"\\"}"; } # PathToWin - use printf so zsh does not interpret back slashes (\)

wtu() # WinToUnix
{
	GetArgs; local file="$1"; [[ ! $file ]] && { MissingOperand "FILE" "wtu"; return 1; }
	{ ! IsPlatform win || [[ ! "$file" ]] || IsUnixPath "$file"; } && { echo -E "$file"; return; }
  wslpath -u "$*"
}

utw() # UnixToWin
{	
	GetArgs; local clean="" file="$1"; [[ ! $file ]] && { MissingOperand "FILE" "utw"; return 1; } 
	{ ! IsPlatform win || [[ ! "$file" ]] || IsWindowsPath "$file"; } && { echo -E "$file"; return; }

	file="$(GetRealPath "$file")" || return

	# tranlate CIFS shares to UNC format in WSL 2 
	# - wslpath does not not translate UNC shares in WSL 2
	# - chheck for a CIFS share using findmnt directly for performance (instead of unc get unc "$file" --quiet)
	IsPlatform wsl2 && findmnt --target "$file" --output=SOURCE --types=cifs --noheadings >& /dev/null && { ptw "$(unc get unc "$file" --quiet)"; return; }

	# utw requires the file exist in newer versions of wsl
	if [[ ! -e "$file" ]]; then
		local filePath="$(GetFilePath "$file")"
		[[ ! -d "$filePath" ]] && { ${G}mkdir --parents "$filePath" >& /dev/null || return; }
		touch "$file" || return
		clean="true"
	fi

	wslpath -w "$file"

	[[ $clean ]] && { rm "$file" || return; }
	return 0
} 

# File Attributes

FileHide() { for f in "$@"; do [[ -e "$f" ]] && { attrib "$f" +h || return; }; done; return 0; }
FileTouchAndHide() { [[ ! -e "$1" ]] && { touch "$1" || return; }; FileHide "$1"; return 0; }
FileShow() { for f in "$@"; do [[ -e "$f" ]] && { attrib "$f" -h || return; }; done; return 0; }
FileHideAndSystem() { for f in "$@"; do [[ -e "$f" ]] && { attrib "$f" +h +s || return; }; done; return 0; }

# attrib FILE [OPTIONS] - set Windows file attributes, attrib.exe options must come after the file
attrib()
{ 
	! IsPlatform win && return
	
	local f="$1"; shift
	[[ ! -e "$f" ]] && { EchoErr "attrib: $f: No such file or directory"; return 2; }

	# ensure path is on a Windows drive
	local path; path="$(GetFilePath "$f")" || return
	{ [[ ! $path ]] || ! drive IsWin "$path"; } && return
	
	# /L flag changes target changed not link from WSL when full path specified
	# i.e. attrib.exe /l +h 'C:\Users\jjbutare\Documents\data\app\Audacity'
	( cd "$path"; attrib.exe "$@" "$(GetFileName "$f")" );
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
# IFS
#

IfsShow() { echo -n "$IFS" | ShowChars; }
IfsReset() { IFS=$' \t\n\0'; }
IfsSave() { ifsSave="$IFS"; IfsReset; }
IfsRestore() { IFS="$ifsSave"; }

#
# monitoring
#

# LogShow FILE [PATTERN] - show and follow a log file, optionally filtering for a pattern
LogShow()
{ 
	local sudo file="$1" pattern="$2"; [[ $pattern ]] && pattern=" $pattern"

	LineWrap "off"
	SudoCheck "$file"; $sudo ${G}tail -f "$1" | grep "$pattern"
	LineWrap "on"
}

# LogShowAll FILE [PATTERN] - show the entire log file, optionally starting a reverse search for pattern
LogShowAll()
{
	local sudo file="$1" pattern="$2"; [[ $pattern ]] && pattern="+?$pattern"
	SudoCheck "$file"; $sudo less $pattern "$file"
}

# FileWatch FILE [PATTERN] - watch a whole file for changes, optionally for a specific pattern
FileWatch() { local sudo; SudoCheck "$1"; cls; $sudo ${G}tail -F --lines=+0 "$1" | grep "$2"; }

#
# network
#

NETWORK_CACHE="network" NETWORK_CACHE_OLD="network-old"

GetPorts() { sudoc lsof -i -P -n; }
GetDefaultGateway() { CacheDefaultGateway "$@" && echo "$NETWORK_DEFAULT_GATEWAY"; }	# GetDefaultGateway - default gateway
GetDomain() { UpdateNeeded "domain" && UpdateSet "domain" "$(network domain name)"; UpdateGetForce "domain"; }
GetMacAddress() { grep -i " ${1:-$HOSTNAME}$" "/etc/ethers" | cut -d" " -f1; }				# GetMacAddress - MAC address of the primary network interface
GetHostname() { SshHelper connect "$1" -- hostname; } 																# GetHostname NAME - hosts actual configured name
GetOsName() { local name="$1"; name="$(UpdateGet "os-name-$1")"; [[ $name ]] && echo "$name" || os name "$server"; } # GetOsName NAME - use cached DNS name without calling os for speed
HostAvailable() { IsAvailable "$@" && return; ScriptErrQuiet "host '$1' is not available"; }
HostUnknown() { ScriptErr "$1: Name or service not known" "$2"; }
HostUnresolved() { ScriptErr "Could not resolve hostname $1: Name or service not known" "$2"; }
HttpHeader() { curl --silent --show-error --location --dump-header - --output /dev/null "$1"; }
IpFilter() { grep "$@" --extended-regexp '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}'; }
IsHostnameVm() { [[ "$(GetWord "$1" 1 "-")" == "$(os name)" ]]; } 										# IsHostnameVm NAME - true if name follows the virtual machine syntax HOSTNAME-name
IsIpInCidr() { ! InPath nmap && return 1; nmap -sL -n "$2" | grep --quiet " $1$"; }		# IsIpInCidr IP CIDR - true if IP belongs to the CIDR, i.e. IsIpInCidr 10.10.100.10 10.10.100.0/22
NetworkCurrent() { UpdateGetForce "$NETWORK_CACHE"; }; 																# NetworkCurrent - configured current network
NetworkOld() { UpdateGetForce "$NETWORK_CACHE_OLD"; }; 																# NetworkOld - the previous network
PortScan() { local args=(); IsPlatform win && [[ ! $1 ]] && args+=(-Pn); nmap "${1:-localhost}" "${args[@]}" "$@"; }
RemovePort() { GetArgs; echo "$1" | cut -d: -f 1; }															# RemovePort NAME:PORT - returns NAME
SmbPasswordIsSet() { sudoc pdbedit -L -u "$1" >& /dev/null; }										# SmbPasswordIsSet USER - return true if the SMB password for user is set
UrlExists() { curl --output /dev/null --silent --head --fail "$1"; }						# UrlExists URL - true if the specified URL exists
WifiNetworks() { sudo iwlist wlan0 scan | grep ESSID | cut -d: -f2 | RemoveQuotes | RemoveEmptyLines | sort | uniq; }

# curl
curl()
{
	local file="/opt/homebrew/opt/curl/bin/curl"
	IsPlatform mac && [[ -f "$file" ]] && { "$file" "$@"; return; }
	command curl "$@"; return
}

# proxy
ProxyEnable() { ScriptEval network proxy vars --enable; network proxy vars --status; }
ProxyDisable() { ScriptEval network proxy vars --disable; network proxy vars --status; }
ProxyStatus() { network proxy --status; }

# GetDns - get DNS informationm for the computer, or the network the computer is in
GetDnsDomain() { echo "$(ConfigGet "$(GetDomain)DnsDomain")"; }
GetDnsBaseDomain() { echo "$(ConfigGet "$(GetDomain)DnsBaseDomain")"; }
GetNetworkDnsDomain() { echo "$(ConfigGet "$(NetworkCurrent)DnsDomain")"; }
GetNetworkDnsBaseDomain() { echo "$(ConfigGet "$(NetworkCurrent)DnsBaseDomain")"; }

# GetRoute host - get the interface used to send to host
GetRoute()
{
	local host="${1:-"0.0.0.0"}"
	if IsPlatform mac; then route -n get $host | grep interface | cut -d":" -f2 | RemoveSpaceTrim
	else ip route show to match $host | cut -d" " -f5
	fi
}

NetworkConf()
{
	local force forceLevel forceLess; ScriptOptForce "$@"
	local verbose verboseLevel verboseLess; ScriptOptVerbose "$@"

	# return if network configuration is set
	[[ ! $force && $NETWORK_CHECKED ]] && return

	# configure network
	(( verboseLevel > 1 )) && header "Network Configuration"
	NetworkCurrentUpdate "$@" && NETWORK_CHECKED="true"
}

CacheDefaultGateway()
{
	local force forceLevel forceLess; ScriptOptForce "$@"

	[[ ! $force && $NETWORK_DEFAULT_GATEWAY ]] && return

	if IsPlatform win; then
		local g="$(RunWin route.exe -4 print | RemoveCarriageReturn | grep ' 0.0.0.0 ' | head -1 | awk '{ print $3; }')" || return
	elif IsPlatform mac; then
		local g="$(netstat -rnl | grep '^default' | ${G}grep -v "ppp" | head -1 | awk '{ print $2; }')" || return
	else
		local g="$(route -n | grep '^0.0.0.0' | head -1 | awk '{ print $2; }')" || return
	fi

	export NETWORK_DEFAULT_GATEWAY="$g"
}

# DhcpRenew ADDRESS(primary) - renew the IP address of the specified adapter
DhcpRenew()
{
	local adapter="$1";  [[ ! $adapter ]] && adapter="$(GetAdapterName)"
	local oldIp="$(GetAdapterIpAddress "$adapter")"

	if IsPlatform win; then
		RunWin ipconfig.exe /release "$adapter" || return
		RunWin ipconfig.exe /renew "$adapter" || return
		echo

	elif IsPlatform linux && InPath dhclient; then
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
	local ip
	if [[ $isWin ]]; then

		if [[ ! $adapter ]]; then
			# - use default route (0.0.0.0 destination) with lowest metric
			# - Windows build 22000.376 adds "Default " route
			RunWin route.exe -4 print | RemoveCarriageReturn | grep ' 0.0.0.0 ' | grep -v "Default[ ]*$" | sort -k5 --numeric-sort | head -1 | awk '{ print $4; }'
		else
			RunWin ipconfig.exe | RemoveCarriageReturn | grep -E "Ethernet adapter $adapter:|Wireless LAN adapter $adapter:" -A 9 | grep "IPv4 Address" | head -1 | cut -d: -f2 | RemoveSpace
		fi

	elif InPath ifdata; then
		ip="$(ifdata -pa "$adapter")" || return
		[[ "$ip" == "NON-IP" ]] && { ScriptErr "interface '$adapter' does not have an IPv4 address"; return 1; }
		echo "$ip"

	elif IsPlatform entware; then
		ifconfig "$adapter" | grep inet | grep -v 'inet6|127.0.0.1' | head -n 1 | awk '{ print $2 }' | cut -d: -f2

	else
		ifconfig "$adapter" | grep inet | grep -v 'inet6|127.0.0.1' | head -n 1 | awk '{ print $2 }'

	fi
}

# GetMacAddress [ADAPTER](primary) - get the MAC address of the specified network adapter
GetAdapterMacAddress()
{
	local adapter wsl; 

	# options
	while (( $# != 0 )); do
		case "$1" in "") : ;;
			-w|--wsl) wsl="--wsl";;
			*)
				if ! IsOption "$1" && [[ ! $adapter ]]; then adapter="$1"
				else UnknownOption "$1" "GetAdapterMacAddress"; return
				fi
		esac
		shift
	done

	# for Windows determine if we want the MAC address of a Windows or WSL adapter
	local isWin; IsPlatform win && [[ ! $wsl ]] && isWin="true"

	# get the primary adapter name
	if [[ ! $adapter ]]; then
		if [[ $isWin ]]; then
			adapter="$(GetAdapterName)" || return
		else
			adapter="$(GetInterface)" || return
		fi
	fi

	# get the MAC address of the specified adapter
	if [[ $isWin ]]; then
		RunWin ipconfig.exe /all | RemoveCarriageReturn | grep -E "Ethernet adapter $adapter:|Wireless LAN adapter $adapter:" -A 9 | \
			grep "^[ ]*Physical Address" | head -1 | cut -d: -f2 | RemoveSpace | LowerCase | sed 's/-/:/g'
	else
		ifconfig "$adapter" | grep "^[ ]*ether " | RemoveSpaceFront | cut -d" " -f2
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
		ifconfig "$(GetInterface)" | head -2 | ${G}tail --lines=-1 | awk '{ print $6; }'
	fi
}

GetEthernetAdapters()
{
	if IsPlatform win; then
		RunWin ipconfig.exe /all | grep -e "^Ethernet adapter" | cut -d" " -f3- | cut -d: -f1	
	elif IsPlatform mac; then 
		netstat -rn | grep '^default' | awk '{ print $4; }' | grep -v '^utun' # utunN - IPv6 adapters
	else
		ip -4 -oneline -br address | cut -d" " -f 1
	fi
}

# GetEthernetAdapterInfo - get information about all ethernet adapters
GetEthernetAdapterInfo()
{
	local adapter adapters dns ip; adapters=( $(GetEthernetAdapters | sort) ) || return

	{
		hilight "adapter-IP Address-DNS Name"

		for adapter in "${adapters[@]}"; do
			[[ "$adapter" == @(lo|docker*|br-*) ]] && continue
			ip="$(GetAdapterIpAddress "$adapter")" || return
			dns="$(DnsResolve "$ip" | NewlineToComma | RemoveEnd ",")" || dns="unknown"
			echo "${RESET}${RESET}$adapter-$ip-$dns" # add resets to line up the columns
		done
	} | column -c $(tput cols -T "$TERM") -t -s-
}

# GetInterface - name of the primary network interface
GetInterface()
{
	if IsPlatform mac; then netstat -rn | grep '^default' | head -1 | awk '{ print $4; }'
	else route | grep "^default" | head -1 | tr -s " " | cut -d" " -f8
	fi
}

# GetIpAddress [HOST] - get the IP address of the current or specified host
# -a|--all 						resolve all addresses for the host, not just the first
# -ra|--resolve-all 	resolve host using all methods (DNS, MDNS, and local virtual machine names)
# -m|--mdns						resolve host using MDNS
# -v|--vm 						resolve host using local virtual machine names (check $HOSTNAME-HOST)
# -w|--wsl						get the IP address used by WSL (Windows only)
# test cases: 10.10.100.10 web.service pi1 pi1.butare.net pi1.hagerman.butare.net
GetIpAddress() 
{
	# arguments
	local host mdns quiet vm wsl all=(head -1) 

	while (( $# != 0 )); do
		case "$1" in "") : ;;
			--all|-a) all=(cat);;
			--resolve-all|-ra) mdsn="true" vm="true";;
			--mdns|-m) mdns="true";;
			--quiet|-q) quiet="true";;
			--vm|-v) vm="true";;
			--wsl|-w) wsl="--wsl";;
			*)
				! IsOption "$1" && [[ ! $host ]] && { host="$(GetSshHost "$1")"; shift; continue; }
				UnknownOption "$1" "GetIpAddress"; return 1
		esac
		shift
	done

	local ip server

	# IP address
	IsIpAddress "$host" && { echo "$host"; return; }

	# localhost
	IsLocalHost "$host" && { GetAdapterIpAddress $wsl; return; }

	# SSH configuration
	host="$(SshHelper config get "$host" hostname)" || return

	# /etc/hosts
	[[ $host ]] && IsFunction getent && ip="$(getent hosts "$host")" && { echo "$ip" | cut -d" " -f1; return; }

	# Resolve mDNS (.local) names exclicitly as the name resolution commands below can fail on some hosts
	# In Windows WSL the methods below never resolve mDNS addresses
	IsMdnsName "$host" && { ip="$(MdnsResolve "$host" 2> /dev/null)"; [[ $ip ]] && echo "$ip"; return; }

	# override the server if needed
	server="$(DnsAlternate "$host")"

	# lookup IP address using various commands
	# - -N 3 and -ndots=2 allow the default domain names for partial names like consul.service
	# - getent on Windows sometimes holds on to a previously allocated IP address.   This was seen with old IP address in a Hyper-V guest on test VLAN after removing VLAN ID) - host and nslookup return new IP.
	# - dnscachutil -q host -a name HOST - query macOS system resolvers, ensure get hosts on VPN network as /etc/resolv.conf does not always update wit the VPN nameservers
	# - host and getent are fast and can sometimes resolve .local (mDNS) addresses 
	# - host is slow on wsl 2 when resolv.conf points to the Hyper-V DNS server for unknown names
	# - nslookup is slow on mac if a name server is not specified
	if [[ ! $server ]] && InPath getent; then ip="$(getent ahostsv4 "$host" |& grep "STREAM" | "${all[@]}" | cut -d" " -f 1)"
	elif [[ ! $server ]] && IsPlatform mac; then ip="$(dscacheutil -q host -a name "$host" |& grep "^ip_address:" | cut -d" " -f2 | ${G}head -1)"
	elif InPath host; then ip="$(host -N 2 -t A -4 "$host" $server |& ${G}grep -v "^ns." | grep "has address" | "${all[@]}" | cut -d" " -f 4)"
	elif InPath nslookup; then ip="$(nslookup -ndots=2 -type=A "$host" $server |& ${G}tail --lines=+4 | grep "^Address:" | "${all[@]}" | cut -d" " -f 2)"
	fi

	# if an IP address was not found, check for a local virtual hostname
	[[ ! $ip && $vm ]] && ip="$(GetIpAddress --quiet "$HOSTNAME-$host")"

	# resolve using .local only if --all is specified to avoid delays
	[[ ! $ip && $mdns ]] && ip="$(MdnsResolve "${host}.local" 2> /dev/null)"

	# return
	[[ ! $ip ]] && { [[ ! $quiet ]] && HostUnresolved "$host"; return 1; }
	echo "$(echo "$ip" | RemoveCarriageReturn)"
}

GetSubnetMask() { ifconfig "$(GetInterface)" | grep "netmask" | tr -s " " | cut -d" " -f 5; }
GetSubnetNumber() { ip -4 -oneline -br address show "$(GetInterface)" | cut -d/ -f2 | cut -d" " -f1 | RemoveSpaceTrim; }

# GetAdapterName [IP](primary) - get the descriptive name of the primary network adapter used for communication
GetAdapterName()
{
	local ip="$1"; [[ ! $ip ]] && { ip="$(GetAdapterIpAddress)" || return; }

	if IsPlatform win; then
		RunWin ipconfig.exe | grep "$ip" -B 8 | grep " adapter" | awk -F adapter '{ print $2 }' | sed 's/://' | sed 's/ //' | RemoveCarriageReturn
	else
		GetInterface "$@"
	fi
}

# ipconfig [COMMAND] - show or configure network
ipconfig() { IsPlatform win && { RunWin ipconfig.exe "$@"; } || ip -4 -oneline -br address; }

# ipinfo - show network configuration
ipinfo()
{
	! IsPlatform win && { ip -4 -br address; return; }
	
	{
		local adapter adapters

		PrintErr "searching..."

		hilight "Name:IP"
		{
			local IFS=$'\n' adapters=( $(GetEthernetAdapters) )
			for adapter in "${adapters[@]}"; do
				local ip="$(GetAdapterIpAddress "$adapter")"
				echo "$adapter:$ip"
				PrintErr "."
			done
		} | sort

		EchoErr "done"
	} | column -c $(tput cols) -t -s: -n

}

# IsInDomain domain[,domain,...] - true if the computer is in one of the specified domains
# - if not domain is specified, return true if the computer is joined to a domain
IsInDomain()
{
	[[ ! $1 ]] && { network domain joined; return; }
	local domains; StringToArray "$(LowerCase "$1")" "," domains
	local domain="$(GetDomain)"; [[ ! $domain ]] && return 1
	IsInArray "$(GetDomain)" domains
}

IsDomainRestricted() { IsInDomain sandia; }
IsOnRestrictedDomain() { IsOnNetwork Sandia; }

# IsIpAddress IP - return true if the IP is a valid IPv4 address
IsIpAddress()
{
	GetArgs
  local ip="$1"
  [[ ! "$ip" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]] && return 1
	
  if IsZsh; then
  	ip=( "${(s/./)ip}" )
  	(( ${ip[1]}<=255 && ${ip[2]}<=255 && ${ip[3]}<=255 && ${ip[4]}<=255 ))
  else # zsh
  	IFS='.' read -a ip <<< "$ip"
  	(( ${ip[0]}<=255 && ${ip[1]}<=255 && ${ip[2]}<=255 && ${ip[3]}<=255 ))
  fi
}

# IsIpLocal - return true if the specified IP is reachable on the local network (check if host does not use the default gateway in 5 hops or less)
IsIpLocal()
{
	GetArgs
	local args=("-4"); IsPlatform mac && args=()
	! traceroute "${args[@]}" -m 5 "$1" |& sponge | ${G}grep --quiet "($(GetDefaultGateway))"
}

# IsLocalHost HOST - true if the specified host refers to the local host.  
#   - This is a fast check, so we assume this is the local host if the host is 
#     the same as the local hostname, and if the host DNS suffixes is specified 
#     it must match one of our DNS search domains.
#   - A slower more reliable check would resolve the host name and check if the returned
#     IP address matches one of our network adapters IP addresses.  This could be accomplished
#     using DnsResolve , GetEternetAdapters, GetAdapterIpAddress.  The call to DnsResolve 
#     would need to prevent recursion and not call IsLocalHost.
IsLocalHost()
{
	local host="$(RemoveSpace "$1" | LowerCase)"

	# host is empty, localhost, or the loopback address (127.0.0.1)
	[[ "$host" == "" || "$host" == "localhost" || "$host" == "127.0.0.1" ]] && return

	# if the name is different, this is not localhost
	local hostname="$(hostname | LowerCase)"
	[[ "$(RemoveDnsSuffix "$host")" != "$(RemoveDnsSuffix $hostname)" ]] && return 1

	# since the host name is the same, assume if there is no DNS suffix the host is localhost
	local suffix="$(GetDnsSuffix "$host")"; [[ ! $suffix ]] && return 0

	# since the host name is the same and has a DNS suffix, assume host is localhost if the DNS suffix matches one of our DNS search suffixes
	local search; search=( $(GetDnsSearch) ) || return
	IsInArray --case-insensitive "$suffix" search
}

# IsLocalHostIp HOST - true if the specified host refers to the local host.  Also check the IP address of the host.
IsLocalHostIp() { IsLocalHost "$1" || [[ "$(GetIpAddress "$1" --quiet)" == "$(GetIpAddress)" ]] ; }

# IsMacAddress MAC - return true if the MAC is a valid MAC address
IsMacAddress()
{
	local mac="$(UpperCase "$1")"; [[ ! $mac ]] && { MissingOperand "mac" "IsMacAddress"; return 1; }
	echo "$mac" | ${G}grep --extended-regexp --quiet '^([0-9A-F]{1,2}:){5}[0-9A-F]{1,2}$'
}

# IsOnNetwork network[,network,...] - return true if we are connected to one of the specified networks
IsOnNetwork()
{
	local network networks=(); StringToArray "$(LowerCase "$1")" "," networks
	local current; current="$(NetworkCurrent | LowerCase)" || return

	for network in "${networks[@]}"; do 
		[[ "$current" == "$network" ]] && return
	done

	return 1
}

IsStaticIp() { ! ip address show "$(GetInterface)" | grep "inet " | grep --quiet "dynamic"; }

# MacLookup HOST|IP... - resolve a host name or IP to a MAC address using the ARP table or /etc/ethers
# --detail|-d		displayed detailed information about the MAC address including all MAC, IP address, and 
#               DNS names.  Allows identification of the current host of a Virtual IP Addresses (VIP).
# --monitor|-m	monitor the host name or IP address for changes (useful for VIP failovers)
# --ethers|-e		resolve using /etc/ethers instead of the ARP table
# --quiet|-q		suppress error message where possible
# test: lb lb3 pi1
MacLookup() 
{
	local detail ethers host monitor quiet

	while (( $# != 0 )); do
		case "$1" in "") : ;;
			--detail|-d) detail="true";;
			--ethers|-e) ethers="true";;
			--monitor|-m) monitor="true";;
			--quiet|-q) quiet="true";;
			*) 
					IsOption "$1" && { UnknownOption "$1" "MacLookup"; return 1; }
					[[ ! $host ]] && host="$1" || { ExtraOperand "$1" "MacLookup"; return 1; }
					;;
		esac
		shift
	done

	[[ ! $host ]] && { MissingOperand "host" "MacLookup"; return 1; } 	

	# monitor
	if [[ $monitor ]]; then
		echo "Press any key to stop monitoring '$host'..."
		
		while true; do
			hilightp "$host: "; MacLookup --detail "$host" | ${G}tail --lines=+2 | tr -s " " | cut -d" " -f3 | cut -d"." -f1 | sort | NewlineToSpace; echo
			ReadChars 1 1 && return
		done
	fi

	# variables
	local mac macWin

	# resolve using /etc/ethers	
	if [[ $ethers ]]; then
		if InPath getent; then
			mac="$(getent ethers "$(RemoveDnsSuffix "$host")" | cut -d" " -f1 | sed 's/\b\(\w\)\b/0\1/g' | sort | uniq)" # sed pads zeros, i.e. 2:2 -> 02:02 
		else
			mac="$(grep " $(RemoveDnsSuffix "${host,,}")$" "/etc/ethers" | cut -d" " -f1)"
		fi
	# resolve using the ARP table
	else
		local ping="ping -c 1"; IsPlatform win && ping="ping.exe -n 1 -w 100"

		# populate the arp cache with the MAC address
		eval $ping "$host" >& /dev/null || { ScriptErrQuiet "unable to lookup the MAC address for '$host'" "MacResolve"; return 1; }

		# get the MAC address in Windows
		if IsPlatform win; then
			local ip; ip="$(GetIpAddress "$host")" || return
			macWin="$(RunWin arp.exe -a | grep "$ip" | tr -s " " | cut -d" " -f3 | ${G}tail --lines=-1)" || return
			mac="$(echo "$macWin" | sed 's/-/:/g')" || return # change - to :

		# get the MAC address - everything else
		else
			mac="$(arp "$host")" || return
			echo "$mac" | ${G}grep --quiet "no entry$" && { ScriptErrQuiet "no MAC address for '$host'" "MacResolve"; return 1; }
			local column=3; IsPlatform mac && column=4
			mac="$(echo "$mac" | tr -s " " | cut -d" " -f${column} | ${G}tail --lines=-1)"
		fi

	fi

	# check if got a mac
	[[ ! $mac ]] && { ScriptErrQuiet "unable to lookup the MAC address for '$host'" "MacResolve"; return 1; }

	# return the MAC address if not showing detail
	[[ ! $detail ]] && { echo "$mac"; return; }

	# get all IP addresses associated with the MAC address - more than one for a Virtual IP Address (VIP)
	local ips; 
	if IsPlatform win; then
		IFS=$'\n' ips=( $(RunWin arp.exe -a | command ${G}grep "$macWin" | tr -s " " | cut -d" " -f2 | sort | uniq) ) || return
	else
		IFS=$'\n' ips=( $(arp -a -n | command ${G}grep " $mac " | cut -d" " -f2 | RemoveParens | sort | uniq) ) || return
	fi

	{
		hilight "mac-IP Address-DNS Name"

		for ip in "${ips[@]}"; do
			dns="$(DnsResolve "$ip")"
			echo "${RESET}${RESET}$mac-$ip-$dns" # add resets to line up the columns
		done
	} | column -c $(tput cols -T "$TERM") -t -s-
}

# NetworkCurrentConfig - configure the shell with the current network configuration
NetworkCurrentConfig() { ScriptEval network vars proxy; HashiConf -ff; }

# NetworkCurrentUpdate - update the network configuration
NetworkCurrentUpdate()
{
	local force forceLevel forceLess; ScriptOptForce "$@"

	# show detail if forcing
	if [[ $force || ! $(NetworkCurrent) ]]; then
		network current update "$@" || return
		ScriptEval network vars proxy "$@" || return
	else
		ScriptEval network --quiet --update vars proxy "$@" || return
	fi
}

#
# network: host availability
#

AvailableTimeoutGet()
{
	local t="$(UpdateGet "hostTimeout")"; [[ ! $t ]] && t="$(ConfigGet "hostTimeout")"
	echo "${t:-200}"
}

AvailableTimeoutSet()
{
	[[ ! $1 ]] && { UpdateRm "hostTimeout"; return; }
	! IsInteger "$1" && { ScriptErr "'$1' is not an integer"; return 1; }
 	UpdateSet "hostTimeout" "$1" 
}

# IsAvailable HOST [TIMEOUT_MILLISECONDS] - returns true if the host is available
IsAvailable() 
{ 
	local host="$1" timeout="${2:-$(AvailableTimeoutGet)}"

	IsLocalHost "$host" && return 0

	# resolve the IP address explicitly:
	# - mDNS name resolution is intermitant (double check this on various platforms)
	# - Windows ping.exe name resolution is slow for non-existent hosts
	local ip; ip="$(GetIpAddress --quiet "$host")" || return

	if IsPlatform wsl1; then # WSL 1 ping does not timeout quickly for unresponsive hosts, ping.exe does
	  	RunWin ping.exe -n 1 -w "$timeout" "$ip" |& grep "bytes=" &> /dev/null 
	elif InPath fping; then
		fping -r 1 -t "$timeout" -e "$ip" &> /dev/null
	else
		ping -c 1 -W 1 "$ip" &> /dev/null # -W timeoutSeconds
	fi
}

# IsAvailableBatch HOST... -  return available hosts in parallel
IsAvailableBatch()
{
	if InPath parallel; then
		parallel -i bash -c '. function.sh && IsAvailable {} && echo {}' -- "$@"
	else
		local host; for host in "$@"; do IsAvailable "$host" && echo "$host"; done
	fi
	return 0
}

# IsPortAvailable HOST:PORT|HOST PORT [TIMEOUT_MILLISECONDS] - return true if the host is available on the specified TCP port
IsAvailablePort()
{
	local host="$1"; shift
	local port; [[ "$host" =~ : ]] && port="$(GetUriPort "$host")" host="$(GetUriServer "$host")" || { port="$1"; shift; }
	local timeout="${1-$(AvailableTimeoutGet)}"; host="$(GetIpAddress "$host" --quiet)" || return

	if InPath ncat; then
		ncat --exec "BOGUS" --wait ${timeout}ms "$host" "$port" >& /dev/null
	elif InPath nmap; then
		nmap "$host" -p "$port" -Pn -T5 |& grep -q "open" >& /dev/null
	elif IsPlatform win && InPath chkport-ip.exe; then
		RunWin chkport-ip.exe "$host" "$port" "$timeout" >& /dev/null
	else
		return 0 
	fi
}

# IsPortAvailableUdp HOST PORT [TIMEOUT_MILLISECONDS] - return true if the host is available on the specified UDP port
# --verbose - does not supress error message
IsAvailablePortUdp()
{
	# arguments
	local host port timeout verbose verboseLevel verboseLess

	while (( $# != 0 )); do
		case "$1" in "") : ;;
			--verbose|-v|-vv|-vvv|-vvvv|-vvvvv) ScriptOptVerbose "$1";;
			*)
				! IsOption "$1" && [[ ! $host ]] && { host="$1"; shift; continue; }
				! IsOption "$1" && [[ ! $port ]] && { port="$1"; shift; continue; }
				! IsOption "$1" && [[ ! $timeout ]] && { timeout="$1"; shift; continue; }
				UnknownOption "$1" "IsAvailablePortUdp"; return
		esac
		shift
	done
	[[ ! $host ]] && { MissingOperand "host" "IsAvailablePortUdp"; return 1; }
	[[ ! $port ]] && { MissingOperand "port" "IsAvailablePortUdp"; return 1; }
	[[ ! $timeout ]] && { timeout="$(AvailableTimeoutGet)"; }

	host="$(GetIpAddress "$host" --quiet)" || return

	local redirect=">& /dev/null"; [[ $verbose ]] && redirect=""

	if InPath nc; then # does not require root access
		timeout="$(( timeout / 1000 + 1 ))" # round up to nearest second
		eval nc -zvu "$host" "$port" -w "$timeout" $redirect
	elif InPath nmap; then
		eval sudoc -- nmap "$host" -p "$port" -Pn -T5 -sU |& grep --quiet "open" $redirect
	else
		return 0 
	fi
}

# PingResponse HOST [TIMEOUT_MILLISECONDS] - returns ping response time in milliseconds
PingResponse() 
{ 
	local host="$1" timeout="${2-$(AvailableTimeoutGet)}"; host="$(GetIpAddress "$host")" || return

	if InPath fping; then
		fping -r 1 -t "$timeout" -e "$host" |& grep " is alive " | cut -d" " -f 4 | tr -d '('
	else
		ping -c 1 -W 1 "$host" |& grep "time=" | cut -d" " -f 7 | tr -d 'time=' # -W timeoutSeconds
	fi
}

# PortResponse [--verbose] HOST PORT [TIMEOUT_MILLISECONDS] - return host port response time in milliseconds
PortResponse() 
{
	# arguments
	local host port timeout quiet verbose verboseLevel verboseLess

	while (( $# != 0 )); do
		case "$1" in "") : ;;
			--quiet|-q) quiet="--quiet";;
			--verbose|-v|-vv|-vvv|-vvvv|-vvvvv) ScriptOptVerbose "$1";;
			*)
				! IsOption "$1" && [[ ! $host ]] && { host="$1"; shift; continue; }
				! IsOption "$1" && [[ ! $port ]] && { port="$1"; shift; continue; }
				! IsOption "$1" && [[ ! $timeout ]] && { timeout="$1"; shift; continue; }
				UnknownOption "$1" PortResponse; return
		esac
		shift
	done
	[[ ! $host ]] && { MissingOperand "host" "PortResponse"; return 1; }
	[[ ! $port ]] && { MissingOperand "port" "PortResponse"; return 1; }
	[[ ! $timeout ]] && { timeout="$(AvailableTimeoutGet)"; }

	# test port
	local result host="$(GetIpAddress $quiet "$host")" || return

	if InPath ncat && [[ ! $verbose ]]; then
		result="$(TimeCommand ncat --exec "BOGUS" --wait ${timeout}ms "$host" "$port")" || return

	elif InPath nmap; then
		local result="$(nmap "$host" -p "$port" -Pn -T5)" || return
		! echo "$result" | grep --quiet "open" && { [[ ! $quiet ]] && ScriptErr "host '$host' port '$port' is not open" "PortResponse"; return 1; }

		# "Host is up (0.049s latency)."
		result="$(echo "$result" | grep "Host is up")" || { [[ ! $quiet ]] && ScriptErr "host '$host' is not up" "PortResponse"; return 1; }
		result="$(echo "$result" | RemoveBefore \( | cut -d"s" -f1)"
	
	else
		echo "0"; return 0 
	fi

	# validate
	! IsNumeric "$result" && { [[ ! $quiet ]] && ScriptErr "received an invalid response '$result' contacting host '$host' port '$port'" "PortResponse"; return 1; }

	# return
	echo "$result * 1000" | bc	
}

WaitForAvailable() # WaitForAvailable HOST [HOST_TIMEOUT_MILLISECONDS] [WAIT_SECONDS]
{
	local host="$1"; [[ ! $host ]] && { MissingOperand "host" "WaitForAvailable"; return 1; }
	local timeout="${2-$(AvailableTimeoutGet)}" seconds="${3-$(AvailableTimeoutGet)}"

	printf "Waiting $seconds seconds for $(RemoveDnsSuffix "$host")..."
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
	local timeout="${3-$(AvailableTimeoutGet)}" seconds="${4-$(AvailableTimeoutGet)}"
	
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
# network: DNS
#

AddDnsSuffix() { GetArgs2; HasDnsSuffix "$1" && echo "$1" || echo "$1.$2"; } 	# AddDnsSuffix HOST DOMAIN - add the specified domain to host if a domain is not already present
GetDnsSuffix() { GetArgs; ! HasDnsSuffix "$1" && return; printf "${@#*.}"; }	# GetDnsSuffix HOST - the DNS suffix of the HOST
HasDnsSuffix() { GetArgs; local p="\."; [[ "$1" =~ $p ]]; }										# HasDnsSuffix HOST - true if the specified host includes a DNS suffix

# GetDnsSearch - get the system DNS search domains
GetDnsSearch()
{
	local f="/etc/resolv.conf"; [[ ! -f "$f" ]] && return 1
	cat "$f" | grep "^search " | cut -d" " -f2-
}

# RemoveDnsSuffix HOST - remove the DNS suffix if present
RemoveDnsSuffix()
{
	GetArgs; [[ ! $1 ]] && return
	IsIpAddress "$1" && printf "$1" || printf "${@%%.*}"
}

#
# network: name resolution
#

# IsMdnsName NAME - return true if NAME is a local address (ends in .local)
IsMdnsName() { IsZsh && [[ "$1" =~ .*\\.local$ ]] || [[ "$1" =~ .*'.'local$ ]]; }

ConsulResolve() { hashi resolve "$@"; }

# DnsAlternate [HOST] - return an alternate DNS server for the host if it requires one
DnsAlternate()
{
	local host="$1"

	# hardcoded to check if connected on VPN from the Hagerman network to the DriveTime network (coeixst.local suffix) 
	if [[ ! $host || ("$host" =~ (^$|butare.net$) && "$(GetDnsSearch)" == "coexist.local") ]]; then
		echo "10.10.100.8" # butare.net primary DNS server
	fi

	return 0
}

# DnsResolve [--quiet|-q|--user-alternate|-ua] IP|NAME - resolve an IP address or host name to a fully qualified domain name
DnsResolve()
{
	local name quiet server useAlternate

	while (( $# != 0 )); do
		case "$1" in "") : ;;
			--quiet|-q) quiet="--quiet";;
			--use-alternate|-ua) useAlternate="--use-alternate";;
			*)
				if ! IsOption "$1" && [[ ! $name ]]; then name="$1"
				else UnknownOption "$1" "DnsResolve"; return 1
				fi
		esac
		shift
	done

	[[ ! $name ]] && { MissingOperand "host" "DnsResolve"; return 1; } 

	# localhost - use the domain in the configuration
	IsLocalHost "$name" && name=$(AddDnsSuffix "$HOSTNAME" "$(GetNetworkDnsDomain)")

	# override the server if needed
	if [[ $useAlternate ]]; then server="$(DnsAlternate)"; else server="$(DnsAlternate "$name")"; fi

	# Resolve name using various commands
	# - -N 3 and -ndotes=3 allow the default domain names for partial names like consul.service

	# reverse DNS lookup for IP Address
	local lookup
	if IsIpAddress "$name"; then

		if IsLocalHost "$name"; then lookup="localhost"
		elif [[ ! $server ]] && IsPlatform mac; then lookup="$(dscacheutil -q host -a ip_address "$name" | grep "^name:" | cut -d" " -f2)" || unset lookup
		elif InPath host; then lookup="$(host -t A -4 "$name" $server |& ${G}grep -E "domain name pointer" | ${G}cut -d" " -f 5 | RemoveTrim ".")" || unset lookup
		else lookup="$(nslookup -type=A "$name" $server |& ${G}grep "name =" | ${G}cut -d" " -f 3 | RemoveTrim ".")" || unset lookup
		fi

		# use alternate for Hagerman network IP addresses, reverse lookup fails on mac using VPN
		[[ ! $lookup && ! $useAlternate ]] && IsIpInCidr "$name" "10.10.100.0/22" && { DnsResolve --use-alternate $quiet "$name"; return; }

	# forward DNS lookup to get the fully qualified DNS address
	else
		if [[ ! $server ]] && InPath getent; then lookup="$(getent ahostsv4 "$name" |& ${G}head -1 | tr -s " " | ${G}cut -d" " -f 3)" || unset lookup
		elif [[ ! $server ]] && IsPlatform mac; then lookup="$(dscacheutil -q host -a name "$name" |& grep "^name:" | ${G}tail --lines=-1 | cut -d" " -f2)" || unset lookup # return the IPv4 name (the last name), dscacheutil returns ipv6 name first if present, i.e. dscacheutil -q host -a name "google.com"
		elif InPath host; then lookup="$(host -N 2 -t A -4 "$name" $server |& ${G}grep -v "^ns." | ${G}grep -E "domain name pointer|has address" | head -1 | cut -d" " -f 1)" || unset lookup
		elif InPath nslookup; then lookup="$(nslookup -ndots=2 -type=A "$name" $server |& ${G}tail --lines=-3 | ${G}grep "Name:" | ${G}cut -d$'\t' -f 2)" || unset lookup
		fi

	fi

	# error
	[[ ! $lookup ]] && { [[ ! $quiet ]] && HostUnresolved "$name"; return 1; }
	echo "$lookup"
}

# DnsResolveBatch - resolve IP addresses or names to fully qualified DNS names in parallel, uses the same options as DnsResolve
# - example: echo "10.10.100.1\n10.10.100.10" | DnsResolveBatch
DnsResolveBatch()
{
	local args=(); [[ $1 ]] && args=("$@")
	GetArgsPipe || return

	if InPath parallel; then
		local command=". function.sh && DnsResolve ${args[@]} {}" # command must be set first or ${args[@]} is not expanded properly
		parallel -i bash -c "$command" -- $@; 
	else
		local host; for host in "$@"; do DnsResolve "$host" "${args[@]}"; done
	fi
}

# DnsResolveMacBatch  - resolve mac addresses from standard input in parallel, uses the same options as DnsResolveMac
# example: echo "74:ac:b9:ed:8c:eb\ndc:a6:32:02:b5:34" | DnsResolveMacBatch
DnsResolveMacBatch()
{
	local args=(); [[ $1 ]] && args=("$@")
	GetArgsPipe || return

	if InPath parallel; then
		local command=". function.sh && DnsResolveMac ${args[@]} {}; echo" # command must be set first or ${args[@]} is not expanded properly
		parallel -i bash -c "$command" -- $@
	else
		local host; for host in "$@"; do DnsResolveMac "$host" "${args[@]}"; echo; done
	fi
}

# DnsResolveMac MAC... - resolve MAC addresses to DNS names using /etc/ethers
# --all|-a			show all names, even those that could not be resolved
# --errors|-e		keep processing if an error occurs, return the total number of errors
# --full|-f  		return a fully qualified domain name
# --quiet|-q		suppress error message where possible
DnsResolveMac()
{
	local all errors macs=() quiet full="cat"

	while (( $# != 0 )); do
		case "$1" in "") : ;;
			--all|-a) all="true";;
			--errors|-e) errors=0;;
			--full|-f) full="DnsResolveBatch";;
			--quiet|-q) quiet="true";;
			*)
					IsOption "$1" && { UnknownOption "$1" "DnsResolveMac"; return 1; }
					macs+=("$1")
					;;
		esac
		shift
	done

	[[ ! $macs ]] && { MissingOperand "mac" "DnsResolveMac"; return 1; } 	

	# validate
	local mac validMacs=()
	for mac in "${macs[@]}"; do
		IsMacAddress "$mac" && { validMacs+=("$mac"); continue; }
		ScriptErrQuiet "'$mac' is not a valid MAC address" "DnsResolveMac"
		[[ ! $errors ]] && return 1; (( ++errors ))
	done
	
	# lookup
	local name names=()
	for mac in "${validMacs[@]}"; do

		if InPath getent; then
			name="$(getent ethers "$mac" | cut -d" " -f2)"
		else
			name="$(grep -i "^${mac} " "/etc/ethers" | cut -d" " -f2)"
		fi	

		if [[ $name ]]; then
			names+=("$name")
		elif [[ $all ]]; then
			names+=("$mac")
		else
			ScriptErrQuiet "'$mac' was not found" "DnsResolveMac"
			[[ ! $errors ]] && return 1; (( ++errors ))
		fi

	done

	# show names
	[[ $names ]] && ArrayDelimit names $'\n' | $full; return $errors
}

DnsFlush()
{
	if IsPlatform mac; then sudoc dscacheutil -flushcache && sudo killall -HUP mDNSResponder
	elif IsPlatform win; then RunWin ipconfig.exe /flushdns >& /dev/null
	elif IsPlatform systemd && systemctl is-active systemd-resolved >& /dev/null; then resolvectl flush-caches
	fi
}

GetDnsServers()
{
	if [[ -f "/etc/resolv.conf" ]]; then cat "/etc/resolv.conf" | grep nameserver | cut -d" " -f2 | sort | uniq | NewlineToSpace | RemoveSpaceTrim
	elif IsPlatform mac; then scutil --dns | grep 'nameserver\[[0-9]*\]' | cut -d: -f2 | sort | uniq | RemoveNewline | RemoveSpaceTrim
	elif InPath resolvectl; then resolvectl status |& grep "DNS Servers" | head -1 | cut -d":" -f2 | RemoveSpaceTrim | SpaceToNewline | sort | uniq | NewlineToSpace | RemoveSpaceTrim # Ubuntu >= 22.04
	fi			
}

MdnsResolve()
{
	local name="$1" result; [[ ! $name ]] && MissingOperand "host" "MdnsResolve"

	{ [[ ! $name ]] || ! IsMdnsName "$name"; } && return 1

	# Currently WSL does not resolve mDns .local address but Windows does
	if InPath dns-sd.exe; then
		result="$(RunWin dns-sd.exe -timeout 200 -Q "$name" |& grep "$name" | head -1 | rev | cut -d" " -f1 | rev)"
	elif IsPlatform mac; then
		result="$(ping -c 1 -W 200 "$name" |& grep "bytes from" | gcut -d" " -f 4 | sed s/://)"
	elif InPath avahi-resolve-address; then
		result="$(avahi-resolve-address -4 -n "$name" | awk '{ print $2; }')"
	fi

	[[ ! $result ]] && { EchoErr "mDNS: Could not resolve hostname $host"; return 1; } 
	echo "$result"
}

MdnsNames() { avahi-browse -all -c -r | grep hostname | sort | uniq | cut -d"=" -f2 | RemoveSpace | sed 's/\[//' | sed 's/\]//'; }
MdnsServices() { avahi-browse --cache --all --no-db-lookup --parsable | cut -d';' -f5 | sort | uniq; }

#
# network: services
#

# GetServer SERVICE - get an active host for the specified service
GetServer() 
{
	# arguments
	local quiet service

	while (( $# != 0 )); do
		case "$1" in "") : ;;
			--quiet|-q) quiet="--quiet";;
			*)
				! IsOption "$1" && [[ ! $service ]] && { service="$1"; shift; continue; }
				pause UnknownOption "$1" "GetServer"; return 1
		esac
		shift
	done

	[[ ! $service ]] && { MissingOperand "service" "GetServer"; return 1; }	
	local ip; ip="$(GetIpAddress $quiet "$service.service.$(GetNetworkDnsBaseDomain)")" || return
	DnsResolve $quiet $useAlternate "$ip" "$@"
}

# GetServers SERVICE - get all active hosts for the specified service
GetServers() { hashi resolve name --all "$@"; }

# GetAllServers - get all active servers
GetAllServers() { GetServers "${1:-nomad-client}"; } # assume all servers have the nomad-client service

# IsService SERVICE - return true if the service is a service on the current domain
IsService()
{
	local service="$1"
	IsIpAddress "$service" && return 1
	HasDnsSuffix "$service" && return 1
	! IsOnNetwork "hagerman" && return 1	
	DnsResolve --quiet "$1.service.$(GetNetworkDnsDomain)" > /dev/null
}

#
# network: SSH
#

GetSshUser() { GetArgs; local gsu; [[ "$1" =~ @ ]] && gsu="${1%@*}"; r "$(RemoveSpaceTrim "$gsu")" $2; } 	# GetSshUser USER@HOST:PORT -> USER
GetSshHost() { GetArgs; local gsh="${1#*@}"; gsh="${gsh%:*}"; r "$(RemoveSpaceTrim "$gsh")" $2; }					# GetSshHost USER@HOST:PORT -> HOST
GetSshPort() { GetArgs; local gsp; [[ "$1" =~ : ]] && gsp="${1#*:}"; r "$(RemoveSpaceTrim "$gsp")" $2; }	# GetSshPort USER@HOST:PORT -> PORT

IsSsh() { [[ $SSH_CONNECTION || $XPRA_SERVER_SOCKET ]]; }		# IsSsh - return true if connected over SSH
IsXpra() { [[ $XPRA_SERVER_SOCKET ]]; }											# IsXpra - return true if connected using XPRA
RemoteServer() { echo "${SSH_CONNECTION%% *}"; }						# RemoveServer - return the IP addres of the remote server that the SSH session is connected from
RemoteServerName() { DnsResolve "$(RemoteServer)"; }				# RemoveServerName - return the DNS name remote server that the SSH session is connected from

SshConfigGet() { local host="$1" value="$2"; ssh -G "$host" | grep -i "^$value " | head -1 | cut -d" " -f2; } # SshConfigGet HOST VALUE - do not use SshHelp config get for speed
SshInPath() { SshHelper connect "$1" -- which "$2" >/dev/null; } 																							# SshInPath HOST FILE
SshIsAvailablePort() { local port="$(SshHelper config get "$1" port)"; IsAvailablePort "$1" "${port:-22}" $2; } 	# SshIsAvailablePort HOST [TIMEOUT] - return true if SSH is available on the host

SshAgentEnvConf()
{
	local force forceLevel forceLess; ScriptOptForce "$@"
	[[ $SSH_AUTH_SOCK && !$force ]] && return
	ScriptEval SshAgent environment --quiet
}

SshAgentConf()
{ 
	local force forceLevel forceLess; ScriptOptForce "$@"
	local verbose verboseLevel verboseLess; ScriptOptVerbose "$@"

	# set the environment from cache if possible - faster than calling SshAgent
	local e="$HOME/.ssh/environment"
	[[ -f  "$e" ]] && eval "$(cat "$e")" 

	# return if the ssh-agent has keys already loaded
	[[ ! $force ]] && ssh-add -L >& /dev/null && { [[ $verbose ]] && SshAgent status; return 0; }

	# return without error if no SSH keys are available
	! SshAgent check keys && { [[ $verbose ]] && ScriptErr "no SSH keys found in $HOME/.ssh", "SshAgentConf"; return 0; }

	# start the ssh-agent and set the environment
	(( verboseLevel > 1 )) && header "SSH Agent Configuration"
	SshAgent start "$@" && ScriptEval SshAgent environment "$@"
}

SshAgentConfStatus() { SshAgentConf "$@" && SshAgent status; }

# SshSudoc HOST COMMAND ARGS - run a command on host using sudoc
SshSudoc() { SshHelper connect --credential --function "$1" -- sudoc "${@:2}"; }

#
# network: GIO shares - # .../smb-share:server=SERVER,share=SHARE/...
#

GetGioServer() { GetArgs; local ggs="${1#*server=}"; ggs="${ggs%,*}"; r "$ggs" $2; }
GetGioShare() { GetArgs; local ggs="${1#*share=}"; ggs="${ggs%%/*}"; r "$ggs" $2; }

#
# network: UNC shares - [PROTOCOL:]//[USER@]SERVER/SHARE[/DIRS][:PROTOCOL]
#

CheckNetworkProtocol() { [[ "$1" == @(|nfs|rclone|smb|ssh) ]] || IsInteger "$1"; }
GetUncRoot() { GetArgs; r "//$(GetUncServer "$1")/$(GetUncShare "$1")" $2; }																	# //SERVER/SHARE
GetUncServer() { GetArgs; local gus="${1#*( )*(*:)//}"; gus="${gus#*@}"; r "${gus%%/*}" $2; }											# SERVER
GetUncShare() { GetArgs; local gus="${1#*( )*(*:)//*/}"; gus="${gus%%/*}"; gus="${gus%:*}"; r "${gus:-$3}" $2; }		# SHARE
GetUncDirs() { GetArgs; local gud="${1#*( )*(*:)//*/*/}"; [[ "$gud" == "$1" ]] && gud=""; r "${gud%:*}" $2; } 			# DIRS
IsUncPath() { [[ "$1" =~ ^(\ |.*:)*//.* ]]; }

IsRcloneRemote() { [[ -f "$HOME/.config/rclone/rclone.conf" ]] && grep --quiet "^\[$1\]$" "$HOME/.config/rclone/rclone.conf"; }

# GetUncFull [--ip] UNC: return the UNC with server fully qualified domain name or an IP
GetUncFull()
{
	local ip unc

	# arguments
	while (( $# != 0 )); do
		case "$1" in "") : ;;
			--ip) ip="true";;
			*)
				if ! IsOption "$1" && [[ ! $unc ]]; then unc="$1"
				else UnknownOption "$1" "GetUncFull"; return 1
				fi
		esac
		shift
	done

	[[ ! $unc ]] && { MissingOperand "unc" "GetUncFull"; return 1; } 

	# parse the UNC
	local user="$(GetUncUser "$unc")"
	local server="$(GetUncServer "$unc")"
	local share="$(GetUncShare "$unc")"
	local dirs="$(GetUncDirs "$unc")"
	local protocol="$(GetUncProtocol "$unc")"

	# exclude if not a server
	{ [[ "$(LowerCase "$server")" == @(cryfs) ]] || IsRcloneRemote "$server"; } && { echo "$unc"; return; }

	# force use of the IP if the host requires an alternate DNS server
	[[ $(DnsAlternate "$server") ]] && ip="--ip"

	# resolve the server
	if ! IsIpAddress "$server" ; then
		if [[ $ip ]]; then
			server="$(GetIpAddress "$server")" || return
		else
			server="$(DnsResolve "$server")" || return
		fi
	fi
	
	# return the new UNC
	UncMake "$user" "$server" "$share" "$dirs" "$protocol"
}

GetUncUser()
{
	GetArgs; ! [[ "$1" =~ .*\@.* ]] && { r "" $2; return; }
	local guu="${1#*( )//}"; guu="${guu%%@*}"; r "$guu" $2
}

# GetUncProtocol UNC [VAR [DEFAULT]] - PROTOCOL=NFS|SMB|SSH|INTEGER - INTEGER is a custom SSH port
GetUncProtocol()
{
	# GetArgs; local gup="${1#*:}"; [[ "$gup" == "$1" ]] && gup=""; r "${gup:-$3}" $2
	# CheckNetworkProtocol "$gup" || { EchoErr "'$gup' is not a valid network protocol"; return 1; }

	GetArgs; local gup="$(RemoveSpaceTrim "$1")"
	if [[ "$gup" =~ ^[a-zA-Z]*:// ]]; then gup="${gup%:*}"
	elif [[ "$gup" =~ :[a-zA-Z] ]]; then gup="${gup##*:}"
	else gup="$3"
	fi

	CheckNetworkProtocol "$gup" || { EchoErr "'$gup' is not a valid network protocol"; return 1; }
	r "${gup}" $2	
}

# SshUser HOST - return the user for the host
SshUser()
{
	local host="$1" user; user="$(SshConfigGet "$host" "user")" || return
	[[ "$user" == "johnbutare" ]] && user="jjbutare"
	echo "${user:-$USER}"
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
# network: URI - PROTOCOL://SERVER:PORT[/DIRS]
#

GetUriProtocol() { GetArgs; local gup="${1%%\:*}"; r "$(LowerCase "$gup")" $2; }
GetUriServer() { GetArgs; local gus="${1#*//}"; gus="${gus%%:*}"; r "${gus%%/*}" $2; }
GetUriPort() { GetArgs; local gup="${1##*:}"; r "${gup%%/*}" $2; }
GetUriDirs() { GetArgs; local gud="${1#*//*/}"; [[ "$gud" == "$1" ]] && gud=""; r "$gud" $2; }
IsHttps() { GetArgs; [[ "$(GetUriProtocol "$@")" == "https" ]]; }

GetUrlPort()
{
	GetArgs
	local gup="$(GetUriPort "$1")"
	[[ $gup ]] && { r "$gup" $2; return; }
	case "$(GetUriProtocol "$1")" in
		http) gup="80";;
		https) gup="443";;
	esac
	r "$gup" $2
}

#
# package manager
#

HasPackageManager() { [[ "$(PackageManager)" != "none" ]]; }
PackageLog() { LogShow "/var/log/unattended-upgrades/unattended-upgrades-dpkg.log"; }
PackagePurge() { InPath wajig && wajig purgeremoved; }
PackageSize() { InPath wajig && wajig sizes | grep "$1"; }
PackageUpgradable() { ! IsPlatform apt && return; (apt list --upgradeable | grep -v "^Listing..." | wc -l;) 2> /dev/null; }

# package PACKAGE - install the specified package
#   --no-prompt|-np   do not prompt for input
#   --force|-f   			force the install even if the package is installed
#   --quiet|-q   			minimize informational messages
package() # package install
{
	# arguments
	local packages=() force noPrompt quiet
	while (( $# != 0 )); do
		case "$1" in "") : ;;
			--force|-f) force="--force";;
			--no-prompt|-np) noPrompt="--no-prompt";;
			--quiet|-q) quiet="--quiet";;
			*) packages+=("$1");;
		esac
		shift
	done

	# fix package list
	packageFixList || return

	# return if all packages have been excluded
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

	# install
	IsPlatform nala && { sudoc $noPrompt nala install -y "${packages[@]}"; return; }
	IsPlatform apt && { sudoc $noPrompt apt install -y "${packages[@]}"; return; }
	IsPlatform brew && { HOMEBREW_NO_AUTO_UPDATE=1 brew install "${packages[@]}"; return; }
	IsPlatform dnf && { sudoc dnf install --assumeyes "${packages[@]}"; }
	IsPlatform opkg && { sudoc opkg install "${packages[@]}"; return; }
	IsPlatform pacman && { sudoc pacman -S "$@"; }

	return 0
}

# PackageFileInstall - install a package file with dependencies
PackageFileInstall()
{
	IsPlatform apt && InPath gdebi && { sudoc gdebi -n "$@"; return; }
	IsPlatform yum && { sudoc yum localinstall --assumeyes "$@"; return; } # try before rpm, which does not install dependencies
	IsPlatform rpm && { sudoc rpm --install --assumeyes "$@"; return; }
} 

 # PackageFileExtension - the package file extension for the system
PackageFileExtension()
{
	IsPlatform apt && { echo "deb"; return; }
	IsPlatform rpm && { echo "rpm"; return; }
}

 # PackageFileInfo - information about a package file
PackageFileInfo()
{
	IsPlatform apt && InPath dpkg && { dpkg -I "$1"; return; }
	IsPlatform rpm && { rpm --query --info --package "$1"; return; }
}

PackageFileVersion()
{
	IsPlatform apt && InPath dpkg && { PackageFileInfo "$1" | RemoveSpace | grep Version | cut -d: -f2; return; }
	IsPlatform rpm && { rpm --query --queryformat '%{VERSION}' --nosignature --package "$1"; return; }
}

PackageFix()
{
	IsPlatform apt && { sudoc apt-get -y --with-new-pkgs upgrade "$@"; } # held back
	return 0
}

# packageFixList - fix packages in the packages array for the platform
packageFixList()
{
	local p exclude=()

	# Ubuntu changes
	if IsPlatform ubuntu; then

		# ncat is not present on older distributions
		IsInArray "ncat" packages && [[ "$(os CodeName)" =~ ^(bionic|xenial)$ ]] && ArrayRemove packages "ncat"

		# libturbojpeg0 is libturbojpeg in Ubuntu
		IsInArray "libturbojpeg0" packages && { ArrayRemove packages "libturbojpeg0"; packages+=( libturbojpeg ); }
	fi

	# exclude packages
	IsPlatform entware && exclude+=( pwgen )
	IsPlatform mac && exclude+=( atop fortune-mod hdparm inotify-tools iotop iproute2 ksystemlog ncat ntpdate psmisc squidclient unison-gtk util-linux virt-what )
	IsPlatformAll mac,arm && exclude+=( bonnie++ rust traceroute )
	IsPlatformAll mac,x86 && exclude+=( ncat traceroute )
	IsPlatform rhel && exclude+=( daemonize di pwgen htop iproute2 ncat ntpdate )
	IsPlatform wsl1 && exclude+=( fping )
	packageExclude
	return 0
}

packageExclude()
{
	(( ${#packages[@]} == 0 )) && return
	local p
	for p in "${packages[@]}"; do
		IsInArray "$p" exclude && ArrayRemove packages "$p"
	done
}

PackageIsInstalled()
{
	if IsPlatform apt; then dpkg --get-selections "$1" 2>&1 | qgrep --extended-regexp "(install|hold)$"
	elif IsPlatform dnf; then dnf info "$1" >& /dev/null
	else PackageListInstalled | ${G}grep "^$1	" >& /dev/null # --quiet causes pipe to fail in Debian
	fi
}

# pakcageu PACKAGE - remove the specified package exists
# - allow removal prompt to view dependant programs being uninstalled, i.e. uninstall of mysql-common will remove kea
packageu() # package uninstall
{ 
	if IsPlatform nala; then sudoc nala purge "$@"
	elif IsPlatform apt; then sudoc apt remove "$@"
	elif IsPlatform brew; then brew remove "$@"
	elif IsPlatform opkg; then sudoc opkg remove "$@"
	fi
}

PackageCleanup()
{
	if IsPlatform apt; then
		ask "Clean packages"	&& { sudoc apt-get clean -y || return; } # cleanup downloaded package files in /var/cache/apt/archives
		ask "Remove packages" && { sudoc apt autoremove -y || return; }
		ask "Purge packages" && { PackagePurge || return; }
	fi
}

# PackageExist PACKAGE - return true if the specified package exists
PackageExist()
{ 
	if IsPlatform apt; then [[ "$(apt-cache search "^$@$")" ]]
	elif IsPlatform brew; then brew search "/^$@$/" | grep -v "No formula or cask found for" >& /dev/null
	elif IsPlatform opkg; then [[ "$(packagel "$1")" ]]
	fi
}

# PackageFiles PACKAGE - show files in the specified package
PackageFiles()
{
	if InPath "apt-file"; then apt-file list "$@"
	elif IsPlatform opkg; then opkg files "$@"
	fi
}

# PackageInfo PACKAGE - show information about the specified package
PackageInfo()
{
	if IsPlatform apt; then
		apt show "$1" || return
		! PackageInstalled "$1" && return
		dpkg -L "$1"; echo
		dpkg -L "$1" | grep 'bin/'
	elif IsPlatform brew; then
		brew info "$1" || return
		! PackageInstalled "$1" && return
		brew list "$1"; echo
		brew list "$1" | grep 'bin/'
	elif IsPlatform dnf; then
		dnf info "$1"
		dnf repoquery -l "$1"
	elif IsPlatform opkg; then
		opkg info "$@"
	fi
}

# PackageInstalled PACKAGE [PACKAGE]... - return true if all packages are installed
PackageInstalled() 
{ 
	[[ "$@" == "" ]] && return 0

	if IsPlatform apt; then
		# ensure the package counts match, i.e. dpkg --get-selectations samba will not return anything if samba-common is installed
		[[ "$(dpkg --get-selections "$@" |& grep -v "no packages found" | wc -l)" == "$#" ]] && ! dpkg --get-selections "$@" | grep -q "deinstall$"
	
	elif IsPlatform brew; then
		InPath "$@" && return # faster if all packages are in the path
		brew list "$@" >& /dev/null

	elif IsPlatform dnf,rpm,yum; then
		[[ "$(rpm --query --all "${packages[@]}" | wc -l)" == "$#" ]]

	else
		InPath "$@" # assumes each package name is in the path
	fi
}

PackageManager()
{
	if IsPlatform apt; then echo "apt"
	elif IsPlatform brew; then echo "brew"
	elif IsPlatform dnf; then echo "dnf"
	elif IsPlatform opkg; then echo "opkg"
	elif IsPlatform rpm; then echo "rpm"
	elif IsPlatform yum; then echo "yum"
	else echo "none"
	fi
}

# PackageSearch PATTERN - search for a package
PackageSearch() 
{ 
	if IsPlatform apt; then apt-cache search  "$@"
	elif IsPlatform brew; then brew search "$@"
	elif IsPlatform dnf; then sudoc dnf search "$@"
	elif IsPlatform entware; then opkg find "*$@*"
	elif IsPlatform pacman; then pacman -Ss "$@"
	elif IsPlatform yum; then yum search "$@"
	fi
}

# PackageSearchDetail PATTERN - search for a package showing installed and uninstalled matches
PackageSearchDetail() 
{ 
	if IsPlatform apt && InPath wajig && InPath apt-file; then wajig whichpkg "$@"
	elif IsPlatform entware; then opkg whatprovides "$@"
	fi
}

PackageListInstalled()
{
	local full; [[ "$1" == @(--full|-f) ]] && { full="true"; shift; }
	if IsPlatform apt && InPath dpkg; then dpkg --get-selections "$@"
	elif IsPlatform brew && [[ $full ]]; then brew info --installed --json
	elif IsPlatform brew && [[ ! $full ]]; then brew info --installed --json | jq -r '.[].name'
	elif IsPlatform dnf; then dnf list installed
	elif IsPlatform entware; then opkg list-installed
	elif IsPlatform rpm; then rpm --query --all
	elif IsPlatform pacman; then pacman --query
	fi
}

# PackageUpdate - update package list
PackageUpdate() 
{
	if IsPlatform nala; then sudoc nala update
	elif IsPlatform apt; then sudoc apt update
	elif IsPlatform dnf; then sudoc dnf clean expire-cache && sudo dnf update --assumeyes
	elif IsPlatform brew; then brew update
	elif IsPlatform qnap; then sudoc opkg update
	elif IsPlatform yum; then sudoc yum makecache --assumeyes
	fi
}

# PackageUpgrade - update packages
PackageUpgrade() 
{
	PackageUpdate || return
	if IsPlatform nala; then sudo sudo nala upgrade -y
	elif IsPlatform apt; then sudo apt dist-upgrade -y
	elif IsPlatform brew; then brew upgrade;
	elif IsPlatform qnap; then sudo opkg upgade
	fi
}

# PackageWhich FILE - show which package an installed file is located in
PackageWhich() 
{
	local file="$1"
	[[ -f "$file" ]] && file="$(GetFullPath "$1")"
	[[ ! -f "$file" ]] && InPath "$file" && file="$(FindInPath "$file")"
	if IsPlatform apt; then dpkg -S "$file"
	elif IsPlatform brew; then { file="$(readlink "$file")" && echo "$file" | sed 's/.*Cellar\///' | cut -d"/" -f1; }
	elif IsPlatform dnf; then dnf provides "$file"
	elif IsPlatform entware; then	opkg search "$file"
	fi
}

#
# platform
# 

IsPlatformAll() { IsPlatform --all "$@"; }
PlatformDescription() { echo "$PLATFORM_OS$([[ "$PLATFORM_ID_LIKE" != "$PLATFORM_OS" ]] && echo " $PLATFORM_ID_LIKE")$([[ "$PLATFORM_ID_MAIN" != "$PLATFORM_OS" ]] && echo " $PLATFORM_ID_MAIN")"; }

PlatformSummary()
{
	printf "$(os architecture) $(PlatformDescription | RemoveSpaceTrim) $(os bits)"
	! IsPlatform win && { echo ; return; }
	IsWinAdmin && echo " administrator" || echo " non-administrator"
}

# GetPlatformVar VAR - return PLATFORM_VAR variable if defined, otherewise return VAR
if IsZsh; then GetPlatformVar() { local v="$1" pv="${(U)PLATFORM_OS}_$1"; [[ ${(P)pv} ]] && echo "${(P)pv}" || echo "${(P)v}"; }
else GetPlatformVar() { local v="$1" pv="${PLATFORM_OS^^}_$1"; [[ ${!pv} ]] && echo "${!pv}" || echo "${!v}"; }
fi

# IsPlatform  platform[,platform,...] [--host [HOST]] - return true if the host matches any of the listed characteristics
# --all - return true if the host match all of the listed characteristics
# --host [HOST] - check the specified host instead of localhost.   If the HOST argument is not specified,
#   use the _platform host variables set from the last call to HostGetInfo.
IsPlatform()
{
	local all host hostArg p platforms=() useHost

	# arguments
	while (( $# != 0 )); do
		case "$1" in "") : ;;
			-a|--all) all="true";;
			-h|--host) 
				[[ $2 ]] && ! IsOption "$2" && { host="$2"; shift; }
				useHost="true" hostArg="--host $host"
				;;
			*)
				if ! IsOption "$1" && [[ ! $platforms ]]; then StringToArray "$1" "," platforms
				else UnknownOption "$1" "IsPlatform"; return
				fi
				;;
		esac
		shift
	done

	# set _platformOs variables
	if [[ $useHost && $host ]]; then		
		ScriptEval HostGetInfo "$host" || return
	elif [[ ! $useHost ]]; then
		local _platformTarget="localhost" _platformLocal="true" _platformOs="$PLATFORM_OS" _platformIdMain="$PLATFORM_ID_MAIN" _platformIdLike="$PLATFORM_ID_LIKE" _platformKernel="$PLATFORM_KERNEL" _machine="$MACHINE" _wsl="$WSL"
	fi

	# check if the host matches the specified platforms
	for p in "${platforms[@]}"; do
		if [[ $all ]]; then
			! isPlatformCheck "$p" "$@" && return 1			
		else
			isPlatformCheck "$p" && return
		fi
	done

	[[ $all ]]
}

# isPlatformCheck p
isPlatformCheck()
{
	local p="$1"; LowerCase "$p" p
	local found="true" result

	# works local and remote - only use variables from "HostGetInfo vars HOST"
	case "$p" in 

		# platformOs, platformIdMain, and platformIdLike
		win|mac|linux) [[ "$p" == "$_platformOs" ]];;
		casaos|dsm|qts|rhel|srm|pi|ubuntu) [[ "$p" == "$_platformIdMain" ]];;
		fedora|mingw|openwrt|qnap|synology|ubiquiti) [[ "$p" == "$_platformIdLike" ]];;
		debian) [[ "$_platformIdMain" == "debian" || "$_platformIdLike" == "debian" ]];;
		debianbase) [[ "$_platformIdMain" == "debian" && "$_platformIdLike" == "" ]];;
		debianlike) [[ "$_platformIdLike" == "debian" ]];;

		# aliases
		embedded) IsPlatform pi,piKernel,rock,RockKernel $hostArg;;
		nas) IsPlatform qnap|synology;;
		rh) IsPlatform rhel $hostArg;; # Red Hat

		# windows
		wsl) [[ "$_platformOs" == "win" && "$_platformIdLike" == "debian" ]];; # Windows Subsystem for Linux
		wsl1|wsl2) [[ "$p" == "$_platformKernel" ]];;

		# hardware
		32|64) [[ "$p" == "$(os bits "$_machine" )" ]];;
		arm|mips|x86) [[ "$p" == "$(os architecture "$_machine" | LowerCase)" ]];;
		x64) eval IsPlatformAll x86,64 $hostArg;;

		# kernel
		winkernel) [[ "$_platformKernel" == @(wsl1|wsl2) ]];;
		linuxkernel) [[ "$_platformKernel" == "linux" ]];;
		pikernel) [[ "$_platformKernel" == "pi" ]];;
		rock|rockkernel) [[ "$_platformKernel" == "rock" ]];;

		# other
		entware) IsPlatform qnap,synology $hostArg;;

		*) unset found;;
	esac
	result="$?"; [[ $found ]] && return $result

	# perform local only checks, return if we are not checking the local system
	[[ ! $_platformLocal ]] && return 1

	case "$p" in 

		# package management
		apt) ! IsPlatform mac && InPath apt;;
		brew|homebrew) InPath brew;;
		dnf|opkg|rpm|yum) InPath "$p";;
		nala) InPath "nala";;
		pacman) InPath "pacman";;

		# virtualization
		chroot) IsChroot;;
		container) IsContainer;;
		docker) IsDocker;;
		guest|vm|virtual) IsVm;;
		hyperv) IsHypervVm;;
		host|physical) ! IsChroot && ! IsContainer && ! IsVm;;
		proxmox) IsProxmoxVm;;
		parallels) IsParallelsVm;;
		swarm) InPath docker && docker info |& command grep "^ *Swarm: active$" >& /dev/null;; # -q does not work reliably on pi2
		vmware) IsVmwareVm;;

		# window manager
		wm) IsPlatform gnome,mac,win;; # system has a windows manager
		gnome) [[ -f "/usr/bin/gnome-session" ]];;

		# windows
		win11) [[ ! $useHost ]] && IsPlatform win && (( $(os build) >= 22000 ));;

		# other
		busybox) IsBusyBox;;
		cm4) [[ -e /proc/cpuinfo ]] && grep -q "Raspberry Pi Compute Module" "/proc/cpuinfo";;
		consul|nomad|vault) service running "$p";;
		desktop) ! IsPlatform laptop;;
		gnome-keyring) InPath "$p";;
		laptop)
			if IsPlatform mac; then system_profiler "SPHardwareDataType" | grep "Model Identifier" | grep --quiet "Book"
			elif IsPlatform win; then
				local chassisType
				if InPath wmic.exe; then
					chassisType="$( wmic.exe systemenclosure get chassistypes /value | grep ChassisTypes | cut -d"{" -f2 | cut -d"}" -f1)"
				else
					chassisType="$( powershell "Get-CimInstance -ClassName Win32_SystemEnclosure -Property ChassisTypes" | grep ChassisTypes | cut -d"{" -f2 | cut -d"}" -f1)"
				fi
				(( (chassisType >= 8 && chassisType <=15) || (chassisType >= 30 && chassisType <=32) )) # https://learn.microsoft.com/en-us/windows/win32/cimwin32prov/win32-systemenclosure
			fi
			;;
		mini) # mini computer, like a Mac mini or Beelink
			if IsPlatform mac; then system_profiler "SPHardwareDataType" | grep "Model Identifier" | grep --quiet "mini"
			elif IsPlatform win; then os info -w=cpum | ${G}grep --extended-regexp --quiet 'N100|N305|N5105'
			fi
			;;
		pi4|pi5) IsPlatform PiKernel && [[ "$(pi info model | cut -d" " -f3)" == "${p:2}" ]];; # Raspberry Pi model 4 or 5
		systemd) IsSystemd;;

		*) return 1;;

	esac
}

# IsBusyBox FILE - return true if the specified file is using BusyBox
IsBusyBox() { InPath busybox && [[ "$(readlink -f "$(which nslookup 2>&1)")" == "$(which "busybox" 2>&1)" ]]; }

# GetPlatformFiles FILE_PREFIX FILE_SUFFIX - add platform specific files to files array, i.e. .bashrc.win.sh
function GetPlatformFiles()
{
	files=()

	[[ -f "$1$PLATFORM_OS$2" ]] && files+=("$1$PLATFORM_OS$2")
	[[ "$PLATFORM_ID_LIKE" != "$PLATFORM_OS" && -f "$1$PLATFORM_ID_LIKE$2" ]] && files+=("$1$PLATFORM_ID_LIKE$2")
	[[ "$PLATFORM_ID_MAIN" != "$PLATFORM_OS" && -f "$1$PLATFORM_ID_MAIN$2" ]] && files+=("$1$PLATFORM_ID_MAIN$2")

	return 0
}

SourceIfExists() { [[ -f "$1" ]] && { . "$1" || return; }; return 0; }

SourceIfExistsPlatform() # SourceIfExistsPlatform PREFIX SUFFIX
{
	local file files

	GetPlatformFiles "$1" "$2" || return 0;
	for file in "${files[@]}"; do . "$file" || return; done
}

SourcePlatformScripts()
{
	local script scripts=( "$@" ) errors=0 

	set --
	for script in "${scripts[@]}"; do
		{ [[ ! $script ]] || IsOption "$script"; } && continue
		script="$PLATFORM_DIR/$script.sh"
		[[ ! -f "$script" ]] && { ScriptErrQuiet "script '$(FileToDesc "$script")' does not exist" "SourcePlatformScripts"; (( ++errors )); continue; }
		[[ $verbose ]] && ScriptErr "sourcing '$(FileToDesc "$script")'" "SourcePlatformScripts"
		. "$script" || { ScriptErrQuiet "error sourcing script '$(FileToDesc "$script")'" "SourcePlatformScripts"; (( ++errors )); continue; }
	done

	return $errors
}

PlatformTmp() { IsPlatform win && echo "$UADATA/Temp" || echo "$TEMP"; }

# RunPlatform PREFIX [--host [HOST]] [ARGS] - call platform functions, i.e. prefixWin.  example order: win -> debian -> ubuntu -> wsl -> physical
# --host [HOST] - if specified run the platform function for the specified host
function RunPlatform()
{
	local function="$1"; shift

	# set _platform variables
	if [[ "$1" == @(-h|--host) ]]; then		
		shift
		[[ $1 ]] && { ScriptEval HostGetInfo "$1" || return; }
	else
		local _platformOs="$PLATFORM_OS" _platformIdMain="$PLATFORM_ID_MAIN" _platformIdLike="$PLATFORM_ID_LIKE" _platformKernel="$PLATFORM_KERNEL" _machine="$MACHINE" _wsl="$WSL"
	fi

	# run platform function
	[[ $_platformOs ]] && { RunFunction $function $_platformOs -- "$@" || return; }
	[[ $_platformIdLike && "$_platformIdLike" != "$platformOs" ]] && { RunFunction $function $_platformIdLike -- "$@" || return; }
	[[ $_platformIdMain && "$platformIdMain" != "$platformOs" ]] && { RunFunction $function $_platformIdMain -- "$@" || return; }

	# run windows WSL functions
	if [[ "$PLATFORM_OS" == "win" ]]; then
		IsPlatform wsl --host && { RunFunction $function wsl -- "$@" || return; }
		IsPlatform wsl1 --host && { RunFunction $function wsl1 -- "$@" || return; }
		IsPlatform wsl2 --host && { RunFunction $function wsl2 -- "$@" || return; }
	fi

	# run other functions
	IsPlatform cm4 --host && { RunFunction $function cm4 -- "$@" || return; }
	IsPlatform entware --host && { RunFunction $function entware -- "$@" || return; }
	IsPlatform pikernel --host && { RunFunction $function PiKernel -- "$@" || return; }
	IsPlatform proxmox --host && { RunFunction $function proxmox -- "$@" || return; }
	IsPlatform vm --host && { RunFunction $function vm -- "$@" || return; }
	IsPlatform physical --host && { RunFunction $function physical -- "$@" || return; }

	return 0
}

#
# process
#

CanElevate() { ! IsPlatform win && return; IsWinAdmin; }
ProgramsElevate() { CanElevate && echo "$P" || echo "$UADATA"; }
console() { start proxywinconsole.exe "$@"; } # console PROGRAM ARGS - attach PROGRAM to a hidden Windows console (powershell, nuget, python, chocolatey), alternatively run in a regular Windows console (Start, Run, bash --login)
CoprocCat() { cat 0<&${COPROC[0]}; } # read output from a process started with coproc
handle() { ProcessResource "$@"; }
InUse() { ProcessResource "$@"; }
IsMacApp() { FindMacApp "$1" >& /dev/null; }
IsRoot() { [[ "$USER" == "root" || $SUDO_USER ]]; }
IsSystemd() { IsPlatform mac && return 1; cat /proc/1/status | grep -i "^Name:[	 ]*systemd$" >& /dev/null; } # systemd must be PID 1
IsWinAdmin() { IsPlatform win && { IsInDomain sandia || RunWin net.exe localgroup Administrators | RemoveCarriageReturn | grep --quiet "$WIN_USER$"; }; }
pkillchildren() { pkill -P "$1"; } # pkillchildren PID - kill process and children
ProcessIdExists() {	kill -0 $1 >& /dev/null; } # kill is a fast check
pschildren() { ps --forest $(ps -e --no-header -o pid,ppid|awk -vp=$1 'function r(s){print s;s=a[s];while(s){sub(",","",s);t=s;sub(",.*","",t);sub("[0-9]+","",s);r(t)}}{a[$2]=a[$2]","$1}END{r(p)}'); } # pschildren PPID - list process with children
pschildrenc() { local n="$(pschildren "$1" | wc -l)"; (( n == 1 )) && return 1 || echo $(( n - 2 )); } # pschildrenc PPID - list count of process children
pscount() { ProcessList | wc -l; }
RunQuiet() { if [[ $verbose ]]; then "$@"; else "$@" 2> /dev/null; fi; }		# RunQuiet COMMAND... - suppress stdout unless verbose logging
RunSilent() {	if [[ $verbose ]]; then "$@"; else "$@" >& /dev/null; fi; }		# RunQuiet COMMAND... - suppress stdout and stderr unless verbose logging

# PipeStatus N - return the status of the 0 based Nth command in the pipe
if IsZsh; then
	PipeStatus() { echo "${pipestatus[$(($1+1))]}"; }
else
	PipeStatus() { return ${PIPESTATUS[$1]}; }
fi

# FindMacApp APP - return the location of a Mac applciation
FindMacApp()
{
	local app="$1"
	[[ -d "$app" && "$app" =~ \.app$ ]] && HasFilePath "$app" && echo "$app" && return
	HasFilePath "$app" && return 1
	
	# special cases
	case "$app" in
		DiskSpeedTest) app="Blackmagic Disk Speed Test";;
		MicrosoftRemoteDesktop) app="Windows App";;
	esac

	# get directory
	app="$(GetFileNameWithoutExtension "$app")"
	[[ -d "$P/$app.app" ]] && { echo "$P/$app.app"; return; }
	[[ -d "$HOME/Applications/$app.app" ]] && { echo "$HOME/Applications/$app.app"; return; }
	return 1
}

# IsExecutable FILE - true if the file is an executable program
IsExecutable()
{
	local file="$1"; [[ ! $file ]] && { EchoWrap "Usage: IsExecutable FILE"; return 1; }

	# file $UADATA/Microsoft/WindowsApps/*.exe returns empty, so assume files that end in exe are executable
	[[ -f "$file" && "$(GetFileExtension "$file")" == @(exe|com) ]] && return 0

	# executable file
	[[ -f "$file" ]] && { file "$(GetRealPath "$file")" | grep -E "executable|ELF" > /dev/null; return; }

	# not executable
	return 1
}

# IsProcessRunning NAME
# -f|--full 	match the full command line argument not just the process name
# -r|--root 	return root processes as well
IsProcessRunning()
{
	# options
	local full name root win

	while (( $# != 0 )); do
		case "$1" in "") : ;;
			-f|--full) full="--full";;
			-r|--root) root="sudoc";;
			*)
				! IsOption "$1" && [[ ! $name ]] && { name="$1"; shift; continue; }
				UnknownOption "$1" "IsProcessRunning"; return 1
		esac
		shift
	done
	[[ ! "$name" ]] && { MissingOperand "name" "ProcessClose"; return; }

	# check Windows process
	IsWindowsProcess "$name" && { IsProcessRunningList "$name" --win; return; }

	# mac	
	if IsPlatform mac; then
		local nameCheck="$name"; [[ "$name" =~ \.app$ ]] && nameCheck="$(GetFileNameWithoutExtension "$name")"
		pidof -l "$nameCheck" | ${G}grep --ignore --quiet "^PID for $nameCheck is"; return;
	fi

	# check for process using pidof - slightly faster but pickier than pgrep
	[[ ! $full && $root ]] && { pidof -snq "$name" > /dev/null; return; }

	# check for proces using pgrep
	local args=(); [[ ! $root ]] && args+=("--uid" "$USER")
	HasFilePath "$name" && full="--full" # pgrep >= 4.0.3 requires full for process name longer than 15 characters
	pgrep $full "$name" "${args[@]}" > /dev/null
}

# IsProcessRunningList [--user|--unix|--win] NAME - check if NAME is in the list of running processes.  Slower than IsProcessRunning.
IsProcessRunningList() 
{
	local name="$1"; shift

	# get processes - grep fails if ProcessList call in the same pipline on Windows
	local processes; 
	if [[ $CACHED_PROCESSES ]]; then
		processes="$CACHED_PROCESSES"
		(( verboseLevel > 2 )) && ScriptErr "IsProcessRunningList: using cached processes to lookup '$name'"
	else
		processes="$(ProcessList "$@")" || return
	fi

	# convert windows programs to a quoted Windows path format
	HasFilePath "$name" && IsWindowsProcess "$name" && name="$(utw "$name")"	
	IsWindowsPath "$name" && name="$(echo -E "$name" | QuoteBackslashes | QuoteParens)"

	# search for an exact match, a match without the Unix path, and a match without the Windows path
	echo -E "$processes" | grep --extended-regexp --ignore-case --quiet "(,$name$|,.*/$name$|,.*\\\\$name$)"
}

# IsRunnable COMMAND - true if the command is runnable (executable, script, function, alias)
IsRunnable()
{
	local command="$1"; [[ ! $command ]] && { EchoWrap "Usage: IsRunnable COMMAND"; return 1; }

	# executable
	IsExecutable "$command" && return

	# runnable shell commands: alias, function, or builtin
	[[ "$(GetCommandType "$command")" == @(alias|function|builtin) ]]
}

# IsWindowsProces NAME: true if the executable is a native windows program requiring windows paths for arguments (c:\...) instead of POSIX paths (/...)
IsWindowsProcess()
{
	local name="$1"; [[ ! $1 ]] && { MissingOperand "name" "IsWindowsProcess"; return 1; }
	! IsPlatform win && return 1
	[[ "$(GetFileExtension "$name")" == "exe" ]] && return 0
	[[ ! -f "$name" ]] && { name="$(FindInPath "$name")" || return; }
	[[ "$(GetFileExtension "$name")" == "exe" ]] && return 0
	file "$name" | grep --quiet "PE32"
}

# ProcessClose|ProcessCloseWait|ProcessKill NAME... - close or kill the specified process
# --full 					match the full command line argument not just the process name
# --force|-f			do not check if the process exists
# --quiet|-q 			minimize informational messages
# --root|-r 			kill processes as root
# --timeout|-t		time to wait for the process to end in seconds
# --verbose|-v		verbose mode, multiple -v increase verbosity (max 5)
ProcessClose() 
{ 
	# arguments
	local args=() force names=() quiet root timeout=10 verbose verboseLevel verboseLess

	while (( $# != 0 )); do
		case "$1" in "") : ;;
			--full) args+=("--full");;
			--force|-f) force="--force";;
			--quiet|-q) quiet="--quiet";;
			--root|-w) root="sudoc";;
			--timeout|--timeout=*|-t|-t=*) . script.sh && ScriptOptTimeout "$@";;
			--verbose|-v|-vv|-vvv|-vvvv|-vvvvv) ScriptOptVerbose "$1";;
			*)
				! IsOption "$1" && { names+=("$1"); shift; continue; }
				UnknownOption "$1" "ProcessClose"; return 1
		esac
		shift
	done
	[[ ! $names ]] && { MissingOperand "name" "ProcessClose"; return; }

	# close
	local finalResult="0" name result win
	for name in "${names[@]}"; do

		# continue if the process is not running
		[[ ! $force ]] && ! IsProcessRunning $root $full "$name" && continue

		# check for Windows process
		IsPlatform win && IsWindowsProcess "$name" && win="true"

		# close
		if [[ $win ]]; then
			name="${name/.exe/}.exe"; GetFileName "$name" name # ensure process has an .exe extension
			cd "$PBIN" || return # process.exe only runs from the current directory in WSL
			if InPath process.exe; then # Process.exe is not installed in some environments (flagged as malware by Cylance Protect)
				./process.exe -q "$name" $timeout |& grep --quiet "has been closed successfully."; result="$(PipeStatus 1)"
			else
				cmd.exe /c taskkill /IM "$name" >& /dev/null; result="$?"
			fi

		elif IsPlatform mac; then
			osascript -e "quit app \"$name\""; result="$?"

		else
			[[ ! $root ]] && args+=("--uid" "$USER")
			$root pkill "$name" "${args[@]}"; result="$?"

		fi

		if (( ${result:-0} != 0 )); then
			[[ ! $quiet ]] && ScriptErr "unable to close '$name'"; finalResult="1"
		elif [[ $verbose ]]; then
			ScriptErr "closed process '$name'"
		fi

	done

	return "$finalResult"
}

ProcessCloseWait()
{
	# arguments
	local full names=() quiet root seconds=10 verbose verboseLevel verboseLess

	# options
	while (( $# != 0 )); do
		case "$1" in "") : ;;
			--full|-f) full="--full";;
			--quiet|-q) quiet="--quiet";;
			--root|-r) root="--root";;
			--verbose|-v|-vv|-vvv|-vvvv|-vvvvv) ScriptOptVerbose "$1";;
			*)
				! IsOption "$1" && { names+=("$1"); shift; continue; }
				UnknownOption "$1" "ProcessCloseWait"; return 1
		esac
		shift
	done
	[[ ! $names ]] && { MissingOperand "name" "ProcessCloseWait"; return; }

	# close
	local name
	for name in "${names[@]}"; do

		# continue if not running
		[[ ! $force ]] && ! IsProcessRunning $root $full "$name" && continue
		# close the process
		[[ ! $quiet ]] && printf "Closing process $name..."
		ProcessClose $root $full "$name"

		# wait for process to close
		local description="closed"
		for (( i=1; i<=$seconds; ++i )); do
	 		ReadChars 1 1 && { [[ ! $quiet ]] && echo "cancelled after $i seconds"; return 1; }
			[[ ! $quiet ]] && printf "."
			! IsProcessRunning $root $full "$name" && { [[ ! $quiet ]] && echo "$description"; return; }
			sleep 1; description="killed"; ProcessKill $root $full "$name"
		done

		[[ ! $quiet ]] && echo "failed"; return 1

	done
}

ProcessKill()
{
	# arguments
	local args=() force names=() quiet root rootArg win

	while (( $# != 0 )); do
		case "$1" in "") : ;;
			--full) args+=("--full");;
			--force|-f) force="--force";;
			--quiet|-q) quiet="true";;
			--root|-r) rootArg="--root" root="sudoc";;
			--win|-w) win="--win";;
			*)
				! IsOption "$1" && { names+=("$1"); shift; continue; }
				UnknownOption "$1" "ProcessKill"; return 1
		esac
		shift
	done
	[[ ! $names ]] && { MissingOperand "name" "ProcessKill"; return; }

	# kill
	local name output result resultFinal="0"
	for name in "${names[@]}"; do

		# continue if not running
		[[ ! $force ]] && ! IsProcessRunning $rootArg $full "$name" && continue

		# check for Windows process
		[[ ! $win ]] && IsWindowsProcess "$name" && win="true"

		# kill the process
		if [[ $win ]]; then
			output="$(start pskill.exe -nobanner "$name" |& grep "unable to kill process" | grep "^Process .* killed$")"
		else
			[[ ! $root ]] && args+=("--uid" "$USER")
			output="$($root pkill -9 "$name" "${args[@]}")"
		fi
		result="$?"

		# process result
		[[ ! $quiet && $output ]] && echo "$output"
		if (( $result != 0 )); then
			[[ ! $quiet ]] && ScriptErr "unable to kill '$name'"; resultFinal="1"
		elif [[ $verbose ]]; then
			ScriptErr "killed process '$name'"
		fi

	done

	return "$resultFinal"
}

# ProcessList [--user|--unix|--win] - show process ID and executable name with a full path in format PID,NAME
# -u|--user - only user processes
# -U|--unix - only UNIX processes
# -w|--win - only Windows processes
ProcessList() 
{ 
	# arguments
	local args="-e" unix="true" win="true"

	while (( $# != 0 )); do
		case "$1" in "") : ;;
			-u|--user) unset args;;
			-U|--unix) unset win;;
			-w|--win) unset unix;;
			*) UnknownOption "$1" "ProcessList"; return 1
		esac
		shift
	done

	# mac proceses
	IsPlatform mac && { ps -c $args | sed 's/^[[:space:]]*//' | tr -s ' ' | ${G}cut -d" " -f1,4 --output-delimiter=,; return; }

	# unix processes
	[[ $unix ]] && IsPlatform linux,win && { ps $args -o pid= -o command= | awk '{ print $1 "," $2 }' || return; }

	# windows processes
	if [[ $win ]] && IsPlatform win; then
		if InPath ProcessList.exe; then
			ProcessList.exe | RemoveCarriageReturn
		elif InPath wmic.exe; then
			RunWin wmic.exe process get Name,ExecutablePath,ProcessID /format:csv | RemoveCarriageReturn | ${G}tail --lines=+3 | awk -F"," '{ print $4 "," ($2 == "" ? $3 : $2) }'
		else
			RunWin powershell.exe --command 'Get-Process | select Name,Path,ID | ConvertTo-Csv' | RemoveCarriageReturn | awk -F"," '{ print $3 "," ($2 == "" ? $1 ".exe" : $2) }' | RemoveQuotes
		fi
	fi
}

ProcessParents()
{
	local ppid; 
	{
		if IsPlatform mac; then
			for ((ppid=$PPID; ppid > 1; ppid=$(ps ao ppid $ppid | ${G}tail --lines=-1))); do
				ps ao comm $ppid | ${G}tail --lines=-1 | GetFileName
			done
		else
			for ((ppid=$PPID; ppid > 1; ppid=$(ps ho %P -p $ppid))); do
				ps ho %c -p $ppid
			done
		fi
	} | NewlineToSpace | RemoveTrim
}

ProcessResource()
{
	IsPlatform win && { start handle.exe "$@"; return; }
	InPath lsof && { lsof "$@"; return; }
	echo "Not Implemented"
}

pstree()
{
	local pstreeOpts=(); IsPlatform mac && pstreeOpts+=(-g 2)
	InPath pstree && { command pstree "${pstreeOpts[@]}" "$@"; return; }
	! IsPlatform mac && { ps -axj --forest "$@"; return; }
	return
}

# RunWin PROGRAM - running Windows executables from some Linux directories fails
# - CryFS directories causes "Invalid argument" errors
# - logioptionsplus_installer.exe terminates in Linux directories
RunWin() { (IsPlatform win && cd "$WIN_ROOT"; "$@"); }

# start a program converting file arguments for the platform as needed
startUsage()
{
	EchoWrap "\
Usage: start [OPTION]... FILE [ARGUMENTS]...
	Start a program converting file arguments for the platform as needed

	--elevate, -e 					run the program with an elevated administrator token (Windows)
	--open, -o							open the the file using the associated program
	--sudo, -s							run the program as root
	--terminal, -T 					the terminal used to elevate programs, valid values are wsl|wt
													wt does not preserve the current working directory
	--test, -t 							test mode, the program is not started
	--wait, -w							wait for the program to run before returning
	--window-style, -ws 		hidden|maximized|minimized|normal"
}

start() 
{
	# arguments
	local elevate file force noPrompt sudo terminal verbose verboseLevel verboseLess wait windowStyle

	while (( $# != 0 )); do
		case "$1" in "") : ;;
			--elevate|-e) IsPlatform win && CanElevate && ! IsElevated && elevate="--elevate";;
			--force|-f) force="--force";;
			--help|-h) startUsage; return 0;;
			--no-prompt|-np) noPrompt="--no-prompt";;
			--quiet|-q) quiet="--quiet";;
			--sudo|-s) sudov || return; sudo="sudo";;
			--terminal|-T) [[ ! $2 ]] && { startUsage; return 1; }; terminal="$2"; shift;;
			--verbose|-v|-vv|-vvv|-vvvv|-vvvvv) ScriptOptVerbose "$1";;
			--wait|-w) wait="--wait";;
			--window-style|-ws) [[ ! $2 ]] && { startUsage; return 1; }; windowStyle=( "--window-style" "$2" ); shift;;
			*)
				! IsOption "$1" && [[ ! $file ]] && { file="$1"; shift; break; }
				UnknownOption "$1" start; return
		esac
		shift
	done

	[[ ! "$file" ]] && { MissingOperand "file" "start"; return; }

	local args=( "$@" ) fileOrig="$file"

	# start Mac application 
	if IsMacApp "$file"; then
		
		# find the physical app location if possible
		[[ ! -d "$file" ]] && file="$(GetFileNameWithoutExtension "$file")"
		[[ ! -d "$file" && -d "$P/$file.app" ]] && file="$P/$file.app"
		[[ ! -d "$file" && -d "$HOME/Applications/$file.app" ]] && file="$P/$file.app"

		# we could not find the app, just try and open it
		[[ ! -d "$file" ]] && { open -a "$file" "${args[@]}"; return; }

		# open the app, waiting for the OS to see newly installed apps if needed
		local result; result="$(open -a "$file" "${args[@]}")" && return
		[[ ! "$result" =~ "Unable to find application named" ]] && { ScriptErrQuiet "$result" "start"; return 1; }
		StartWaitExists "$file"; return

	fi

	# find file in path
	[[ "$(GetCommandType "$file")" == "file" ]] && file="$(FindInPath "$file")"

	# open directories, URLs, and non-executable files
	if [[ -d "$file" ]] || IsUrl "$file" || { [[ -f "$file" ]] && ! IsExecutable "$file"; }; then

		# get the full path of files
		[[ -f "$file" ]] && file="$(GetFullPath "$file")"

		# determin open program
		local open=()
		if [[ -d "$file" ]]; then explore "$file"; return
		elif IsPlatform mac; then open=( open )
		elif IsPlatform win; then open=( explorer.exe )
		elif InPath xdg-open; then open=( xdg-open )
		else ScriptErrQuiet "unable to open '$fileOrig'" "start"; return 1
		fi

		# open
		(( verboseLevel > 1 )) && ScriptMessage "opening file '$file'" "start"
		(
			#IsPlatform win && ! drive IsWin . && cd "$WIN_ROOT"
			start $verbose "${open[@]}" "$file" "${args[@]}";
		)		
		return
	fi

	# validate file exists
	[[ ! -f "$file" ]] && { ScriptErrQuiet "unable to find '$fileOrig'" "start"; return 1; }

	# start files with a specific extention
	case "$(GetFileExtension "$file")" in
		cmd) (IsPlatform win && ! drive IsWin . && cd "$WIN_ROOT"; cmd.exe /c "$(utw "$(GetFullPath "$file")")" "${args[@]}"; ); return;;
		js|vbs) start cscript.exe /NoLogo "$file" "${args[@]}"; return;;
	esac

	# start Windows processes, or start a process on Windows elevated
	if IsPlatform win && ( [[ $elevate ]] || IsWindowsProgram "$file" ) ; then
		local fullFile="$(GetFullPath "$file")"

		# convert POSIX paths to Windows format (i.e. c:\...) if needed
		if IsWindowsProgram "$file"; then
			local a newArgs=()
			for a in "${args[@]}"; do 
				[[  -e "$a" || ( ! "$a" =~ .*\\.* && "$a" =~ .*/.* && -e "$a" ) ]] && { newArgs+=( "$(utw "$a")" ) || return; } || newArgs+=( "$a" )
			done
			args=("${newArgs[@]}")
		fi

		# file:// convert HOME directory in Windows, example: start 'ms-word:ofe|u|file:/~/Juntos%20Holdings%20Dropbox/test.docx'
		if IsPlatform win && [[ "${args[1]}" =~ file: ]]; then
			local newHome="$(utw "$WIN_HOME" | BackToForwardSlash | RemoveTrailingSlash)"
			local s="${args[1]}"
			s="${s/\~/$newHome}"
			s="${s/$HOME/$newHome}"
			args[1]="$s"
		fi

		# start Windows console process
		[[ ! $elevate ]] && IsConsoleProgram "$file" && { $sudo "$fullFile" "${args[@]}"; return; }

		# escape spaces for shell scripts so arguments are preserved when elevating - we must be elevating scripts here
		if IsShellScript "$fullFile"; then	
			IsBash && for (( i=0 ; i < ${#args[@]} ; ++i )); do args[$i]="${args[$i]// /\\ }"; done
			IsZsh && for (( i=1 ; i <= ${#args[@]} ; ++i )); do args[$i]="${args[$i]// /\\ }"; done	
		fi

		# start the program
		if IsShellScript "$fullFile"; then
			local distribution; distribution="$(wsl get name)" || return
			local p=(wsl.exe --distribution "$distribution" --user "$USER"); [[ "$terminal" == "wt" ]] && InPath wt.exe && p=(wt.exe -d \"$PWD\" "${p[@]}")
			local runProcessArgs=($wait $elevate "${windowStyle[@]}"); [[ $verbose ]] && runProcessArgs+=(--verbose --pause)
			(( verboseLevel > 1 )) && ScriptArgs RunWin RunProcess.exe "${runProcessArgs[@]}" "${p[@]}" --exec "$(FindInPath "$fullFile")" "${args[@]}"
			RunWin RunProcess.exe "${runProcessArgs[@]}" "${windowStyle[@]}" "${p[@]}" --exec "$(FindInPath "$fullFile")" "${args[@]}"

		else
			(( verboseLevel > 1 )) && ScriptArgs "start" RunProcess.exe $wait $elevate "${windowStyle[@]}" "$(utw "$fullFile")" "${args[@]}"
			if InPath RunProcess.exe; then
				RunWin RunProcess.exe $wait $elevate "${windowStyle[@]}" "$(utw "$fullFile")" "${args[@]}"
			else
				"$fullFile" "${args[@]}"
			fi
		fi
		result=$?

		return $result
	fi

 	# run a non-Windows program
 	if IsShellScript "$file"; then
 		(( verboseLevel > 1 )) && ScriptArgs "start" $sudo "$file" "${args[@]}"
 		$sudo "$file" "${args[@]}"
	elif [[ $wait ]]; then
		(( verboseLevel > 1 )) && ScriptArgs "start" nohup $sudo "$file" "${args[@]}"
		(
			nohup $sudo "$file" "${args[@]}" >& /dev/null &
			wait $!
		)
	else
		(( verboseLevel > 1 )) && ScriptArgs "start" nohup $sudo "$file" "${args[@]}"
		(nohup $sudo "$file" "${args[@]}" >& /dev/null &)
	fi
}

# SystemdConf - configure systemd
SystemdConf()
{
	# configure runtime directory - must be owned by $USER
	local dir="/run/user/$(${G}id -u)"
	[[ ! -d "$dir" ]] && { sudo mkdir "$dir" || return; }
	[[ "$(stat -c '%U' "$XDG_RUNTIME_DIR")" != "$USER" ]] && { sudo chown "$USER" "$XDG_RUNTIME_DIR"; }

	return 0
}

#
# Python
#

PythonGetConfig() { local var="$1"; python3 -m "sysconfig" | grep "$var = " | head -1 | cut -d= -f2 | RemoveSpace | RemoveQuotes; }
PythonManageDisable() { local file; file="$(PythonGetConfig "DESTLIB")/EXTERNALLY-MANAGED" || return; [[ ! -f "$file" ]] && return; sudoc mv "$file" "$file.hold"; }
PythonManageEnable() { local file; file="$(PythonGetConfig "DESTLIB")/EXTERNALLY-MANAGED" || return; [[ ! -f "$file.hold" ]] && return; sudoc mv "$file.hold" "$file"; }

# PythonConf - configure Python for the current user
PythonConf()
{
	local force forceLevel forceLess; ScriptOptForce "$@"

	# configure
	if [[ $force || ! $PYTHON_CHECKED ]]; then

		# return if python is not installed
		! InPath python3 && { PYTHON_CHECKED="true"; return; }
	 
		# find locations
		export PYTHON_USER_SITE; PYTHON_USER_SITE="$(python3 -m site --user-site)" || return
		export PYTHON_USER_BIN; PYTHON_USER_BIN="$(python3 -m site --user-base)/bin" || return

		[[ ! -d "$PYTHON_USER_SITE" ]] && { ScriptErr "The Python user site directory '$(FileToDesc "$PYTHON_USER_SITE")' does not exist" "PythonConf"; PYTHON_CHECKED="true"; return 1; }
		[[ ! -d "$PYTHON_USER_BIN" ]] && { ScriptErr "The Python user bin directory '$(FileToDesc "$PYTHON_USER_BIN")' does not exist" "PythonConf"; PYTHON_CHECKED="true"; return 1; }

		# add to path
		local front; IsPlatform mac && front="front"
		PathAdd "$front" "$PYTHON_USER_BIN" # $HOME/.local/bin
		
		PYTHON_CHECKED="true"
	fi

	# configure direnv for virtual environments
	if [[ -f ".envrc" ]] && InPath direnv; then
		DirenvConf || return
		${G}grep --quiet pyenv ".envrc" && { PyenvConf || return; }
	fi

	return 0
}

# PyEnvCreate [dir](.) [version] - make a Python virtual environment in the current directory
PyEnvCreate()
{
	local dir="$1"; [[ $dir ]] && shift || { MissingOperand "dir" "PyEnvCreate"; return; }
	local v="$1" vOrig="$1"

	# create the directory
	[[ ! -d "$dir" ]] && { ${G}mkdir --parents "$dir" || return; }
	cd "$dir" || return

	# initialize
	DirenvConf || return
	[[ $v ]] && { PyEnvConf || return; }
	
	# configure
	if [[ ! -f ".envrc" ]]; then
		local layout="layout python3"; 
		if [[ $v ]]; then
			v="$(pyenv versions --bare --skip-envs | ${G}grep "$v" | sort --version-sort --reverse | head -1)"
			[[ ! $v ]] && { ScriptErr "Python version '$vOrig' is not installed" "PyenvMake"; return 1; }
			layout="layout pyenv $v"
		fi
		echo "$layout" > ".envrc" || return
	fi

	# create the environment
	direnv allow	
}

# PyenvConf - configure pyenv to mange multiple Python versions
PyEnvConf()
{
	# initialize
	[[ ! -d "$HOME/.pyenv" ]] && { ScriptErr "pyenv is not installed" "PyenvConf"; return 1; }	
	export PYENV_ROOT="$HOME/.pyenv"

	# add to path
	PathAdd front "$PYENV_ROOT/bin"

	# configure
	eval "$(pyenv init -)"
}

# prl - Python run local, run a Python program freom the current users Python bin directory
prl()
{
	[[ ! $PYTHON_CHECKED ]] && { PythonConf || return; }
	"$PYTHON_USER_BIN/$@"
}

# PythonRootConf - configure Python for the root user
PythonRootConf()
{
	local force forceLevel forceLess; ScriptOptForce "$@"
	( [[ ! $force && $PYTHON_ROOT_CHECKED ]] || ! InPath python3 ) && return
	 
	# find locations
	sudov || return
	export PYTHON_ROOT_SITE; PYTHON_ROOT_SITE="$(sudo --set-home python3 -m site --user-site)" || return
	export PYTHON_ROOT_BIN; PYTHON_ROOT_BIN="$(sudo --set-home python3 -m site --user-base)/bin" || return

	! sudo ls "$PYTHON_ROOT_SITE" >& /dev/null && { ScriptErr "The Python root site directory '$(FileToDesc "$PYTHON_ROOT_SITE")' does not exist" "PythonConfRoot"; return 1; }
	! sudo ls "$PYTHON_ROOT_BIN" >& /dev/null && { ScriptErr "The Python root bin directory '$(FileToDesc "$PYTHON_ROOT_BIN")' does not exist" "PythonConfRoot"; return 1; }

	PYTHON_ROOT_CHECKED="true"
}

# prr - Python run root, run a Python program freom the root users Python bin directory
prr()
{
	[[ ! $PYTHON_ROOT_CHECKED ]] && { PythonRootConf || return; }	
	sudoc --set-home "$PYTHON_ROOT_BIN/$@"
}


# pipl|pipr - run pip the global or local user
pipl() { prl pip "$@"; }
pipr() { prr pip "$@"; }

# pipxl - pipx global, run pipx programs for the local user
pipxl() { prl pipx "$@"; }

# pipxg - pipx global, run pipx programs for the global (shared) location
pipxg()
{
	[[ ! $PYTHON_ROOT_CHECKED ]] && { PythonRootConf || return; }	
	local openSslPrefix="/usr"; IsPlatform mac && openSslPrefix="$HOMEBREW_PREFIX/opt/openssl@3/"
	sudoc --set-home PIPX_HOME="$ADATA/pipx" PIPX_BIN_DIR="/usr/local/bin" BORG_OPENSSL_PREFIX="$openSslPrefix" "$PYTHON_ROOT_BIN/pipx" "$1" "${@:2}"
}

#
# scripts
#

FilterShellScript() { grep -E "shell script|bash.*script|Bourne-Again shell script|\.sh:|\.bash.*:"; }
IsInstalled() { type "$1" >& /dev/null && command "$1" IsInstalled; }
IsShellScript() { file "$1" | FilterShellScript >& /dev/null; }
IsDeclared() { declare -p "$1" >& /dev/null; } 		# IsDeclared NAME - NAME is a declared variable

# aliases
IsAlias() { type "$1" |& grep alias > /dev/null; } # IsAlias NAME - NAME is an alias
GetAlias() { local a=$(type "$1"); a="${a#$1 is aliased to \`}"; echo "${a%\'}"; }

# arguments
ExtraOperand() { ScriptErr "extra operand '$1'" "$2"; ScriptTry "$2"; }
IsOption() { [[ "$1" =~ ^-.* && "$1" != "--" ]]; }
IsWindowsOption() { [[ "$1" =~ ^/.* ]]; }
MissingOperand() { ScriptErr "missing $1 operand" "$2"; ScriptTry "$2"; }
MissingOption() { ScriptErr "missing $1 option" "$2"; ScriptExit; }
UnknownOption() { ScriptErr "unrecognized option '$1'" "$2"; ScriptTry "$2"; }

# functions
IsFunction() { declare -f "$1" >& /dev/null; } # IsFunction NAME - NAME is a function

# FindFunction NAME - find a function NAME case-insensitive
if IsZsh; then
	FindFunction() { print -l ${(ok)functions} | grep -iE "^${1}$" ; }
else
	FindFunction() { declare -F | grep -iE "^declare -f ${1}$" | sed "s/declare -f //"; return "${PIPESTATUS[1]}"; }
fi

# RunCache CACHE FUNCTION [ARGS] - run function if an update is needed
RunCache()
{
	local cache="$1"; shift
	! UpdateNeeded "$cache" && return
	"$@" && UpdateDone "$cache"
}

# RunFunction NAME [SUFFIX] -- [ARGS]- call a function if it exists, optionally with the specified suffix (i.e. nameSuffix)
RunFunction()
{
	# arguments
	local f="$1"; shift
	local suffix; [[ $1 && "$1" != "--" ]] && { suffix="$1"; shift; f+="$(UpperCaseFirst "$suffix")"; }
	[[ "$1" == "--" ]] && shift

	# if the function does not exist return without error
	! IsFunction "$f" && return

	# run the function
	"$f" "$@"
}

# RunFunctionExists NAME [SUFFIX|--] - return true if the run function exists
RunFunctionExists()
{
	local f="$1"; shift
	local suffix="$1"; [[ $suffix && "$suffix" != "--" ]] && f+="$(UpperCaseFirst "$suffix")"
	IsFunction "$f"
}

# RunFunctions NAME[,NAME...] -- [ARGS]- run functions
# - if showing timing exported variables are not set
RunFunctions()
{
	# arguments
	local function functions=() ignoreErrors result

	while (( $# != 0 )); do
		case "$1" in "") : ;;
			--ignore-errors|-ie) ignoreErrors="--ignore-errors";;
			*)
				[[ "$1" == "--" ]] && { shift; break; }
				if ! IsOption "$1" && [[ ! $s ]]; then s="$1"
				elif ! IsOption "$1"; then functions+=("$1")
				else UnknownOption "$1" "RunFunctions"; return
				fi
		esac
		shift
	done

	# run functions
	for function in "${functions[@]}"; do

		# time function
		if [[ $timerOn ]]; then
			printf "$(StringPad "$function:" 20) "; time ("$function" "$@" $force $quiet $verbose)			
		else
			"$function" "$@" $force $quiet $verbose
		fi
		result="$?"
		
		if (( result != 0 )); then
			ScriptErr "$function failed with result $result"
			[[ ! $ignoreErrors ]] && return 1
		fi

	done

	return 0
}

# scripts
ScriptArgs() { PrintErr "$1: "; shift; printf "\"%s\" " "$@" >&2; echo >&2; } 						# ScriptArgs SCRIPT_NAME ARGS... - display script arguments
ScriptCheckMac() { IsMacAddress "$1" && return; ScriptErr "'$1' is not a valid MAC address"; }
ScriptErr() { [[ $1 ]] && HilightErr "$(ScriptPrefix "$2")$1" || HilightErr; return 1; }	# ScriptErr MESSAGE SCRIPT_NAME - hilight a script error message as SCRIPT_NAME: MESSAGE
ScriptErrEnd() { [[ $1 ]] && HilightErrEnd "$(ScriptPrefix "$2")$1" || HilightErrEnd; return 1; }
ScriptErrQuiet() { [[ $quiet ]] && return 1; ScriptErr "$@"; }
ScriptExit() { [[ "$-" == *i* ]] && return "${1:-1}" || exit "${1:-1}"; }; 								# ScriptExit [STATUS](1) - return or exist from a script with the specified status
ScriptFileCheck() { [[ -f "$1" ]] && return; [[ ! $quiet ]] && ScriptErr "file '$1' does not exist"; return 1; }
ScriptMessage() { EchoErr "$(ScriptPrefix "$2")$1"; } 																		# ScriptMessage MESSAGE - log a message with the script prefix
ScriptPrefix() { local name="$(ScriptName "$1")"; [[ ! $name ]] && return; printf "%s" "$name: "; }
ScriptReturnError() { [[ $suppressErrors ]] && echo 0 || echo 1; }
ScriptTry() { EchoErr "Try '$(ScriptName "$1") --help' for more information."; ScriptExit; }
ScriptTryVerbose() { EchoErr "Use '--verbose' for more information."; ScriptExit; }

# ScriptCd PROGRAM [ARG...] - run a script and change to the first directory returned
ScriptCd()
{
	[[ ! $@ ]] && { MissingOperand "program" "ScriptCd"; return 1; }
	local dir="$("$@" | ${G}head --lines=1)" || return # run the script
	[[ ! $dir ]] && { ScriptErr "directory not returned" "ScriptCd"; return 1; }
	[[ ! -d "$dir" ]] && { ScriptErr "'$dir' is not a valid directory" "ScriptCd"; return 1; }
	echo "cd $dir"; DoCd "$dir"
}

# ScriptDir - return the directory of the root script
ScriptDir()
{
	local dir="$0"; IsZsh && dir="$ZSH_SCRIPT"
	GetFilePath "$(GetFullPath "$dir")"; 
}


# ScriptEval <script> [<arguments>] - run a script and evaluate the output
# - typically the output is variables to set, such as printf "a=%q;b=%q;" "result a" "result b"
ScriptEval() { local result; export SCRIPT_EVAL="true"; result="$("$@")" || return; eval "$result"; unset SCRIPT_EVAL; } 

# ScriptName [func] - return the function, or the name of root script
ScriptName()
{
	local func="$1"; [[ $func ]] && { printf "%s" "$func"; return; }
	local name="$0"; IsZsh && name="$ZSH_SCRIPT"
	name="$(GetFileName "$name")"; [[ "$name" == "function.sh" ]] && unset name
	printf "$name" 
}

# ScriptOptForce - find force option.  Sets force, forceLevel, and forceLess.
ScriptOptForce()
{
	while (( $# > 0 )) && [[ "$1" != "--" ]]; do 
		case "$1" in
			-f|--force) force="-f"; forceLevel=1;;
			-ff) force="-ff"; forceLevel=2;;
			-fff) force="-fff"; forceLevel=3;;
		esac
		shift; 
	done

	(( forceLevel > 1 )) && forceLess="-$(StringRepeat "f" "$(( forceLevel - 1 ))")"

	return 0
}

# ScriptOptVerbose - find verbose option.  Sets verbose, verboseLevel, and verboseLess.
ScriptOptVerbose()
{
	while (( $# > 0 )) && [[ "$1" != "--" ]]; do 
		case "$1" in
			-v|--verbose) verbose="-v"; verboseLevel=1;;
			-vv) verbose="-vv"; verboseLevel=2;;
			-vvv) verbose="-vvv"; verboseLevel=3;;
			-vvvv) verbose="-vvvv"; verboseLevel=4;;
			-vvvvv) verbose="-vvvvv"; verboseLevel=5;;
		esac
		shift; 
	done

	(( verboseLevel > 1 )) && verboseLess="-$(StringRepeat "v" "$(( verboseLevel - 1 ))")"

	return 0
}

# ScriptOptQuiet - find quiet option
ScriptOptQuiet()
{
	opts=()
	while (( $# > 0 )) && [[ "$1" != "--" ]]; do 
		case "$1" in
			--quiet|-q) quiet="--quiet";;
			*) opts+=("$1")
		esac
		shift; 
	done
}

# ScriptReturn <var>... - return the specified variables as output from the script in an escaped format
#   The script should be called using ScriptEval.
#   -e, --export		the returned variables should be exported
ScriptReturn() 
{
	local var avar fmt="%q" arrays export # fmt="\"%s\"" # for testing
	[[ "$1" == @(-e|--export) ]] && { export="export "; shift; }

	# cache array lookup for performance
	arrays="$(declare -p "$@" |& grep "^declare -a" 2> /dev/null)"

	for var in "$@"; do
		check=".*declare -a ${var}=.*"

		# array
		if [[ "$arrays" =~ $check ]]; then
			avar="$var[@]"
			printf "$var=("
			for value in "${!avar}"; do printf "$fmt " "$value"; done; 
			echo ") "

		# other variable
		else
			printf "$export$var=$fmt\n" "${!var}"
		fi
	done
}

#
# security
#

CertGetDates() { local c; for c in "$@"; do echo "$c:"; SudoRead "$c" openssl x509 -in "$c" -text | grep "Not "; done; }
CertView() { local c; for c in "$@"; do openssl x509 -in "$c" -text; done; }
CredentialSetBoth() { credential set "$@" --manager=local && credential set "$@" --manager=remote; }

# CredentialConf - configure the credential manager but do not unlock (to prevent password prompt)
CredentialConf()
{
	local force forceLevel forceLess; ScriptOptForce "$@"
	local verbose verboseLevel verboseLess; ScriptOptVerbose "$@"

	# return if credential configuration is set
	[[ ! $force && $CREDENTIAL_MANAGER_CHECKED ]] && return

	# configure credentials
	(( verboseLevel > 1 )) && header "Credential Configuration"
	ScriptEval credential environment $verbose "$@" || { export CREDENTIAL_MANAGER="None" CREDENTIAL_MANAGER_CHECKED="true"; return 1; }
}


# CredentialConfStatus - configure, unlock, and show the status of the credential manager
CredentialConfStatus() { CredentialConf "$@" && credential manager unlock && credential manager status; }

# IsElevated - return true if the user has an Administrator token, always true if not on Windows
IsElevated() 
{ 
	! IsPlatform win && return 0

	# if the user is in the Administrators group they have the Windows Administrator token
	# cd / to fix WSL 2 error running from network share
	RunWin whoami.exe /groups | grep 'BUILTIN\\Administrators' | grep "Enabled group" >& /dev/null; 
} 

# sudo
SudoCheck() { [[ ! -r "$1" ]] && sudo="sudoc"; } # SudoCheck FILE - set sudo variable to sudoc if user does not have read permissiont to the file
sudox() { sudoc XAUTHORITY="$HOME/.Xauthority" "$@"; }
sudov() { sudoc "$@" -- sudo --validate; } # update the cached credentials if needed
IsSudo() { sudo --validate --non-interactive >& /dev/null; } # return true if the sudo credentials are cached

# sudoc COMMANDS - run COMMANDS using sudo and use the credential store to get the password if available
#   --no-prompt|-np   do not prompt or ask for a password
#   --preserve|-p   	preserve the existing path (less secure)
#   --stderr|-se   		prompt for a password using stderr
sudoc()
{ 
	# run the command - already root
	IsRoot && { env "$@"; return; } # use env to support commands with variable prefixes, i.e. sudoc VAR=12 ls

	# arguments
	local args=() noPrompt preserve stderr verbose verboseLevel verboseLess
	while (( $# != 0 )); do
		case "$1" in "") : ;;
			--no-prompt|-np) noPrompt="--no-prompt";;
			--preserve|-p) preserve="--preserve";;
			--stderr|-se) stderr="--stderr";;
			--verbose|-v|-vv|-vvv|-vvvv|-vvvvv) ScriptOptVerbose "$1";;
			--) shift; args+=("$@"); break;;
			*) args+=("$1");;
		esac
		shift
	done

	# set variables
	local prompt="[sudoc] password for $USER on $HOSTNAME: "
	local command=( "$(FindInPath "sudo")" )
	
	# do not prompt no prompt if there is no stdin
	! IsStdIn && noPrompt="--no-prompt"

	# determine environment variables need to be preserved when running sudo
	if [[ $preserve ]]; then
		if IsPlatform pi; then command+=(--preserve-env)
		elif ! IsPlatform mac; then command+=(--preserve-env=PATH)
		fi
	fi

	# run the command - sudo credentials are cached
	IsSudo && { "${command[@]}" --prompt="" "${args[@]}"; return; } 

	# determine which password to use
	local passwordName="secure"
	if InPath opensc-tool && opensc-tool --list-readers | ${G}grep --quiet "Yes"; then passwordName="ssh"
	elif IsDomainRestricted && echo "BOGUS" | { sudo --stdin --validate 2>&1; true; } | ${G}grep --quiet "^Enter PIN"; then passwordName="ssh"  
	fi

	# get password if possible, ignore errors so we can prompt for it
	local password; password="$(credential --quiet get $passwordName default $verbose)"

	# prompt for password to stdout or stderr if possible, prevent sudo from asking for a password
	if [[ ! $noPrompt && ! $password ]]; then
		if [[ ! $stderr ]] && IsStdOut; then		
			PrintEnd "$prompt" || return
		elif IsStdErr; then
			PrintErr "$prompt" || return
		else
			noPrompt="--no-prompt"
		fi
	fi

	# validate sudo to cache credentials
	# - do separately from running the command so can use stdin in the command
	if [[ $password ]]; then
		echo "$password" | "${command[@]}" --prompt="" --stdin --validate
	else
		[[ $noPrompt ]] && command+=(--non-interactive)
		"${command[@]}" --prompt="" --validate
	fi
	(( $? != 0 )) && { ScriptErrEnd "unable to run command '"${args[@]}"'" "sudoc"; return 1; }

	# run the command
	# - do not use -- to allow environment variables, i.e. sudoc TEST=1 ls
	"${command[@]}" --prompt="" "${args[@]}"
} 

# sudoe FILE - sudoedit with credentials
sudoe()  
{ 
	local file="$1"; ScriptFileCheck "$file" || return

	# edit Windows files
	if IsPlatform win && IsWindowsFile "$1"; then
		if sublime IsRunning; then # sublime will not run elevated if it is already running
			echo "Running Notepad elevates since Sublime is already running..."
			elevate notepad.exe "$@"; return
		else
			elevate sublime start "$@"; return;
		fi
	fi

	# edit file directly if we are root
	IsRoot && { sudoedit "$@"; return; }

	# edit the file
	if InPath sudoedit && credential -q exists secure default; then
		SUDO_ASKPASS="$BIN/SudoAskPass" sudoedit --askpass "$@"
	elif InPath sudoedit; then
		sudoedit "$@"
	else
		sudo nano "$@" 
	fi
} 

# sudor [COMMAND|--dir|-d DIR] - run commands or a shell as root with access to the users SSH Agent and credential manager
# - if DIR is specified, start an interactive shell in the specified DIR
# - test: sudor && sudor --dir /tmp && sudor credential ls -m=r
sudor()
{
	local bash=(bash -i -l); IsPlatform mac && bash=(bash -l)
	[[ $# == 0 ]] && set -- "${bash[@]}"
	[[ $# == 2 && "$1" =~ (--dir|-d) ]] && set -- "${bash[@]}" -c "cd \"$2\"; ${bash[*]}"

	# let the root command use our credential manager, ssh-agent, and Vault token
	sudox \
		CREDENTIAL_MANAGER="$CREDENTIAL_MANAGER" CREDENTIAL_MANAGER_CHECKED="$CREDENTIAL_MANAGER_CHECKED" \
		SSH_AUTH_SOCK="$SSH_AUTH_SOCK" SSH_AGENT_PID="$SSH_AGENT_PID" \
		VAULT_TOKEN="$VAULT_TOKEN" \
		"$@"
}

# SudoRead FILE COMMAND - use sudoc to run the command if the file is not readable
SudoRead()
{
	local file="$1"; shift
	local sudo; [[ ! -r "$file" ]] && sudo="sudoc"
	$sudo "$@"
}

#
# text processing
#

tac() { InPath tac && command tac "$@" | cat "$@"; }
Utf16toAnsi() { iconv -f utf-16 -t ISO-8859-1; }
Utf16to8() { iconv -f utf-16 -t UTF-8; }

# shead - sponge head
# - prevents termination of the pipeline with SIGPIPE when head terminates
# - the rest of the output from the pipe is discarded (sent to /dev/null with cat)
shead() { ${G}head "$@"; cat > /dev/null; }

# sqgrep - sponge quiet grep - prevents termination of the pipeline with SIGPIPE when grep terminates before early with a match
sqgrep() { local result; qgrep "$@"; result=$?; cat > /dev/null; return $result; }
qgrep() { ${G}grep --quiet "$@"; }

# true grep - always return 0
# - normally 0=text found, 1=text not found, 2=error
# - on macOS ggrep returns 1 if no text found or error (i.e. invalid arguments)
tgrep() { ${G}grep "$@"; true; }

# editor

GetTextEditor()
{
	local e force; ScriptOptForce "$@"
	local isSsh; IsSsh && isSsh="true"
	local isSshX; [[ $isSsh && $DISPLAY ]] && isSshX="true"

	# cache
	local cache="get-text-editor"
	if [[ $isSshX ]]; then cache+="-sshx"
	elif [[ $ssh ]]; then cache+="-ssh"
	fi

	if ! e="$(UpdateGet "$cache")" || [[ ! $e ]]; then
		e="$(
			# initialize
			local sublimeProgram="$(sublime program)"

			# native
			if [[ ! $isSsh ]]; then
				[[ $sublimeProgram ]] && { echo "$sublimeProgram"; return 0; }
				IsPlatform win && InPath "$P/Notepad++/notepad++.exe" && { echo "$P/Notepad++/notepad++.exe"; return 0; }
				IsPlatform mac && { echo "TextEdit.app"; return 0; }
				IsPlatform win && InPath notepad.exe && { echo "notepad.exe"; return 0; }
			fi

			# X Windows
			if ! IsPlatform mac && [[ $DISPLAY ]]; then
				IsPlatform win && sublimeProgram="$(sublime program --alternate)"
				[[ $sublimeProgram ]] && { echo "$sublimeProgram"; return 0; }
				InPath geany && { echo "geany"; return 0; }
				InPath gedit && { echo "gedit"; return 0; }
			fi

			# console
			InPath micro && { echo "micro"; return 0; }
			InPath nano && { echo "nano"; return 0; }
			InPath hx && { echo "hx"; return 0; }
			InPath vi && { echo "vi"; return 0; }

			return 1
		)" || { ScriptErr "no text editor found" "GetTextEditor"; return 1; }
		UpdateSet "$cache" "$e"
	fi

	echo "$e"
}

# GetTextEditorCli - get the default CLI text editor for commands, which must:
# - be a physical file in the path 
# - accept a UNIX style path as the file to edit
# - return only when the file has been edited
GetTextEditorCli()
{
	local e cache="get-text-editor-cli" force; ScriptOptForce "$@"

	if ! e="$(UpdateGet "$cache")"; then
		if IsInstalled sublime; then e="$BIN/sublime -w"
		elif InPath geany; then e="geany -i"
		elif InPath micro; then e="micro"
		elif InPath nano; then e="nano"
		elif InPath vi; then e="vi"
		else ScriptErr "no CLI text editor found" "GetTextEditorCli"; return 1
		fi
		UpdateSet "$cache" "$e"
	fi

	echo "$e"
}

# SetTextEditor - set EDITOR, EDITOR_PROGRAM, and SUDO_EDITOR
SetTextEditor()
{
	local e cache="set-text-editor" force; ScriptOptForce "$@"

	[[ ! $force && $EDITOR && $EDITOR_PROGRAM && $SUDO_EDITOR ]] && return

	if ! e="$(UpdateGet "$cache")"; then
		e="$(cat <<-EOF
			export {SUDO_EDITOR,EDITOR}="$(GetTextEditorCli "$@")"
			export EDITOR_PROGRAM="$(GetTextEditor "$@")"
			EOF
		)"
		UpdateSet "$cache" "$e"
	fi

	eval "$e"
}

# JSON
JsonIsValid() { GetArgs; echo "$1" | jq '.' >& /dev/null; }
JsonGetKeyArg() { local key="$1"; [[ ! "$key" == *.* ]] && key=".$key"; echo "$key"; }
JsonGetKey() { GetArgs2; echo "$1" | jq -e "$(JsonGetKeyArg "$2")" | RemoveQuotes; }
JsonHasKey() { GetArgs2; local key="$2"; echo "$1" | jq -e "select($(JsonGetKeyArg "$2") != null)" >& /dev/null; }
JsonLog() { GetArgs2; (( verboseLevel < ${2} )) && return; ScriptMessage "json="; echo "$1" | jq >&2; } # JsonLog [JSON] [VERBOSE_LEVEL]

# JsonValidate JSON [ERROR_PATH](error) [ERROR_DESCRIPTION_PATH](ERROR_PATH) - validate the passed value is valid JSON.   If it contains and ERROR_PATH key show it.
JsonValidate()
{
	# arguments
	local json="$1" errorPath="${2:-error}"; local errorDescriptionPath="${3:-$errorPath}"

	# invalid json
	! JsonIsValid "$json" && { log1 "json='$json'"; ScriptErrQuiet "the JSON is not valid"; return 1; }	

	# no error
	! JsonHasKey "$json" "$errorPath" && return

	# show error - the error description if present, otherwise a generic error
	JsonLog "$json" 2
	local errorDescription; errorDescription="$(JsonGetKey "$json" "$errorDescriptionPath" | UnQuoteQuotes)"
	[[ ! $errorDescription || "$errorDescription" == "null" ]] && errorDescription="$(JsonGetKey "$json" "$errorPath" | UnQuoteQuotes)"
	[[ ! $errorDescription || "$errorDescription" == "null" ]] && errorDescription="the API call returned an error"
	log2 "errorPath=$errorPath error='$error' errorDescriptionPath=$errorDescriptionPath errorDescription='$errorDescription'"
	ScriptErrQuiet "$errorDescription"
}

#
# virtual machine
#

IsChroot() { GetChrootName; [[ $CHROOT_NAME ]]; }
ChrootName() { GetChrootName; echo "$CHROOT_NAME"; }
ChrootPlatform() { ! IsChroot && return; [[ $(uname -r) =~ [Mm]icrosoft ]] && echo "win" || echo "linux"; }

IsContainer() { ! InPath systemd-detect-virt && return 1; [[ "$(systemd-detect-virt --container)" != @(none|wsl) ]]; }
IsDocker() { ! InPath systemd-detect-virt && return 1; [[ "$(systemd-detect-virt --container)" == "docker" ]]; }
IsVm() { GetVmType; [[ $VM_TYPE ]]; }
IsParallelsVm() { GetVmType; [[ "$VM_TYPE" == "parallels" ]]; }
IsProxmoxVm() { GetVmType; [[ "$VM_TYPE" == "proxmox" ]]; }
IsVmwareVm() { GetVmType; [[ "$VM_TYPE" == "vmware" ]]; }
IsHypervVm() { GetVmType; [[ "$VM_TYPE" == "hyperv" ]]; }
VmType() { GetVmType; echo "$VM_TYPE"; }

GetChrootName()
{
	local force forceLevel forceLess; ScriptOptForce "$@"
	local verbose verboseLevel verboseLess; ScriptOptVerbose "$@"
	[[ ! $force && $CHROOT_CHECKED ]] && return
	
	if [[ -f "/etc/debian_chroot" ]]; then
		CHROOT_NAME="$(cat "/etc/debian_chroot")"
	elif ! IsPlatform winKernel && [[ "$(${G}stat / --printf="%i")" != "2" ]]; then
		CHROOT_NAME="chroot"
	elif IsPlatform wsl1 && sudoc systemd-detect-virt -r; then
		CHROOT_NAME="chroot"
	fi

	[[ $verbose ]] && { ScriptErr "CHROOT_NAME=$CHROOT_NAME"; }	
	CHROOT_CHECKED="true"
}

# GetVmType - cached to avoid multiple sudo calls
GetVmType() # vmware|hyperv
{	
	local force forceLevel forceLess; ScriptOptForce "$@"
	local verbose verboseLevel verboseLess; ScriptOptVerbose "$@"
	[[ ! $force && $VM_TYPE_CHECKED ]] && return

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
	[[ -d "$P/Parallels" ]] && result="parallels"

	# In wsl2, Hyper-V is detected on the physical host and the virtual machine as "microsoft" so check the product
	if IsPlatform wsl2 && [[ "$result" == "hyperv" ]]; then
		local product

		if InPath wmic.exe; then
			product="$(RunWin wmic.exe baseboard get product |& RemoveCarriageReturn | head -2 | ${G}tail --lines=-1 | RemoveSpaceTrim)"

		# wmic.exe is removed from Windows build  >= 22000.376
		# - PowerShell 5 (powershell.exe) is ~6X faster than PowerShell 7
		# - PowerShell 7 - use powershell without the .exe
		else
			product="$(RunWin powershell.exe 'Get-WmiObject -Class Win32_BaseBoard | Format-List Product' | RemoveCarriageReturn | grep Product | tr -s ' ' | cut -d: -f2 | RemoveSpaceTrim)"
		fi

		if [[ "$product" == "440BX Desktop Reference Platform" ]]; then result="vmware"
		elif [[ "$product" == "Virtual Machine" ]]; then result="hyperv"
		elif [[ "$product" == "" ]]; then result="proxmox"
		else result=""
		fi
	fi

	[[ $verbose ]] && { ScriptErr "VM_TYPE=$VM_TYPE"; }
	export VM_TYPE_CHECKED="true" VM_TYPE="$result"
}

#
# window
#

HasWindowManager() { ! IsSsh || IsXServerRunning; } # assume if we are not in an SSH shell we are running under a Window manager
RestartGui() { IsPlatform win && { RestartExplorer; return; }; IsPlatform mac && { RestartDock; return; }; }
WinExists() { ! IsPlatform win && return 1; ! tasklist.exe /fi "WINDOWTITLE eq $1" | grep --quiet "No tasks are running"; }

InitializeXServer()
{
	local force forceLevel forceLess; ScriptOptForce "$@"
	[[ ! $force && $X_SERVER_CHECKED ]] && return

	# return if X is not installed
	! InPath xauth && return

	# arguments
	local quiet 

	while (( $# != 0 )); do
		case "$1" in "") : ;;
			--force|-f|-ff|-fff) ScriptOptForce "$1";;
			--quiet|-q) quiet="--quiet";;
			*) $1; UnknownOption "$1" "InitializeXServer"; return 1;;
		esac
		shift
	done

	# display
	if [[ $force || ! $DISPLAY ]]; then
		if [[ $SSH_CONNECTION ]]; then
			export DISPLAY="$(GetWord "$SSH_CONNECTION" 1):0"
		elif IsPlatform wsl2 && CanElevate; then
			local ip="0.0.0.0"; ! wsl supports mirrored && ip="$(GetWslGateway)"
			export DISPLAY="$ip:0"
			export LIBGL_ALWAYS_INDIRECT=1
		else
			export DISPLAY=:0
		fi

		! IsXServerRunning && { unset DISPLAY; X_SERVER_CHECKED="true"; return; }

	fi

	# GWSL configuration 
	# export QT_SCALE_FACTOR=2
	# export GDK_SCALE=2

	# force GNOME applications to use X forwaring over SSH
	[[ $SSH_CONNECTION ]] && export GDK_BACKEND=x11 

	# add DISPLAY to the D-Bus activation environment
	if IsSsh && InPath dbus-launch dbus-update-activation-environment; then
		( # do not show job messages
			{ # run in background to allow login even if this hangs (if D-Bus is in a bad state)
				local result; result="$(dbus-update-activation-environment --systemd DISPLAY 2>&1)"
				if [[ "$result" != "" ]]; then
					[[ ! $quiet ]] && ScriptErr "unable to initialize D-Bus: $result" "InitializeXServer"
					return 1
				fi
			} &
		)
	fi

	X_SERVER_CHECKED="true"
}

# IsXServerRunning - was xprop -root >& /dev/null
IsXServerRunning()
{
	[[ ! $DISPLAY ]] && return 1
	local ip="$(GetWord "$DISPLAY" 1 ":")"

	if IsIpAddress "$ip"; then
		local timeout="$(AvailableTimeoutGet)"

		# quick timeout if the X Server is local
		if [[ "$ip" == @(0.0.0.0) ]] || { IsPlatform wsl && [[ "$ip" == @(GetWslGateway) ]]; }; then
			timeout=10 
		fi

		IsAvailablePort "$ip" 6000 "$timeout" || return
	fi
	
	InPath xhost && xhost >& /dev/null
}

WinSetStateUsage()
{
	EchoWrap "\
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
		! InPath WindowMode.exe && return
		RunWin WindowMode.exe -title "$title" -mode "${wargs[@]}"
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

# source other scripts
SourcePlatformScripts "$@" || return

export FUNCTIONS="true"
