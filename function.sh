# function.sh: common functions for non-interactive scripts

set -o pipefail # pipes return first non-zero result

# core setup
IsBash() { [[ $BASH_VERSION ]]; }
IsZsh() { [[ $ZSH_VERSION ]]; }
IsInteractiveShell() { [[ "$-" == *i* ]]; } # 0 if we are running at the command prompt, 1 if we are running from a script

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
	[[ $notSet ]] && ! [[ $quietPlatformConf || $quiet ]] && echo "PlatformConf: bash.bashrc was not set" >&2

	return 0
}
PlatformConf || return

# color - set color variables if colors are supported (if using a terminal).   Uses FORCE_COLOR or FORCE_NO_COLOR variables
alias InitColorVars='local colorVars=(GREEN RB_BLUE RB_INDIGO RED RESET); local "${colorVars[@]}"'												# InitColorVars - defines local color variables
InitColorCheck() { [[ $GREEN && $RB_BLUE && $RB_INDIGO && $RED && $RESET ]]; }																						# InitColorCheck - return true if all the color variables are initialized
InitColorCheckAny() { [[ $GREEN || $RB_BLUE || $RB_INDIGO || $RED || $RESET ]]; }																					# InitColorAny - return true if any color variables are initialized
InitColorClear() { GREEN="" RB_BLUE="" RB_INDIGO="" RED="" RESET=""; }																										# InitClear - clear color variables
InitColor() { [[ ! $FORCE_NO_COLOR ]] && { [[ $FORCE_COLOR ]] || IsStdOut; } && InitColorForce || InitColorClear; }				# InitColor - initialize color variables if we are forcing color or stdout is available
InitColorErr() { [[ ! $FORCE_NO_COLOR ]] && { [[ $FORCE_COLOR ]] || IsStdErr; } && InitColorForce || InitColorClear; } 		# InitColorErr - initialize color variables if we are forcing color or stderr is available
InitColorForce() { GREEN=$'\033[32m' RB_BLUE=$'\033[38;5;021m' RB_INDIGO=$'\033[38;5;093m' RED=$'\033[31m' RESET=$'\033[m'; }

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
GroupDefault() { ${G}id --group --name; }
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
	local scriptName="UserCreate" admin system sslCopy user password passwordShow; 

	# options
	while (( $# != 0 )); do
		case "$1" in "") : ;;
			--admin|-a) admin="--admin";;
			--system|-s) system="--system";;
			--ssh-copy) sshCopy="--ssh-copy";;
			*)
				if ! IsOption "$1" && [[ ! $user ]]; then user="$1"
				elif ! IsOption "$1" && [[ ! $password ]]; then password="$1"
				else UnknownOption "$1"; return
				fi
		esac
		shift
	done

	[[ ! $user ]] && { MissingOperand "user"; return; }
	[[ ! $password ]] && { passwordShow="true"; password="$(pwgen 14 1)" || return; }

	# create user
	if ! UserExists "$user"; then
		hilight "Creating user '$user'..."

		if IsPlatform mac; then
			local adminArg; [[ $admin || $system ]] && adminArg="-admin"			
			sudoc sysadminctl -addUser "$user" -password "$password" $admin || return

		elif [[ $system ]]; then
			sudoc useradd --create-home --system "$user" || return
			password change linux --user "$user" --password "$password" || return

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
	local scriptName="FindLoginShell" shell shells="/etc/shells";  IsPlatform entware && shells="/opt/etc/shells"

	[[ ! $1 ]] && { MissingOperand "shell"; return; }

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
IsVisualStudioCode() { [[ "$TERM_PROGRAM" == "vscode" ]]; }
! IsDefined sponge && alias sponge='cat'

# AppVersion app - return the version of the specified application
AppVersion()
{
	# arguments
	local scriptName="AppVersion" allowAlpha alternate app appOrig cache force forceLevel forceLess quiet version

	while (( $# != 0 )); do
		case "$1" in "") : ;;
			--cache|-c) cache="--cache";;
			--force|-f|-ff|-fff) ScriptOptForce "$1";;
			--quiet|-q) quiet="--quiet";;
			--alternate|-a) alternate="--alternate";;
			--allow-alpha|-aa) allowAlpha="--allow-alpha";;
			*)
				! IsOption "$1" && [[ ! $app ]] && { app="$(AppToCli "$1")" appOrig="$1"; shift; continue; }
				UnknownOption "$1"; return
		esac
		shift
	done

	[[ ! $app ]] && { MissingOperand "app"; return; }

	# cache
	local appCache="version-$(GetFileName "$app" | LowerCase)"
	[[ $alternate ]] && appCache+="-alternate"
	[[ $cache ]] && UpdateGet "$appCache" && return

	# get version with helper script
	local helper; helper="$(AppHelper "$app")" && { version="$(alternate="$alternate" "$helper" $quiet --version)" || return; }

	# find and get mac application versions
	local dir
	if [[ ! $version ]] && IsPlatform mac && dir="$(FindMacApp "$app")" && [[ -f "$dir/Contents/Info.plist" ]]; then
		[[ "$dir" =~ anyplaceusb ]] && return
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

	# get file extension
	local ext="$(GetFileExtension "$file" | LowerCase)"

	# special cases
	if [[ ! $version ]]; then
		case "$(LowerCase "$(GetFileName "$app")")" in
			apache|cowsay|cron|gtop|kubectl|lolcat|parallel) return;; # excluded, cannot get version
			7z) version="$(7z | head -2 | ${G}tail --lines=-1 | cut -d" " -f 3)" || return;;
			apt) version="$(apt --version | cut -d" " -f2)" || return;;
			bash) version="$(bash -c 'echo ${BASH_VERSION}' | cut -d"-" -f 1 | RemoveAfter "(")" || return;;
			bat) version="$(bat --version | cut -d" " -f2)";;
			btop) version="$(btop --version  | head -1 | cut -d":" -f2 | RemoveSpaceTrim | RemoveColor)" || return;;
			cfssl) version="$(cfssl version | head -1 | ${G}cut -d":" -f 2 | RemoveSpaceTrim)" || return;;
			consul) version="$(consul --version | head -1 | cut -d" " -f2 | RemoveFront "v")" || return;;
			cryfs|cryfs-unmount) version="$(cryfs --version | head -1 | cut -d" " -f3)";;
			damon) version="$(damon --version | head -1 | cut -d"v" -f2 | cut -d"-" -f1)" || return;;
			dbxcli) version="$(dbxcli version | head -1 | sed 's/.* v//')" || return;;
			dog) version="$(dog --version | head -2 | ${G}tail --lines=-1 | cut -d"v" -f2)" || return;;
			duf)
				version="$(duf --version | cut -d" " -f2)" || return
				! IsNumeric "$version" && IsPlatform mac && { version="$(command ls -l $(FindInPath duf) | ${G}sed 's/^.*duf\///' | ${G}cut -d"/" -f1)" || return; } # mac Homebrew --version is "built from source"
				;;
			exa) version="$(exa --version | head -2 | ${G}tail --lines=-1 | cut -d"v" -f2 | cut -d" " -f1)" || return;;
			eza) version="$(eza --version | head -2 | tail -1 | cut -d" " -f 1 | RemoveFront "v")" || return;;
			figlet|pyfiglet) version="$(pyfiglet --version | RemoveEnd ".post1")" || return;;
			fortune) version="$(fortune --version | cut -d" " -f2)" || return;;
			gcc) version="$(gcc --version | head -1 | cut -d" " -f4)" || return;;
			git-credential-manager) version="$(git-credential-manager --version | cut -d"+" -f1)" || return;;
			go) version="$(go version | head -1 | cut -d" " -f3 | RemoveFront "go")" || return;;
			java) version="$(java --version |& head -1 | cut -d" " -f2)" || return;;
			jq) version="$(jq --version |& cut -d"-" -f2)" || return;;
			keepalived) version="$(keepalived --version |& shead -1 | sed 's/.* v//' | cut -d" " -f1)" || return;;
			lazygit) version="$(lazygit --version | ${G}cut -d"=" -f5 | ${G}cut -d"," -f1)" || return;;
			minikube) version="$(echo "$(minikube version)" | head -1 | sed 's/.* v//')" || return;; # minicube pipe returns error on mac
			nginx) version="$(nginx -v |& sed 's/.*nginx\///' | cut -d" " -f1)";;
			node) version="$(node --version | RemoveFront "v")";;
			nomad) version="$(nomad --version | head -1 | cut -d" " -f2 | RemoveFront "v")" || return;;
			pip) version="$(pip --version | cut -d" " -f2)" || return;;
			procs) version="$(procs --version | cut -d" " -f2 | RemoveFront "\"")" || return;;
			python3) version="$(python3 --version | cut -d" " -f2)" || return;;
			remmina) version="$(command remmina --version |& grep "org.remmina.Remmina" | cut -d"-" -f2 | cut -d" " -f2)" || return;;
			rg) version="$(rg --version | shead -1 | cut -d" " -f 2)" || return;;
			ruby) version="$(ruby --version | cut -d" " -f2 | cut -d"p" -f 1)" || return;;
			speedtest-cli) allowAlpha="--allow-alpha"; version="$(speedtest-cli --version | head -1 | cut -d" " -f2)" || return;;
			sshfs) version="$(sshfs --version |& ${G}tail --lines=-1 | cut -d" " -f3)" || return;;
			tmux) version="$(tmux -V | cut -d" " -f2)" || return;;
			traefik) version="$(traefik version | ${G}grep "^Version:" | ${G}cut -d":" -f 2 | RemoveSpaceTrim)" || return;;
			vault) version="$(vault --version | cut -d" " -f2 | RemoveFront "v")" || return;;
			zsh) version="$("$app" --version | cut -d" " -f2)" || return;;
		esac
	fi

	# get Windows executable version
	if [[ ! $version ]] && IsPlatform win && [[ "$ext" == @(dll|exe) ]]; then
		version="$(AppVersionWin "$file")" || return
	fi

	# AppImage
	if [[ ! $version && "$ext" == "appimage" ]]; then
		version="$(echo "$file" | cut -d"-" -f2)"
	fi

	# call APP --version - where the version number is the last word of the first line
	[[ ! $version ]] && { version="$("$file" --version | head -1 | awk '{print $NF}' | RemoveCarriageReturn)" || return; }

	# validation
	[[ ! $version ]] && { ScriptErrQuiet "application '$appOrig' version was not found"; return 1; }	
	[[ ! $allowAlpha ]] && ! IsNumeric "$version" && { ScriptErrQuiet "application '$appOrig' version '$version' is not numeric"; return 1; }
	UpdateSet "$appCache" "$version" && echo "$version"
}

AppVersionWin()
{
	local file="$1" version

	! IsPlatform win && return

	if InPath "wmic.exe"; then # WMIC is deprecated but does not require elevation
		version="$(RunWin wmic.exe datafile where name="\"$(utw "$file" | QuoteBackslashes)\"" get version /value | RemoveCarriageReturn | grep -i "Version=" | cut -d= -f2)" || return
	elif CanElevate; then
		version="$(RunWin powershell.exe "(Get-Item -path \"$(utw "$file")\").VersionInfo.FileVersion" | RemoveCarriageReturn)" || return

		# use major, minor, build, revision - for programs like speedcrunch.exe
		if ! IsNumeric "$version"; then
			version="$(RunWin powershell.exe "(Get-Item -path \"$(utw "$file")\").VersionInfo.FileVersionRaw" | RemoveCarriageReturn | RemoveEmptyLines | tail -1 | tr -s " " | RemoveSpaceTrim | sed 's/ /\./g')" || return
		fi
	fi

	echo "$version"
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
	local app="$1" appLower="$(LowerCase "$1")"
	case "$appLower" in
		1passwordcli) echo "op";;
		7zip) echo "7z";;
		apt) ! IsPlatform mac && echo "apt";; # /usr/bin/apt in Mac is legacy
		chroot) echo "schroot";;
		python) echo "python3";;
		*) InPath "$appLower" && echo "$appLower" || echo "$app";;
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
	local scriptName="CloudConf" quiet

	while (( $# != 0 )); do
		case "$1" in "") : ;;
			--quiet|-q) quiet="--quiet";;
			*) UnknownOption "$1"; return
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
	[[ ! $CLOUD ]] && { [[ ! $quiet ]] && ScriptErr "unable to find a cloud directory"; return 1; }
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
	local scriptName="HashiConf"
	local force forceLevel forceLess; ScriptOptForce "$@"
	local verbose verboseLevel verboseLess; ScriptOptVerbose "$@"

	# configure D-BUS - as root avoid vault error "DBUS_SESSION_BUS_ADDRESS envvar looks to be not set, this can lead to runaway dbus-daemon processes"
	# - run before return to ensure D-BUS is configured when running from Nomad job with VAULT_TOKEN set
	[[ "$USER" == "root" ]] && { DbusConf $force $verbose || return; }

	# return if needed
	[[ ! $force && $HASHI_CHECKED ]] && return
	[[ ! $force && $VAULT_TOKEN ]] && { HASHI_CHECKED="true"; return; }
	! HashiAvailable && { HASHI_CHECKED="true"; return; }

	# initialize
	(( verboseLevel > 1 )) && header "Hashi Configuration"

	# configure caching - in Windows use gnome-keyring in available (faster)
	local cache="true" manager="local"
	if IsPlatform win && { service running dbus || app start dbus --quiet $force $verbose; } && credential manager IsAvailable --manager=gk && credential manager unlock --quiet --manager=gk; then manager="gk"
	elif ! credential manager IsAvailable --manager="$manager"; then unset cache
	fi

	# set environment from credential store cache if possible (faster .5s, securely save tokens)
	if [[ $cache ]] && ! (( forceLevel > 1 )); then
		log2 "trying to set Hashi environment from '$manager' credential store cache" "HashiConf"
		ScriptEval credential get hashi cache --quiet --manager="$manager" $force $verboseLess  && { HASHI_CHECKED="true"; return; }
	fi

	# set environment (slower 5s)
	log2 "setting the Hashi environment manually" "HashiConf"
	local vars; vars="$(hashi config environment all --suppress-errors "$@")" || return
	if ! eval "$vars"; then
		(( verboseLevel > 1 )) && { ScriptErr "invalid environment variables:"; ScriptMessage "$vars"; }
		ScriptErr "Hashi configuration variables are not valid"
		return 1
	fi
	
	# check if can cache - windows 
	IsPlatform win && [[ "$manager" == @(|local|native|win) ]] && (( $(echo "$vars" | wc --bytes) > 512 )) && unset cache

	# cache variables
	if [[ $cache ]]; then
		log2 "caching the Hashi environment" "HashiConf"
		echo "$vars" | credential set hashi cache - --quiet --manager="$manager" $force $verbose
	fi

	HASHI_CHECKED="true"
}

HashiAvailable() { IsOnNetwork butare,sandia; }
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
	local args=() command help noFind noRun select timeout
	local force forceLevel forceLess noPrompt quiet test verbose verboseLevel verboseLess # for globalArgs

	while (( $# != 0 )); do
		case "$1" in "") : ;;	
			--help|-h) help="--help";;
			--no-find|-nf) noFind="--no-find";;
			--no-run|-nr) noRun="--no-run";;
			--select|-s) select="--select";;
			--timeout|--timeout=*|-t|-t=*) . script.sh && ScriptOptTimeout "$@";;

			--force|-f|-ff|-fff) ScriptOptForce "$1";;
			--no-prompt|-np) noPrompt="--no-prompt";;
			--quiet|-q) quiet="--quiet";;
			--test|-t) test="--test";;
			--verbose|-v|-vv|-vvv|-vvvv|-vvvvv) ScriptOptVerbose "$1";;
			*) args+=( "$1" ); ! IsOption "$1" && [[ ! $command ]] && command="$1";;
		esac
		shift
	done
	local globalArgs globalArgsLess globalArgsLessForce globalArgsLessVerbose; ScriptGlobalArgsSet || return

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
		*) InstFind && inst install --hint "$INSTALL_DIR" $noRun "${globalArgs[@]}" "${args[@]}";;
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
	local sudo="sudoc"; { IsPlatform mac || npm --global prefix | qgrep "^$HOME"; } && sudo=""; 
	$sudo npm --global "$@"
}

NodeUpdate()
{
	# cleanup - update will fail if .bin directory existx, which is create from a failed update
	sudoc rm -fr "$(npm --global prefix)/lib/node_modules/.bin" || return

	# update npm - npm outdated returns false if there are updates
	{ [[ $force ]] || { npm outdated --global; true; } | qgrep '^npm '; } && { NodeNpmGlobal install npm@latest || return; }

	# update other packages
	{ [[ $force ]] || ! npm outdated --global >& /dev/null; } && { NodeNpmGlobal update || return; }

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
UnisonClean() { local sudo=""; IsPlatform mac && sudo="sudoc"; $sudo rm "$(UnisonConfDir)/$1"; }
UnisonCleanRoot() { [[ $# == 2 ]] && { SshHelper --interactive "$1" -- UnisonCleanRoot "$2"; return; }; sudoc rm "$(UnisonRootConfDir)/$1"; }

UnisonFindTemp() { find . -name '.unison*'; }
UnisonRemoveTemp() { find . -name '.unison*' -print0 | xargs -0 -I {} rm -fr "{}"; }

# Zoxide - configure zoxide if it is installed
ZoxideConf()
{
	{ ! InPath zoxide || IsDefined z; } && return
	eval "$(zoxide init $PLATFORM_SHELL)" # errors on bl3 on new shell
	return 0
}

#
# arguments
#

# GetArgs - get argument from standard input if not specified on command line
# - must be an alias in order to set the arguments of the caller
# - GetArgsN will read the first argument from standard input if there are not at least N arguments present
# - aliases must be defined before used in a function
# - pipelines operate on the entire input, not each line, i.e. `cat FILE | RemoveSpaceFront` remove only the first space of the first line of the file
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
# clipboard
#

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

#
# config
#

AllConf() { HashiConf "$@" && CredentialConf "$@" && NetworkConf --config "$@" && SshAgentConf "$@"; }

ConfigExists() { local file; configInit "$2" && (. "$file"; IsVar "$1"); }				# ConfigExists VAR [FILE] - return true if a configuration variable exists
ConfigGet() { local file; configInit "$2" && (. "$file"; eval echo "\$$1"); }			# ConfigGet VAR [FILE] - get a configuration variable
ConfigGetCurrent() { ConfigGet "$(NetworkCurrent)$(UpperCaseFirst "$1")" "$2"; } 	# ConfigGetCurrent VAR [FILE] - get a configuration entry for the current network
ConfigGetCurrentServers() { ConfigGetCurrent "${1}Servers" "$2"; } 								# ConfigGetCurrentServers TYPE [FILE] - get all servers for the specified type for the current network, i.e. ConfigGetCurrentServers dns

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
EchoValidate() { [[ $1 ]] || return; echo "$1"; }												# echo message if it has a value and return 0	
HilightErr() { InitColorVars; InitColorErr; EchoErr "${RED}$@${RESET}"; }							# hilight an error message
HilightErrEnd() { InitColorVars; InitColorErr; EchoErrEnd "${RED}$@${RESET}"; }				# hilight an error message
HilightPrintErr() { InitColorVars; InitColorErr; PrintErr "${RED}$@${RESET}"; }				# hilight an error message
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

DumpBytes() { GetArgs; echo -n -e "$@" | ${G}od --address-radix d -t x1 -t c -t a; } # echo -en "01\\n" | DumpBytes
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

# GetType VAR - show type option without -g (global), i.e. -a (array), -i (integer), -ir (read only integer).   Does not work for some special variables  like funcfiletrace, 
# GetTypeFull - get the full type
if IsZsh; then
	GetType()	{ local gt="$(declare -p "$1")"; gt="${gt#typeset }"; gt="${gt#-g }"; r "${gt%% *}" $2; }
	GetTypeFull() { eval 'echo ${(t)'$1'}'; }
else
	GetType() { local gt="$(declare -p $1)"; gt="${gt#declare }"; r "${gt%% *}" $2; }
	GetTypeFull() { GetType "$@"; }
fi

# array
ArrayAnyCheck() { IsAnyArray "$1" && return; ScriptErr "'$1' is not an array" "ArrayAnyCheck"; return 1; }
ArrayReverse() { { ArrayDelimit "$1" $'\n'; printf "\n"; } | TMPDIR="/tmp" tac; } # last line of tac must end in a newline, tac needs a writable directory
ArraySize() { eval "echo \${#$1[@]}"; }
ArraySort() { IFS=$'\n' ArrayMake "$1" "$(ArrayDelimit "$1" $'\n' | sort "${@:2}")"; } # ArraySort VAR SORT_OPTIONS...

# ArrayMake VAR ARG... - make an array by splitting passed arguments using IFS
# ArrayMakeC VAR CMD... - make an array from the output of a command
# ArrayShift VAR N - shift array by N elements
# ArrayShowKeys VAR - show keys in an associative array
# IsArray VAR - return true if VAR is an array
# IsAssociativeArray VAR - return true if VAR is an associative array
# StringToArray STRING DELIMITER VAR - convert a string to an array splitting by delimiter
if IsZsh; then
	ArrayMake() { setopt sh_word_split; local arrayMake=() arrayName="$1"; shift; arrayMake=( $@ ); ArrayCopy arrayMake "$arrayName"; }
	ArrayMakeC() { setopt sh_word_split; local arrayMakeC=() arrayName="$1"; shift; arrayMakeC=( $($@) ) || return; ArrayCopy arrayMakeC "$arrayName"; }
	ArrayShift() { local arrayShiftVar="$1"; local arrayShiftNum="$2"; ArrayAnyCheck "$1" || return; set -- "${${(P)arrayShiftVar}[@]}"; shift "$arrayShiftNum"; local arrayShiftArray=( "$@" ); ArrayCopy arrayShiftArray "$arrayShiftVar"; }
	ArrayShowKeys() { local var; eval 'local getKeys=( "${(k)'$1'[@]}" )'; ArrayShow getKeys; }
	IsArray() { [[ "$(GetTypeFull "$1")" =~ ^(array|array-) ]]; }
	IsAssociativeArray() { [[ "$(GetTypeFull "$1")" =~ ^(association|association-) ]]; }
	StringToArray() { GetArgs3; IFS=$2 read -A $3 <<< "$1"; }
else
	ArrayMake() { local -n arrayMake="$1"; shift; arrayMake=( $@ ); }
	ArrayMakeC() { local -n arrayMakeC="$1"; shift; arrayMakeC=( $($@) ); }
	ArrayShift() { local -n arrayShiftVar="$1"; local arrayShiftNum="$2"; ArrayAnyCheck "$1" || return; set -- "${arrayShiftVar[@]}"; shift "$arrayShiftNum"; arrayShiftVar=( "$@" ); }
	ArrayShowKeys() { local var getKeys="!$1[@]"; eval local keys="( \${$getKeys} )"; ArrayShow keys; }
	IsArray() { [[ "$(declare -p "$1" 2> /dev/null)" =~ ^declare\ \-a.* ]]; }
	IsAssociativeArray() { [[ "$(declare -p "$1" 2> /dev/null)" =~ ^declare\ \-A.* ]]; }
	StringToArray() { GetArgs3; IFS=$2 read -a $3 <<< "$1"; } 
fi

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
	ArrayMake "$arrayAppendDest" "$(ArrayDelimit "$arrayAppendDest" $'\n' | sort | uniq)"
}

# ArrayCopy SRC DEST
ArrayCopy()
{
	! IsAnyArray "$1" && { ScriptErr "'$1' is not an array" "ArrayCopy"; return 1; }
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

# ArrayIndex NAME VALUE - return the 1 based index of the value in the array
ArrayIndex() { ArrayDelimit "$1" '\n' | RemoveEnd '\n' | grep --line-number "^${2}$" | cut -d: -f1; }

# ArrayIntersection A1 A2 - return the items not in common in each line
ArrayIntersection() { FileIntersect <(ArrayDelimit "$1" $'\n') <(ArrayDelimit "$2" $'\n'); }

# ArrayRemove ARRAY VALUES... - remove values from the array, array is modified
ArrayRemove()
{
	local arrayRemoveExclude=( "$@" )
	IFS=$'\n' ArrayMake "$1" "$(FileLeft <(ArrayDelimit "$1" $'\n') <(ArrayDelimit "arrayRemoveExclude" $'\n'))"
}

# ArraySelect NAME TITLE MENU - select items from the specified array
ArraySelect()
{
	local name="$1" title="$2" menu="$3"
	local array item items=(); ArrayCopy "$name" array
	for item in "${array[@]}"; do items+=( "$item" "" ); done
	dialog --stdout --backtitle "$title" --menu "$menu:" $(($LINES-5)) 50 $(($LINES)) -- "${items[@]}"
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

# ArrayUnion A1 A2 - return the items in common
ArrayUnion() { FileBoth <(ArrayDelimit "$1" $'\n') <(ArrayDelimit "$2" $'\n'); }

# IsInArray [-ci|--case-insensitive] [-w|--wild] [-aw|--array-wild] STRING ARRAY_VAR
IsInArray() 
{ 
	# arguments
	local scriptName="IsInArray" wild awild caseInsensitive
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
				else UnknownOption "$1"; return
				fi
		esac
		shift
	done

	# get string to check
	[[ ! $s && $1 ]] && { s="$1"; shift; }
	[[ ! $s ]] && { MissingOperand "string"; return; }
	[[ $caseInsensitive ]] && LowerCase "$s" s;

	# get array variable
	[[ ! $arrayVar && $1 ]] && { arrayVar="$1"; shift; }
	[[ ! $arrayVar ]] && { MissingOperand "array_var"; return; }
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

# list
ListMake() { local listMakeArray=("${@:2}"); ArrayDelimit listMakeArray "$1"; } # ListMake DELIMITER VALUE... - return values delimited by delimiter

# string
BackToForwardSlash() { GetArgs; echo "${@//\\//}"; }
CharCount() { GetArgs2; local charCount="${1//[^$2]}"; echo "${#charCount}"; } # CharCount STRING [CHAR]
ForwardToBackSlash() { GetArgs; echo -E "$@" | sed 's/\//\\/g'; }
IsWild() { [[ "$1" =~ (.*\*|\?.*) ]]; }
NewlineToComma()  { tr '\n' ','; }
NewlineToSpace()  { tr '\n' ' '; }
QuoteBackslashes() { GetArgs; echo -E "$@" | sed 's/\\/\\\\/g'; } 						# escape (quote) backslashes
QuoteForwardslashes() { GetArgs; echo -E "$@" | sed 's/\//\\\//g'; } 					# escape (quote) forward slashes (/) using a back slash (\)
QuoteParens() { GetArgs; echo -E "$@" | sed 's/(/\\(/g' | sed 's/)/\\)/g'; } 	# escape (quote) parents
QuotePath() { GetArgs; echo -E "$@" | sed 's/\//\\\//g'; } 										# escape (quote) path (forward slashes - /) using a back slash (\)
QuoteQuotes() { GetArgs; echo -E "$@" | sed 's/\"/\\\"/g'; } 									# escape (quote) quotes using a back slash (\)
QuoteRegex() { GetArgs; echo -E "$@" | sed 's/[]\.|$(){}?+*^[]/\\&/g'; }  		# escape (quote) regular expression characters using a back slash (\)
QuoteSpaces() { GetArgs; echo -E "$@" | sed 's/ /\\ /g'; } 										# escape (quote) spaces using a back slash (\)
RemoveAfter() { GetArgs2; echo "${1%%$2*}"; }								# RemoveAfter STRING REMOVE - remove first occerance of REMOVE and all text after it
RemoveBackslash() { GetArgs; echo "${@//\\/}"; }						# RemoveBackslash STRING - remove all backslashes
RemoveBefore() { GetArgs2; echo "${1##*$2}"; }							# RemoveBefore STRING REMOVE - remove last occerance of REMOVE and all text before it
RemoveBeforeFirst() { GetArgs2; echo "${1#*$2}"; }					# RemoveBeforeFirst STRING REMOVE - remove first occerance of REMOVE and all text before it
RemoveCarriageReturn()  { sed 's/\r//g'; }									# RemoveCarriageReturn STRING - removal all carriage returns
RemoveChar() { GetArgs2; echo "${1//${2:- }/}"; }						# RemoveChar STRING REMOVE
RemoveEmptyLines() { awk 'NF { print; }'; }									# RemoveEmptyLines - remove all empty lines
RemoveFront() { GetArgs2; echo "${1##*(${2:- })}"; }				# RemoveFront STRING REMOVE 
RemoveEnd() { GetArgs2; echo "${1%%*(${2:- })}"; }					# RemoveEnd STRING REMOVE 
RemoveLastEmptyLine() { ${G}sed -i '${/^$/d;}' "$1"; }
RemoveNewline()  { tr -d '\n'; }
RemoveParens() { tr -d '()'; }
RemoveQuotes() { sed 's/^\"//g ; s/\"$//g'; }
RemoveSpace() { GetArgs; RemoveChar "$1" " "; }
RemoveSpaceEnd() { GetArgs; RemoveEnd "$1" " "; }
RemoveSpaceFront() { GetArgs; RemoveFront "$1" " "; }
RemoveSpaceTrim() { GetArgs; RemoveTrim "$1" " "; }
RemoveTrailingSlash() { GetArgs; r "${1%%+(\/)}" $2; }
RemoveTrim() { GetArgs2; echo "$1" | RemoveFront "${2:- }" | RemoveEnd "${2:- }"; }	# RemoveTrim STRING REMOVE - remove from front and end
ReplaceString() { GetArgs3; echo "${1//$2/$3}"; } # ReplaceString TEXT STRING REPLACEMENT 
SpaceToNewline()  { tr ' ' '\n'; }
StringPad() { printf '%*s%s\n' "$(($2))" "$1" ""; } # StringPad S N - pad string s to N characters with spaces on the left
StringRepeat() { printf "$1%.0s" $(eval "echo {1.."$(($2))"}"); } # StringRepeat S N - repeat the specified string N times
ShowChars() { GetArgs; echo -n -e "$@" | ${G}od --address-radix=d -t x1 -t a; } # ShowChars STRING - show all characters in the string
UnQuoteQuotes() { GetArgs; echo "$@" | sed 's/\\\"/\"/g'; } # remove backslash before quotes

if IsZsh; then
	GetAfter() { GetArgs2; echo "$1" | cut -d"$2" -f2-; } # GetAfter STRING CHAR - get all text in STRING after the first CHAR
	LowerCase() { GetArgs; [[ $# == 0 ]] && { tr '[:upper:]' '[:lower:]'; return; }; r "${1:l}" $2; }
	LowerCaseFirst() { GetArgs; r "${(L)1:0:1}${1:1}" $2; }
	ProperCase() { GetArgs; r "${(C)1}" $2; }
	UpperCase() { GetArgs; r "${(U)1}" $2; }
	UpperCaseFirst() { GetArgs; r "${(U)1:0:1}${1:1}" $2; }

	GetWord()
	{
		GetArgDash; GetWordUsage "$@" || return
		local gwa gw="$1" word="$2" delimiter="${3:- }"; gwa=( "${(@ps/$delimiter/)gw}" ); printf "${gwa[$word]}"
	}

else
	GetAfter() { GetArgs2; [[ "$1" =~ ^[^$2]*$2(.*)$ ]] && echo "${BASH_REMATCH[1]}"; } # GetAfter STRING CHAR - get all text in STRING after the first CHAR
	LowerCase() { GetArgs; [[ $# == 0 ]] && { tr '[:upper:]' '[:lower:]'; return; }; r "${1,,}" $2; }
	LowerCaseFirst() { GetArgs; r "${1,}" $2; }
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

GetWordUsage() { (( $# == 2 || $# == 3 )) && IsInteger "$2" && return 0; EchoWrap "Usage: GetWord STRING|- WORD [DELIMITER](-) - 1 based"; return 1; }

RemoveColor()
{
	InPath ansi2txt && { ansi2txt "$@"; return; }																								# linux
	InPath ansifilter && { ansifilter --text "$@"; return; }																		# mac
	${G}sed -r 's/[\x1B\x9B][][()#;?]*(([a-zA-Z0-9;]*\x07)|([0-9;]*[0-9A-PRZcf-ntqry=><~]))//g' # generic
}

# StringSort STRING [DELIMITER](,)
StringSort()
{
	local s="$1" delimiter="${2:-,}"
	echo "$s" | sed -e 's/'$delimiter'/\n/g' | sort -n | tr '\n' "$delimiter" | sed 's/.$//'
}

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

# variables
EvalVar() { r "${!1}" $2; } 																											# EvalVar VAR1 [VAR2] - show the value of VAR1, or set var2 to the value of var1
GetVarCached() { local value="$(GetVar "$1")"; [[ $value ]] && printf "$value"; } # GetVarCached VAR - print the value of a variable if it has one and return true, useful for caching values in variables

# result VALUE [VAR] - echo value, or set var to value (faster), r "- '''\"\"\"-" a; echo $a
r() { [[ $# == 1 ]] && echo "$1" || eval "$2=""\"${1//\"/\\\"}\""; }

# IsVarHidden VAR - return true if the variable is hidden
# GetVar VAR - get the value of variable
# SetVar VAR VALUE - set variable to value
if IsZsh; then
	IsVarHidden() { [[ "$(GetTypeFull "$1")" =~ (-hide) ]]; }
	GetVar() { printf "${(P)1}"; }
	SetVar() { eval $1="$2"; }
else
	IsVarHidden() { false; }
	GetType() { local gt="$(declare -p $1)"; gt="${gt#declare }"; r "${gt%% *}" $2; }
	GetVar() { printf "${!1}"; }
	SetVar() { local -n var="$1"; var="$2"; }
fi

#
# File System
#

CanWrite() { [[ -w "$1" ]]; }
DirCount() { local result; result="$(command ls "${1:-.}" |& wc -l)"; ! IsNumeric "$result" && result="0"; RemoveSpace "$result"; }
DirEnsure() { GetArgs; echo "$(RemoveTrailingSlash "$@")/"; } # DirEnsure DIR - ensure dir has a trailing slash
DirMake() { local dir r; for dir in "$@"; do r="$(DirEnsure "$r")$(RemoveFront "$dir" "/")"; done; echo "$r";  } # DirMake DIR... - combine all directories into a single directory (ensures no duplicatate or missing /)
DirSave() { [[ ! $1 ]] && set -- "$TEMP"; pushd "$@" > /dev/null; }
DirRestore() { popd "$@" > /dev/null; }
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
HasFileExtension() { GetArgs; [[ $(GetFileExtension "$1") ]]; }
HasFilePath() { GetArgs; [[ $(GetFilePath "$1") ]]; }
IsDirEmpty() { GetArgs; [[ "$(${G}find "$1" -maxdepth 0 -empty)" == "$1" ]]; }
InPath() { local f; for f in "$@"; do ! FindInPath "$f" >& /dev/null && return 1; done; return 0; } # InPath FILE... - return true if all files are in the path
InPathAny() { local f; for f in "$@"; do FindInPath "$f" >& /dev/null && return; done; return 1; }	# InPathAny FILE... - return true if any files are in the path
IsFileSame() { [[ "$(GetFileSize "$1" B)" == "$(GetFileSize "$2" B)" ]] && diff "$1" "$2" >& /dev/null; }
IsPath() { [[ ! $(GetFileName "$1") ]]; }
IsWindowsFile() { drive IsWin "$1"; }
IsWindowsLink() { ! IsPlatform win && return 1; lnWin -s "$1" >& /dev/null; }

# CloudGet [--quiet] FILE... - force files to be downloaded from the cloud and return the file
# - mac: beta v166.3.2891+ triggers download of online-only files on move or copy
# - wsl: reads of the file do not trigger online-only file download in Dropbox
CloudGet()
{
	! IsPlatform win && return

	# arguments
	local scriptName="CloudGet" file files=()
	local force forceLevel forceLess noPrompt quiet test verbose verboseLevel verboseLess # for globalArgs

	while (( $# != 0 )); do
		case "$1" in "") : ;;
			--force|-f|-ff|-fff) ScriptOptForce "$1";;
			--no-prompt|-np) noPrompt="--no-prompt";;
			--quiet|-q) quiet="--quiet";;
			--test|-t) test="--test";;
			--verbose|-v|-vv|-vvv|-vvvv|-vvvvv) ScriptOptVerbose "$1";;
			-*) UnknownOption "$1"; return;;
			*) files+=("$1"); shift; continue;;
		esac
		shift
	done

	for file in "${files[@]}"; do
		[[ $verbose ]] && PrintErr "CloudGet: $file..."

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
		[[ $verbose ]] && EchoErrEnd "blocks=$blocks"
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

# CopyFileProgress - copy a file with progress indicator
CopyFileProgress()
{
	! IsPlatform linux && { rsync --info=progress2 "$@"; return; }
	! PackageIsInstalled python3-progressbar && { package python3-progressbar || return; }
	"$DATA/platform/agnostic/pcp" "$@"	
}

# explorer DIR - explorer DIR in GUI program
explore()
{
	local dir="$1"; [[ ! $dir ]] && dir="."

	IsPlatform mac && { open "$dir"; return; }
	IsPlatform wsl1 && { RunWin explorer.exe "$(utw "$dir")"; return; }
	IsPlatform wsl2 && { RunWin explorer.exe "$(utw "$dir")"; return 0; }
	InPath nautilus && { start nautilus "$dir"; return; }
	InPath mc && { mc; return; } # Midnight Commander

	EchoErr "The $(PlatformDescription) platform does not have a file explorer"; return 1
}

# File<Both|Life|Right|Intersect> FILE1 FILE2 - return the lines only in the left file, right file, or not in either file
# - FileBoth <(cat "$first") <(cat "$second")
FileIntersect() { awk '{NR==FNR?a[$0]++:a[$0]--} END{for(k in a)if(a[k])print k}' "$1" "$2"; }
FileBoth() { comm -12 <(sort "$1") <(sort "$2"); }
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
	local scriptName="FileCommand" command="$1"; shift
	local args=() files=() dir

	# arguments - ignore files that do not exist
	while (( $# > 1 )); do
		IsOption "$1" && args+=("$arg")
		[[ -e "$1" ]] && files+=("$1")
		shift
	done
	dir="$1" # last argument
	[[ ! $command ]] && { MissingOperand "command"; return; }
	[[ ! $dir ]] && { MissingOperand "dir"; return; }
	[[ ! "$command" =~ ^(cp|mv|ren)$ ]] && { ScriptErr "unknown command '$command'"; return 1; }
	[[ ! $files ]] && return 0
	
	[[ ! "$command" =~ ^(ren)$ && ! -d "$dir" ]] && { ${G}mkdir --parents "$dir" || return; }

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
	local scriptName="FileWait" file noCancel pathFind quiet sudo timeoutSeconds

	while (( $# != 0 )); do
		case "$1" in "") : ;;
			--no-cancel|-nc) noCancel="true";;
			--path|-p) pathFind="true";;
			--quiet|-q) quiet="--quiet";;
			--sudo|-s) sudo="sudoc";;
			*)
				! IsOption "$1" && [[ ! $file ]] && { file="$1"; shift; continue; }
				! IsOption "$1" && [[ ! $timeoutSeconds ]] && { timeoutSeconds="$1"; shift; continue; }
				UnknownOption "$1"; return
		esac
		shift
	done
	[[ ! $file ]] && { MissingOperand "file"; return; }
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
		PrintErr "."
		
	done

	EchoErrEnd "not found"; return 1
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

# FindAny DIR NAME [DEPTH](1) - find NAME (supports wildcards) starting from DIR for max of DEPTH directories
FindAny()
{
	# arguments
	local scriptName="FindAny" args=() dir name nameArg="-name" depth

	while (( $# != 0 )); do
		case "$1" in "") : ;;
			--ignore-case|-i) nameArg="-iname";;
			--) shift; args+=("$@"); break;;
			-*) UnknownOption "$1"; return;;
			*)
				! IsOption "$1" && [[ ! $dir ]] && { dir="$1"; shift; continue; }
				! IsOption "$1" && [[ ! $name ]] && { name="$1"; shift; continue; }
				! IsOption "$1" && [[ ! $depth ]] && IsInteger "$1" && { depth="$1"; shift; continue; }
				UnknownOption "$1"; return
				;;
		esac
		shift
	done
	depth="${depth:-1}"

	# find
	[[ ! -d "$dir" ]] && return 1
	"${G}find" "$dir" -maxdepth "$depth" $nameArg "$name" "${args[@]}" | "${G}grep" "" # grep returns error if nothing found
}

FindDir() { FindAny "$@" -- -type d; }
FindFile() { FindAny "$@" -- -type f; }

FindInPath()
{
	local file="$1" 

	# file exists
	[[ -f "$file" ]] && { echo "$(GetFullPath "$file")"; return; }

	# use cache - example setup:
	# findInPathUseCache="true" findInPathCache="$(PathFileNames)"
	[[ $findInPathUseCache ]] && { echo "$findInPathCache" | ${G}grep -m 1 "^$1$"; return; }
	
	# find in path
	if IsZsh; then
		whence -p "${file}" && return
		IsPlatform wsl && { whence -p "${file}.exe" && return; }
	else
		type -P "${file}" && return
		IsPlatform wsl && { type -P "${file}.exe" && return; }
	fi

	return 1
}

# (p)fpc - (platform) full path to clipboard
fpc() { local arg; [[ $# == 0 ]] && arg="$PWD" || arg="$(GetRealPath "$1")"; echo "$arg"; clipw "$arg"; }
pfpc() { local arg; [[ $# == 0 ]] && arg="$PWD" || arg="$(GetRealPath "$1")"; clipw "$(utw "$arg")"; }

# GetMountPoint FILE - get the mount point for a file
GetMountPoint()
{
	local file="$1"
	! InPath df && { ScriptErr "unable to get the mount point for '$file'" "GetMountPoint"; return; }
	df -P "$file" | tail -1 | awk '{print $6}'
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

# GetWritableDir DIR - return DIR if it is on on a writable filesystem, otherwise return a directory that is on a writable filesystem
# - useful for finding a writable prefix when running in jobs that  that run inside readonly filesystems
GetWritableDir()
{
	local dir="$1"
	if IsPlatform nomad; then dir="$NOMAD_ALLOC_DIR" # for HashiCorp Nomad use the same update directory for all allocations
	elif IsPlatform consul; then dir="/tmp"
	elif ! quiet="--quiet" IsFilesystemReadonly "$dir"; then :
	elif ! quiet="--quiet" IsFilesystemReadonly "/tmp"; then dir="/tmp"
	else ScriptErrQuiet "unable to find a writable directory" "GetWritableDir"; return;
	fi
	printf "$dir"
}

HideAll()
{
	! IsPlatform win && return

	for f in $('ls' -A | grep -E '^\.'); do
		attrib "$f" +h 
	done
}

# IsFilesystemReadonly FILE - return true if file is on a read-only filesystem, i.e. findmnt -rn | grep " ro,"
IsFilesystemReadonly()
{
	local file="$1"
	! InPath df findmnt && { ScriptErrQuiet "unable check if '$file' is on a writable filesystem", "IsFileSystemWritable"; return; }
	local mp; mp="$(GetMountPoint "$file")" || return;  
	findmnt -rno OPTIONS "$mp" | qgrep "^ro,"
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

# PathQuoted - return paths as a quoted space separated list
PathQuoted()
{
	local paths exclude=( "$WIN_ROOT/Windows/system32" "$WIN_ROOT/Windows/System32/Wbem" "$WIN_ROOT/Windows/System32/WindowsPowerShell/v1.0/" )
	StringToArray "$PATH" ":" paths && ArrayRemove paths "${exclude[@]}" && ArrayShow paths
}

# PathFiles - return all files in the path
PathFiles()
{
	eval ${G}find $(PathQuoted) -maxdepth 1 -executable  -not -type d |& ${G}grep -v "No such file or directory"
	return 0 # find will return errors for paths that do not exist
}

# PathFileNames - return all distinct sorted file names in the path
PathFileNames() { PathFiles | sed 's/.*\///' | sort | uniq; }

# RmOldFiles PATTERN [DAYS](30)
RmOldFiles()
{
	local dir="$1" days="${2:-30}"
	[[ ! -d "$dir" ]] && { ScriptErr "the directory '$dir' does not exist" "RmOldFiles"; return 1; }
	find "$dir" -type f -mtime +$days || return
	local count; count="$(find "$dir" -type f -mtime +$days | wc -l)" || return
	(( count == 0 )) && { echo "No files to delete"; return; }
	ask "Delete $count files files" --default-response n || return
	find "$dir" -type f -mtime +$days -delete || return
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
	GetArgs; local file="$1"; [[ ! $file ]] && { MissingOperand "FILE" "wtu"; return; }
	{ ! IsPlatform win || [[ ! "$file" ]] || IsUnixPath "$file"; } && { echo -E "$file"; return; }
  wslpath -u "$*"
}

utw() # UnixToWin
{	
	GetArgs; local clean="" file="$1"; [[ ! $file ]] && { MissingOperand "FILE" "utw"; return; } 
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
	local scriptName="UnzipPlatform" sudo zip dest

	# arguments
	while (( $# != 0 )); do
		case "$1" in "") : ;;
			-s|--sudo) sudo="sudoc";;
			*)
				! IsOption "$1" && [[ ! $zip ]] && { zip="$1"; shift; continue; }
				! IsOption "$1" && [[ ! $dest ]] && { dest="$1"; shift; continue; }
				UnknownOption "$1"; return
		esac
		shift
	done
	[[ ! "$zip" ]] && { MissingOperand "zip"; return; }
	[[ ! "$dest" ]] && { MissingOperand "dest"; return; }

	# unzip
	if IsPlatform win; then
		7z.exe x "$(utw "$zip")" -o"$(utw "$dest")" -y -bb3 || return
	else
		$sudo unzip -o "$zip" -d "$dest" || return
	fi

	return 0
}

#
# IFS - internal file separator
#

IfsShow() { echo -n "$IFS" | ShowChars; }
IfsReset() { IFS=$' \t\n\0'; }
IfsSave() { ifsSave="$IFS"; IfsReset; }
IfsRestore() { IFS="$ifsSave"; }

#
# monitoring
#

header() { InitColorVars; InitColor; printf "${RB_BLUE}******************************** ${RB_INDIGO}$1${RB_BLUE} ********************************${RESET}\n"; headerDone="$((66 + ${#1}))"; return 0; }
HeaderBig() { InitColorVars; InitColor; printf "${RB_BLUE}************************************************************\n* ${RB_INDIGO}$1${RB_BLUE}\n************************************************************${RESET}\n"; }
HeaderDone() { InitColorVars; InitColor; printf "${RB_BLUE}$(StringRepeat '*' $headerDone)${RESET}\n"; }
HeaderFancy() { ! InPath pyfiglet lolcat && { HeaderBig "$1"; return; }; pyfiglet --justify=center --width=$COLUMNS "$1" | lolcat; }
hilight() { InitColorVars; InitColor; EchoWrap "${GREEN}$@${RESET}"; }
hilightp() { InitColorVars; InitColor; echo -n -E "${GREEN}$@${RESET}"; } # hilight with no newline

# FileWatch FILE [PATTERN] - watch a whole file for changes, optionally for a specific pattern
FileWatch() { local sudo; SudoCheck "$1"; cls; $sudo ${G}tail -F --lines=+0 "$1" | grep "$2"; }

# LogLevel LEVEL MESSAGE - log a message if the logging verbosity level is at least LEVEL
LogLevel() { level="$1"; shift; (( verboseLevel < level )) && return; ScriptMessage "$@"; }
LogPrintLevel() { level="$1"; shift; (( verboseLevel < level )) && return; PrintErr "$@"; }

# logN MESSAGE - log a message if the logging verbosity level is a least N
log1() { LogLevel 1 "$@"; }; log2() { LogLevel 2 "$@"; }; log3() { LogLevel 3 "$@"; }; log4() { LogLevel 4 "$@"; }; log5() { LogLevel 5 "$@"; }
logp1() { LogPrintLevel 1 "$@"; }; logp2() { LogPrintLevel 2 "$@"; }; logp3() { LogPrintLevel 3 "$@"; }; logp4() { LogPrintLevel 4 "$@"; }; logp5() { LogPrintLevel 5 "$@"; }

# LogScript [LEVEL](4) MESSAGE SCRIPT - log a script we are going to run.  Indent it if it is on more than one line
LogScript()
{
	local level="$1"; IsInteger "$level" && shift || level=4
	local message="$1"; shift
	[[ ! $verboseLevel || ! $level ]] || (( verboseLevel < level )) && return

	if [[ "$(echo "$@" | wc -l)" == "1" ]]; then
		hilightp "$message: " >& /dev/stderr
		echo "$@" >& /dev/stderr
	else
		hilight "$message:" >& /dev/stderr
		echo -e "$@" | AddTab >& /dev/stderr
		hilight "EOF" >& /dev/stderr
	fi
}

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

# RunLog LEVEL COMMAND - run a command if not testing, log it if level is 0, or if logging and the logging verbosisty level is at least at the specified leave
RunLogLevel()
{
	local level="$1"; shift

	# log command and arguments
	if [[ "$level" == "0" ]] || { [[ $verbose ]] && (( verboseLevel >= level )); }; then
		ScriptMessage "command: $(RunLogArgs "$@")"
	fi

	[[ $test ]] && return

	"$@" # must be in quotes to preserve arguments, test with wiggin sync lb -H=pi2 -v
}

# RunLogArgs 
RunLogArgs()
{
	local arg message

	for arg in "$@"; do
		local pattern=" |	" # assign pattern to variable to maintain Bash and ZSH compatibility
		[[ "$arg" =~ $pattern || ! $arg ]] && message+="\"$arg\" " || message+="$arg "
	done

	echo -E -n "$(RemoveSpaceTrim "$message")"
}

# logFileN COMMAND - log and run a command if the logging verbosity level is at least N
RunLog() { RunLog1 "$@"; }; RunLog1() { RunLogLevel 1 "$@"; }; RunLog2() { RunLogLevel 2 "$@"; }; RunLog3() { RunLogLevel 3 "$@"; }; RunLog4() { RunLogLevel 4 "$@"; }; RunLog5() { RunLogLevel 5 "$@"; }; 
RunLogQuiet() { RunLog RunQuiet "$@"; }
RunLogSilent() { RunLog RunSilent "$@"; }

#
# network
#

NETWORK_CACHE="network" NETWORK_CACHE_OLD="network-old"

GetDefaultGateway() { CacheDefaultGateway "$@" && echo "$NETWORK_DEFAULT_GATEWAY"; }																	# GetDefaultGateway - default gateway
GetDnsServers4() { GetDnsServers -4 "$@"; }; GetDnsServers6() { GetDnsServers -6 "$@"; }
GetAdapterIpAddress4() { GetAdapterIpAddress -4 "$@"; }; GetAdapterIpAddress6() { GetAdapterIpAddress -6 "$@"; }			# GetAdapterIpAddres [ADAPTER](primary) - get specified network adapter address
GetIpAddress4() { GetIpAddress -4 "$@"; }; GetIpAddress6() { GetIpAddress -6 "$@"; }																	# GetIpAddress[4|6] [HOST] - get the IP address of the current or specified host
GetDomain() { UpdateNeededEmpty "domain" && UpdateSet "domain" "$(network domain name)"; UpdateGetForce "domain"; }				# GetDomain - get the current network domain
GetDomainCached() { UpdateGetForce "domain"; }
HostAvailable() { IsAvailable "$@" && return; ScriptErrQuiet "host '$1' is not available"; }
HostUnknown() { ScriptErr "$1: Name or service not known" "$2"; }
HostUnresolved() { ScriptErr "Could not resolve hostname $1: Name or service not known" "$2"; }
HttpHeader() { curl --silent --show-error --location --dump-header - --output /dev/null "$1"; }
IpFilter() { grep "$@" --extended-regexp '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}'; }
IsHostnameVm() { [[ "$(GetWord "$1" 1 "-")" == "$(os name)" ]]; } 																										# IsHostnameVm NAME - true if name follows the virtual machine syntax HOSTNAME-name
IsIpInCidr() { ! InPath nmap && return 1; nmap -sL -n "$2" | grep --quiet " $1$"; }																		# IsIpInCidr IP CIDR - true if IP belongs to the CIDR, i.e. IsIpInCidr 10.10.100.10 10.10.100.0/22
IsIpAddressAny() { GetArgs; IsIpAddress4 "$1" || IsIpAddress6 "$1"; } 																								# IsIpAddressAny [IP] - return true if the IP is a valid IPv4 or IPv6 address
IsIpAddress4() { IsIpAddress -4 "$@"; }; IsIpAddress6() { IsIpAddress -6 "$@"; } 																			# IsIpAddress4|6 [IP] - return true if the IP is a valid IP address
IsIpvSupported() { [[ $(GetAdapterIpAddress -$1) ]]; }																																# IsIpvSupported 4|6 - return true if the specified internet protocol supported
IsMacLocallyAdministered() { echo "$1" | MacFindLocallyAdministered > /dev/null; }
MacFindLocallyAdministered() { ${G}grep --color=always -P '[0-9a-fA-F][26aAeE](:[0-9a-fA-F]{2}){5}' "$@"; }						# MacFindLocallyAdministered - grep for locally administered MAC addressess
MacLookup4() { MacLookup -4 "$@"; }; MacLookup6() { MacLookup -6 "$@"; }																							# GetIpAddress[4|6] [HOST] - get the IP address of the current or specified host
MacPad() { awk -F: '{for(i=1;i<=NF;i++) printf "%02s%s", $i, (i<NF ? ":" : "\n")}'; }
RemovePort() { GetArgs; echo "$1" | cut -d: -f 1; }																																		# RemovePort NAME:PORT - returns NAME
SmbPasswordIsSet() { sudoc pdbedit -L -u "$1" >& /dev/null; }																													# SmbPasswordIsSet USER - return true if the SMB password for user is set
WifiNetworks() { sudo iwlist wlan0 scan | grep ESSID | cut -d: -f2 | RemoveQuotes | RemoveEmptyLines | sort | uniq; }

# curl
curl()
{
	local file="/opt/homebrew/opt/curl/bin/curl"
	IsPlatform mac && [[ -f "$file" ]] && { "$file" "$@"; return; }
	command curl "$@"; return
}

# proxy
ProxyEnable() { ScriptEval network proxy config vars --enable; network proxy config vars --status; }
ProxyDisable() { ScriptEval network proxy config vars --disable; network proxy config vars --status; }
ProxyStatus() { network proxy status; }

# GetDns - get DNS informationm for the computer, or the network the computer is in
GetDnsDomain() { echo "$(ConfigGet "$(GetDomain)DnsDomain")"; }
GetDnsBaseDomain() { echo "$(ConfigGet "$(GetDomain)DnsBaseDomain")"; }
GetNetworkDnsDomain() { echo "$(ConfigGet "$(NetworkCurrent)DnsDomain")"; }
GetNetworkDnsBaseDomain() { echo "$(ConfigGet "$(NetworkCurrent)DnsBaseDomain")"; }

# GetOsName HOST - get HOST short name, use cached DNS name for speed
GetOsName()
{
	local name="$1"; name="$(force= UpdateGet "os-name-$1")"; [[ ! $name ]] && name="$(os name "$@")"
	echo "$(RemoveDnsSuffix "$name")"
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
	sudov || return

	if IsPlatform win; then
		RunWin ipconfig.exe /release "$adapter" || return
		RunWin ipconfig.exe /renew "$adapter" || return
		echo

	elif InPath netplan; then
		sudo netplan apply || return

	elif InPath nmcli; then
		local connection; connection="$(nmcli -t -f NAME connection show --active | head -n1)" || return
		sudo nmcli connection down "$connection" || return
		sudo nmcli connection up "$connection" || return

	elif IsPlatform linux && InPath dhclient; then
		sudoc dhclient -r || return
		sudoc dhclient || return
	fi

	sleep 1 && echo "Adapter $adapter IP: $oldIp -> $(GetAdapterIpAddress "$adapter")"
}

# DhcpServers - return all DHCPv4 servers on the network
DhcpServers()
{
	NmapCanBroadcast "$@" || return
	nmapp --sudo --script broadcast-dhcp-discover --script-args='broadcast-dhcp-discover.timeout=3' |& grep "Server Identifier: " | RemoveCarriageReturn | cut -d":" -f2 | ${G}sed 's/ //g' | sort --numeric | uniq | DnsResolveBatch | sort
}

# DhcpValidate HOST - ensure DHCPv4 is running on HOST
DhcpValidate()
{
	local host; host="$(DnsResolve "$1")" || return; [[ ! $1 ]] && { EchoWrap "Usage: DhcpValidate HOST"; return 1; }
	DhcpServers | qgrep "^$host$"
}

# GetAdapterIpAddres [ADAPTER](primary) - get specified network adapter IP address
# -4|-6 							use IPv4 or IPv6
# -w|--wsl	get the IP address used by WSL (Windows only)
GetAdapterIpAddress() 
{
	# arguments
	local scriptName="GetAdapterIpAddress" adapter wsl ipv="4"; 

	while (( $# != 0 )); do
		case "$1" in "") : ;;
			-4) ipv="4";;
			-6) ipv="6";;
			-w|--wsl) wsl="--wsl";;
			*)
				if ! IsOption "$1" && [[ ! $adapter ]]; then adapter="$1"
				else UnknownOption "$1"; return
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

			if [[ "$ipv" == "4" ]]; then
				# - use default route (0.0.0.0 destination) with lowest metric
				# - Windows build 22000.376 adds "Default " route
				RunWin route.exe -4 print | RemoveCarriageReturn | grep ' 0.0.0.0 ' | grep -v "Default[ ]*$" | sort -k5 --numeric-sort | head -1 | awk '{ print $4; }'
			else
				# - use the first full IPv6 address (no :: and a / for the CIDR)  with the lowest metric
				RunWin route.exe -6 print | grep -v "::" | grep "/" | sort -k1 --numeric-sort | head -1 | tr -s " " | cut -d" " -f4 | cut -d"/" -f1
			fi

		else

			if [[ "$ipv" == "4" ]]; then
				RunWin ipconfig.exe | RemoveCarriageReturn | grep -E "Ethernet adapter $adapter:|Wireless LAN adapter $adapter:" -A 9 | grep "IPv4 Address" | head -1 | cut -d: -f2 | RemoveSpace
			else
				# format: IPv6 Address. . . . . . . . . . . : 2606:a300:9024:308:32cc:6e48:6a5f:5f21(Preferred)
				RunWin ipconfig.exe | RemoveCarriageReturn | grep -E "Ethernet adapter $adapter:|Wireless LAN adapter $adapter:" -A 9 | grep "IPv6 Address" | grep -v -E 'Temporary|Link-local' | head -1 | cut -d":" -f2- | RemoveSpaceTrim | sed 's/(.*)$//'
			fi

		fi

	elif [[ "$ipv" == "4" ]] && InPath ifdata; then
		ip="$(ifdata -pa "$adapter")" || return
		[[ "$ip" == "NON-IP" ]] && { ScriptErr "interface '$adapter' does not have an IPv4 address"; return 1; }
		echo "$ip"

	elif IsPlatform entware; then
		ifconfig "$adapter" | grep inet | grep -v 'inet6|127.0.0.1' | head -n 1 | awk '{ print $2 }' | cut -d: -f2

	else

		if [[ "$ipv" == "4" ]]; then
			ifconfig "$adapter" | ${G}grep inet | ${G}grep -v 'inet6|127.0.0.1' | ${G}head -n 1 | ${G}awk '{ print $2 }'
		elif IsPlatform mac; then
			ifconfig "$adapter" | ${G}grep inet6 | ${G}grep -v " fe80" | ${G}head -1 | ${G}tr -s " " | ${G}cut -d" " -f2
		else
			ifconfig "$adapter" | grep inet6 | grep "global" | head -1 | tr -s " " | cut -d" " -f3
		fi

	fi
}

# GetAdapterMacAddres [ADAPTER](primary) - get MAC address of the specified network adapter
# -w|--wsl	get the MAC address used by WSL (Windows only)
GetAdapterMacAddress()
{
	local scriptName="GetAdapterMacAddress" adapter wsl; 

	# options
	while (( $# != 0 )); do
		case "$1" in "") : ;;
			-w|--wsl) wsl="--wsl";;
			*)
				if ! IsOption "$1" && [[ ! $adapter ]]; then adapter="$1"
				else UnknownOption "$1"; return
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
		ifconfig "$adapter" | ${G}grep "^[ 	]*ether " | tr -s '[:blank:]' ' ' | cut -d" " -f3
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
	} | ${G}column -c $(tput cols -T "$TERM") -t -s-
}

# GetInterface - name of the primary network interface
GetInterface()
{
	# mac
	if IsPlatform mac; then
		netstat -rn | grep '^default' | head -1 | awk '{ print $4; }'

	# get the interface of the first default route if one is present
	elif route -n | grep "^0.0.0.0" | head -1 | tr -s " " | cut -d" " -f8; then :

	# get the interface with an IP (not the loopback address)
	else
		ip -o -4 addr show | awk '{print $2}' | grep -v "^lo$" | head -n1

	fi
}

# GetIpAddress [HOST] [SERVER] - get the IP address of the current or specified host
# -4|-6 							use IPv4 or IPv6, defaults IPv4 unless --both is specified
# -a|--all 						resolve all addresses for the host, not just the first
# -b|--both 					try IPv4 first then IPv6
# -ra|--resolve-all 	resolve host using all methods (DNS, MDNS, and local virtual machine names)
# -m|--mdns						resolve host using MDNS
#    --vm 						resolve host using local virtual machine names (check $HOSTNAME-HOST)
# -w|--wsl						get the IP address used by WSL (Windows only)
# test cases: 10.10.100.10 web.service pi1 pi1.butare.net pi1.butare.net
GetIpAddress() 
{
	# arguments
	local scriptName="GetIpAddress" args=("$@") all=(head -1) both host ip ipv mdns server type="A" vm wsl
	local force forceLevel forceLess noPrompt quiet test verbose verboseLevel verboseLess # for globalArgs

	while (( $# != 0 )); do
		case "$1" in "") : ;;
			-4) ipv="4";;
			-6) ipv="6";;
			--all|-a) all=(cat);;
			--both|-b) both="--both";;
			--resolve-all|-ra) mdsn="true" vm="true";;
			--mdns|-m) mdns="true";;
			--vm|-v) vm="true";;
			--wsl|-w) wsl="--wsl";;

			--force|-f|-ff|-fff) ScriptOptForce "$1";;
			--no-prompt|-np) noPrompt="--no-prompt";;
			--quiet|-q) quiet="--quiet";;
			--test|-t) test="--test";;
			--verbose|-v|-vv|-vvv|-vvvv|-vvvvv) ScriptOptVerbose "$1";;
			*)
				! IsOption "$1" && [[ ! $host ]] && { host="$1"; shift; continue; }
				! IsOption "$1" && [[ ! $server ]] && { server="$1"; shift; continue; }
				UnknownOption "$1"; return
		esac
		shift
	done

	# IP address - if -4 or -6 is not specified check
	[[ $host ]] && IsIpAddress${ipv} "$host" && { echo "$host"; return; }
	
	# try IPv4 and IPv6
	[[ ! $ipv && $both ]] && { GetIpAddress -4 --quiet "${args[@]}" || GetIpAddress -6 "${args[@]}"; return; }

	# set default IP version
	[[ ! $ipv ]] && ipv="4"

	# type
	[[ "$ipv" == "6" ]] && type="AAAA"


	# remove SSH user and port, i.e. USER@HOST:PORT -> HOST	
	host="$(GetSshHost "$host")"

	# localhost
	IsLocalHost "$host" && { GetAdapterIpAddress${ipv} $wsl; return; }

	# SSH configuration
	host="$(SshHelper config get "$host" hostname)" || return

	# /etc/hosts
	[[ "$ipv" != "4" && $host ]] && IsFunction getent && ip="$(getent hosts "$host")" && { echo "$ip" | cut -d" " -f1; return; }

	# Resolve mDNS (.local) names exclicitly as the name resolution commands below can fail on some hosts
	# In Windows WSL the methods below never resolve mDNS addresses
	IsMdnsName "$host" && { ip="$(MdnsResolve "$host" 2> /dev/null)"; [[ $ip ]] && echo "$ip"; return; }

	# override the server if needed
	[[ ! $server ]] && server="$(DnsAlternate "$host" $verbose)"

	# logging
	log3 "getting IP address for '$host' type '$type'$([[ $server ]] && printf " from name server '$server'")"

	# lookup IP address using various commands

	# getent on Windows sometimes holds on to a previously allocated IP address.
	# - this was seen with old IP address in a Hyper-V guest on test VLAN after removing VLAN ID).  
	# - he host and nslookup commands return new IP.
	if [[ ! $server ]] && InPath getent; then
		log3 "using getent"
		ip="$(getent ahostsv$ipv "$host" |& grep "STREAM" | "${all[@]}" | cut -d" " -f 1)"
	
	# dscacheutil -q host -a name HOST - query macOS system resolvers
	# - ensure get hosts on VPN network as /etc/resolv.conf does not always update wit the VPN nameservers
	# - returns label ip_address or ipv6_address:, but for now only use with IPv4 addresses
	elif [[ ! $server && "$ipv" == "4" ]] && IsPlatform mac; then
		log3 "using dscacheutil"
		ip="$(dscacheutil -q host -a name "$host" |& ${G}grep -E "^ip_address:" | ${G}cut -d" " -f2 | ${G}head -1)"
	
	# host and getent are fast and can sometimes resolve .local (mDNS) addresses 
	# - host is slow on wsl 2 when resolv.conf points to the Hyper-V DNS server for unknown names
	elif InPath host; then
		log3 "using host"
		ip="$(host -N 2 -t $type -4 "$host" $server |& ${G}grep -v "^ns." | ${G}grep "has .*address" | "${all[@]}" | rev | ${G}cut -d" " -f 1 | rev)"
	
	# nslookup - slow on mac if a name server is not specified
	#   - -N 3 and -ndots=2 allow the default domain names for partial names like consul.service
	elif InPath nslookup; then
		log3 "using nslookup"
		ip="$(nslookup -ndots=2 -type=$type "$host" $server |& ${G}tail --lines=+4 | ${G}grep -E "^Address:|has AAAA address" | "${all[@]}" | rev | cut -d" " -f 1 | rev)"
	fi

	# if an IP address was not found, check for a local virtual hostname
	[[ ! $ip && $vm ]] && ip="$(GetIpAddress --quiet "$HOSTNAME-$host")"

	# resolve using .local only if --all is specified to avoid delays
	[[ ! $ip && $mdns ]] && ip="$(MdnsResolve "${host}.local" 2> /dev/null)"

	# return
	[[ ! $ip ]] && { [[ ! $quiet ]] && HostUnresolved "$host"; return 1; }
	echo "$(echo "$ip" | RemoveCarriageReturn)"
}

GetSubnetMask()
{
	if IsPlatform mac; then command ipconfig getsummary "$(GetInterface)" | grep "^subnet_mask" | cut -d" " -f3
	else ifconfig "$(GetInterface)" | grep "netmask" | tr -s " " | cut -d" " -f 5
	fi
}

GetSubnetNumber() { ip -4 -oneline -br address show "$(GetInterface)" | cut -d/ -f2 | cut -d" " -f1 | RemoveSpaceTrim; }

# GetAdapterLinkSpeed [adapter](default) - return adapter link speed in Mbps, defaults to 1000
GetAdapterLinkSpeed()
{
	local speed adapter="$1"; [[ ! $adapter ]] && adapter="$(GetAdapterName)"

	if IsPlatform mac; then
		speed="$(networksetup -getMedia $adapter | grep "^Active:" | ${G}cut -d" " -f2 | sed 's/\([0-9.]*\)Gbase.*/\1*1000/; s/\([0-9]*\)base.*/\1/' | bc | xargs printf "%.0f\n")"
	elif IsPlatform win; then
		speed="$(powershell 'Get-NetAdapter | Select-Object Name, Status, LinkSpeed' | grep "^$adapter" | sed 's/ Gbps/*1000/; s/ Mbps//; s/ Kbps/\/1000/' | tr -s " " | rev | cut -d" " -f1-2 | rev | RemoveCarriageReturn | bc -l | xargs printf "%.0f\n")"
	elif InPath ethtool; then
		speed="$(sudoc ethtool "$adapter" | grep Speed | cut -d":" -f2 | RemoveEnd "Mb/s" | RemoveSpace)"
	fi

	echo "${speed:-1000}"
}

# GetAdapterThreads [adapter](default) - return a thread count for processing sufficient for our network bandwidth
GetAdapterThreads()
{
	local speedMbps; speedMbps="$(GetAdapterLinkSpeed "$@")" || return
	local threads
    
  # speed in Gbps * 3, capped between 2 and 48
  threads=$(echo "scale=0; ($speedMbps / 1000) * 3 / 1" | bc)
  
  # Apply min/max bounds
  (( threads < 2 )) && threads=2
  (( threads > 48 )) && threads=48
  
  echo "$threads"
}

# GetAdapterName [IP](primary) - get the descriptive name of the primary network adapter used for communication
GetAdapterName()
{
	local ip="$1"; [[ ! $ip ]] && { ip="$(GetAdapterIpAddress)" || return; }

	if IsPlatform win; then
		RunWin ipconfig.exe | grep "$ip" -B 12 | grep " adapter" | awk -F adapter '{ print $2 }' | sed 's/://' | sed 's/ //' | RemoveCarriageReturn
	else
		GetInterface "$@"
	fi
}

# ipconfig [COMMAND] - show or configure network
ipconfig()
{
	if IsPlatform win; then RunWin ipconfig.exe "$@"
	elif IsPlatform mac; then command ipconfig "$@"
	else ip -4 -oneline -br address
	fi
}

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
	} | ${G}column -c $(tput cols) -t -s: -n

}

# IsInDomain domain[,domain,...] - true if the computer is in one of the specified domains
# - if no domain is specified, return true if the computer is joined to a domain
IsInDomain()
{
	[[ ! $1 ]] && { network domain joined; return; }
	local domains; StringToArray "$(LowerCase "$1")" "," domains
	local domain="$(GetDomain)"; [[ ! $domain ]] && return 1
	IsInArray "$domain" domains
}

IsDomainRestricted() { IsInDomain sandia; }
IsOnRestrictedDomain() { IsOnNetwork Sandia; }
IsHostRestrcted() { IsOsRestrcited; }
IsOsRestrcited() { false; } # TODO: return true if the operating system is restricted for any reason

# IsIpAddress [-4|-6] [IP] - return true if the IP is a valid IP address
IsIpAddress()
{
	# arguments
	local scriptName="IsIpAddress" ip ipv; GetArgs

	while (( $# != 0 )); do
		case "$1" in "") : ;;
			-4) ipv="4";;
			-6) ipv="6";;
			*)
				! IsOption "$1" && [[ ! $ip ]] && { ip="$1"; shift; continue; }
				UnknownOption "$1"; return
		esac
		shift
	done
	[[ ! $ipv && "$ip" == *:* ]] && ipv="6"

	# IPv6 check - https://stackoverflow.com/questions/53497/regular-expression-that-matches-valid-ipv6-addresses/17871737#17871737
	if [[ "$ipv" == "6" ]]; then
		local ipv6Regex="\
([0-9a-fA-F]{1,4}:){7,7}[0-9a-fA-F]{1,4}|\
([0-9a-fA-F]{1,4}:){1,7}:|\
([0-9a-fA-F]{1,4}:){1,6}:[0-9a-fA-F]{1,4}|\
([0-9a-fA-F]{1,4}:){1,5}(:[0-9a-fA-F]{1,4}){1,2}|\
([0-9a-fA-F]{1,4}:){1,4}(:[0-9a-fA-F]{1,4}){1,3}|\
([0-9a-fA-F]{1,4}:){1,3}(:[0-9a-fA-F]{1,4}){1,4}|\
([0-9a-fA-F]{1,4}:){1,2}(:[0-9a-fA-F]{1,4}){1,5}|\
[0-9a-fA-F]{1,4}:((:[0-9a-fA-F]{1,4}){1,6})|\
:((:[0-9a-fA-F]{1,4}){1,7}|:)|\
fe80:(:[0-9a-fA-F]{0,4}){0,4}%[0-9a-zA-Z]{1,}|\
::(ffff(:0{1,4}){0,1}:){0,1}((25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9])\.){3,3}(25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9])|\
([0-9a-fA-F]{1,4}:){1,4}:((25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9])\.){3,3}(25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9])"
		[[ $ip =~ ^($ipv6Regex)$ ]]; return
	fi

	# IPv4 check
  if IsZsh; then
  	[[ $ip =~ ^((25[0-5]\|(2[0-4]\|1{0,1}[0-9]){0,1}[0-9])\.){3,3}(25[0-5]\|(2[0-4]\|1{0,1}[0-9]){0,1}[0-9])$ ]]
  else
  	[[ "$ip" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]] || return
  	IFS='.' read -a ip <<< "$ip"
  	(( ${ip[0]}<=255 && ${ip[1]}<=255 && ${ip[2]}<=255 && ${ip[3]}<=255 ))
  fi
}

# IsIpLocal - return true if the specified IP is reachable on the local network (check if host does not use the default gateway in 5 hops or less)
IsIpLocal()
{
	local args=("-4"); IsPlatform mac && args=(); GetArgs
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
	[[ "$host" == "" || "$host" == "localhost" || "$host" == "127.0.0.1" || "$host" =~ ^([0]*:){2}([0]*:){0,6}1$ ]] && return

	# if the name is different, this is not localhost
	local hostname="$(hostname | LowerCase)"
	[[ "$(RemoveDnsSuffix "$host")" != "$(RemoveDnsSuffix "$hostname")" ]] && return 1

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
	local mac="$(UpperCase "$1")"; [[ ! $mac ]] && { MissingOperand "mac" "IsMacAddress"; return; }
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

# IsIpStatic [interface](default)
IsIpStatic()
{
	local interface="$1"; [[ ! $interface ]] && { interface="$(GetInterface)" || return; }
	! ip address show "$interface" | grep "inet " | grep --quiet "dynamic"
}

# MacGenerate [--all] - generate a random locally administered MAC address (second digit is 2, 6, A, or E)
# --all - if specified use all valid locally administered digits (2, 6, A, or E), otherwise
#         the first octet is 02, the most recognizable locally administered octet
MacGenerate()
{
	local all; [[ "$1" =~ "--all" ]] && { all="--all"; shift; }
	if [[ $all ]]; then
		local valid_digits=(2 6 a e)
		local random_digit=${valid_digits[$RANDOM % 4]}
		printf '%02x' "$((0x$(openssl rand -hex 1) & 0xF0 | 0x$random_digit))"
	else
		printf '02'
	fi
	printf ':%02x:%02x:%02x:%02x:%02x\n' $(openssl rand -hex 5 | sed 's/../0x& /g')
}

# MacLookup [HOST|IP|MAC]... - resolve a host name or IP to a MAC address using the ARP table or /etc/ethers
# -4|-6 					use IPv4 or IPv6
# --arp|-a				resolve only using the ARP table
# --detail   			displayed detailed information about the MAC address including all MAC, IP address, and 
#               	DNS names.  Allows identification of the current host of a Virtual IP Addresses (VIP).
# --monitor|-m		monitor the host name or IP address for changes (useful for VIP failovers)
# --dns|-d  			resolve the MAC address to a DNS name
# --ethers|-e			resolve only using /etc/ethers
# --quiet|-q			suppress error message where possible
# test: lb lb3 pi1
MacLookup() 
{
	local scriptName="MacLookup" arp detail dns ethers host monitor quiet

	while (( $# != 0 )); do
		case "$1" in "") : ;;
			-4) ipv="4";;
			-6) ipv="6";;
			--arp|-a) arp="--arp";;
			--detail) detail="--detail";;
			--dns|-d) dns="--dns";;
			--ethers|-e) ethers="--ethers";;
			--monitor|-m) monitor="--monitor";;
			--quiet|-q) quiet="--quiet";;
			*) 
				IsOption "$1" && { UnknownOption "$1"; return; }
				[[ ! $host ]] && host="$1" || { ExtraOperand "$1"; return; }
				;;
		esac
		shift
	done

	# primary network adapter MAC address
	IsLocalHost "$host" && { GetAdapterMacAddress; return; }

	# lookup the host for the given MAC address
	if IsMacAddress "$host"; then
		grep -i "^$host" "/etc/ethers" | cut -d" " -f2; return
	fi

	# set ipv if needed
	if [[ ! $ipv ]]; then
		if IsIpAddress4 "$host"; then ipv="4"
		elif IsIpAddress6 "$host"; then ipv="6"
		fi
	fi

	# monitor
	if [[ $monitor ]]; then
		echo "Press any key to stop monitoring '$host'..."
		
		while true; do
			hilightp "$host: "; MacLookup$ipv --detail "$host" --arp | ${G}tail --lines=+2 | tr -s " " | cut -d" " -f3 | cut -d"." -f1 | sort | NewlineToSpace; echo
			ReadChars 1 1 && return
		done
	fi

	# variables
	local mac macWin

	# resolve using /etc/ethers	
	if { [[ ! $arp ]] && mac="$(MacLookupEthers "$host")"; } || [[ $ethers ]]; then
		:

	# resolve using the IPv4 ARP table
	elif [[ "$ipv" == @(|4) ]]; then
		
		# populate the arp cache using IsAvailable
		if ! IsAvailable "$host"; then
			:

		# get the MAC address in
		elif IsPlatform win; then
			local ip; ip="$(GetIpAddress "$host")" || return
			macWin="$(RunWin arp.exe -a | grep "$ip" | tr -s " " | cut -d" " -f3 | ${G}tail --lines=-1)" || return
			mac="$(echo "$macWin" | sed 's/-/:/g')" || return # change - to :

		# get the MAC address
		else
			mac="$(arp "$host")" || return
			echo "$mac" | ${G}grep --quiet "no entry$" && { ScriptErrQuiet "no MAC address for '$host'"; return 1; }
			local column=3; IsPlatform mac && column=4
			mac="$(echo "$mac" | tr -s " " | cut -d" " -f${column} | ${G}tail --lines=-1)"
		fi

	# resolve using IPv6 Router Advertisement (RA)
	elif InPath ndisc6; then
		mac="$(ndisc6 -1 -q "$host" "$(GetInterface)")"

	fi

	# check if got a mac
	[[ ! $mac ]] && { ScriptErrQuiet "unable to lookup the MAC address for '$host'" "MacResolve"; return 1; }
	mac="$(echo "$mac" | MacPad)"

	# return the MAC address if not showing detail
	if [[ ! $detail ]]; then
		[[ $dns ]] && { mac="$(DnsResolveMac "$mac")" || return; }
		echo "$mac"
		return
	fi

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
	} | ${G}column -c $(tput cols -T "$TERM") -t -s-
}

# MacLookupEthers HOST - lookup mac address for host in /etc/ethers
MacLookupEthers()
{
	local host="$1"

	if InPath getent; then
		getent ethers "$(RemoveDnsSuffix "$host")" | cut -d" " -f1 | sed 's/\b\(\w\)\b/0\1/g' | sort | uniq # sed pads zeros, i.e. 2:2 -> 02:02 
	else
		${G}grep " $(RemoveDnsSuffix "$(LowerCase "$host")")$" "/etc/ethers" | cut -d" " -f1
	fi
}

# NetworkNeighbors - get network neighbors from the IPv6 Network Discover Protocol (NDP)
NetworkNeighbors()
{
	# populate lines in format IP MAC
	local line lines=()
	if IsPlatform mac; then IFS=$'\n' ArrayMake lines "$(ndp -an | tr -s " " | ${G}cut -d" " -f1,2 | ${G}grep -v '(incomplete)' | ${G}sed 's/\%.* / /g')" || return
	else IFS=$'\n' ArrayMake lines "$(ip -6 neigh show | cut -d" " -f1,5 | ${G}grep -v 'FAILED$')"
	fi

	# resolve MAC addresses to a name
	local host ip mac
	for line in "${lines[@]}"; do
		ip="$(GetWord "$line" 1)" mac="$(GetWord "$line" 2)"
		host="$(DnsResolveMac --quiet "$mac")" && echo "$host=$ip"
	done
}

# nmapp - run nmap for the platform
nmapp()
{	
	local file sudo; [[ $1 == @(-s|--sudo) ]] && { sudo="sudoc"; shift; }
	if IsPlatform win && InPath nmap.exe; then nmap.exe "$@"
	elif IsPlatform mac && file="/usr/local/bin/nmap" && [[ -f "$file" ]]; then $sudo "$file" "$@" # prefer nmap < 7.97 in /usr/local/bin, DhcpServers fails, https://github.com/nmap/nmap/issues/3127
	elif IsPlatform mac && file="$P/nmap.app/Contents/MacOS/nmap" && [[ -f "$file" ]]; then $sudo "$file" "$@"
	else $sudo nmap "$@"
	fi
}

NmapCanBroadcast()
{
	# arguments
	local scriptName="NmapCanBroadcast" quiet

	while (( $# != 0 )); do
		case "$1" in "") : ;;
			--quiet|-q) quiet="--quiet";;
			*) UnknownOption "$1"; return;;
		esac
		shift
	done

	# validate
	IsPlatform win && ! InPath nmap.exe && { ScriptErrQuiet "Nmap for Windows is not installed, broadcast is not possible"; return; }

	return 0
}

# PortUsage - show what ports are in use
PortUsage()
{
	if IsPlatform win; then
		header "Windows"
		RunScript --elevate -- netstat.exe -anb 
	fi

	InPath netstat && { header "netstat"; sudoc netstat -tuap; }
	InPath lsof && { header "lsof"; sudoc lsof -i -P -n; }
}

#
# network: availability
#

PortCheck() { local host="${1:-localhost}" port="${2:-502}"; IsAvailablePort "$host" "$port" && echo "OPEN" || echo "CLOSED"; }
PortOpen() { local port="${1:-502}"; echo "Listining on port $port..."; sudoc ncat -l "$port" -c '/usr/bin/data' --keep-open; }
PortScan() { local args=(); IsPlatform win && [[ ! $1 ]] && args+=(-Pn); nmap "${1:-localhost}" "${args[@]}" "$@"; } # -sT -p-

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
	# arguments
	local scriptName="IsAvailable" host timeout
	local force forceLevel forceLess noPrompt quiet test verbose verboseLevel verboseLess # for globalArgs

	while (( $# != 0 )); do
		case "$1" in "") : ;;
			--force|-f|-ff|-fff) ScriptOptForce "$1";;
			--no-prompt|-np) noPrompt="--no-prompt";;
			--quiet|-q) quiet="--quiet";;
			--test|-t) test="--test";;
			--verbose|-v|-vv|-vvv|-vvvv|-vvvvv) ScriptOptVerbose "$1";;
			*)
				if ! IsOption "$1" && [[ ! $host ]]; then host="$1"
				elif ! IsOption "$1" && [[ ! $timeout ]]; then timeout="$1"
				else UnknownOption "$1"; return
				fi
				;;
		esac
		shift
	done
	[[ $host ]] || return
	timeout="${timeout:-$(AvailableTimeoutGet)}"

	# localhost
	IsLocalHost "$host" && return 0

	# resolve the IP address explicitly:
	# - mDNS name resolution is intermitant (double check this on various platforms)
	# - Windows ping.exe name resolution is slow for non-existent hosts
	local ip; ip="$(GetIpAddress --quiet "$host" $quiet $verbose)" || return

	log2 "checking availability on host '$host' with IP "$ip" timeout $timeout"
	if IsPlatform wsl1; then # WSL 1 ping does not timeout quickly for unresponsive hosts, ping.exe does
  	RunLog3 RunSilent RunWin ping.exe -n 1 -w "$timeout" "$ip" |& grep "bytes="
	elif InPath fping; then # fping is faster if the host is not available
		RunLog3 RunSilent fping --retry 1 --timeout "$timeout" "$ip"
	else
		RunLog3 RunSilent ping -c 1 -W 1 "$ip" # -W timeoutSeconds
	fi
	local result="$?"

	log3 "host '$host' is$( (( result != 0 )) && echo " not") available"
	(( result == 0 ))
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
# -4|-6 																use IPv4 or IPv6
# --verbose|-v|-vv|-vvv|-vvvv|-vvvvv  	verbose output, does not supress error message
IsAvailablePort()
{
	# arguments
	local scriptName="IsAvailablePort" host ipv port timeout
	local force forceLevel forceLess noPrompt quiet test verbose verboseLevel verboseLess # for globalArgs

	while (( $# != 0 )); do

		case "$1" in "") : ;;
			-4) ipv="4";;
			-6) ipv="6";;

			--force|-f|-ff|-fff) ScriptOptForce "$1";;
			--no-prompt|-np) noPrompt="--no-prompt";;
			--quiet|-q) quiet="--quiet";;
			--test|-t) test="--test";;
			--verbose|-v|-vv|-vvv|-vvvv|-vvvvv) ScriptOptVerbose "$1";;
			*)
				if ! IsOption "$1" && [[ ! $host ]]; then
					host="$1"; [[ "$host" =~ : ]] && port="$(GetUriPort "$host")" host="$(GetUriServer "$host")"
					shift; continue
				fi
				! IsOption "$1" && [[ ! $port ]] && { port="$1"; shift; continue; }
				! IsOption "$1" && [[ ! $timeout ]] && { timeout="$1"; shift; continue; }
				UnknownOption "$1"; return
		esac
		shift
	done
	[[ ! $host ]] && { MissingOperand "host"; return; }
	[[ ! $port ]] && { MissingOperand "port"; return; }
	[[ ! $timeout ]] && { timeout="$(AvailableTimeoutGet)"; }

	! IsIpAddressAny "$host" && { host="$(GetIpAddress${ipv} "$host" --quiet)" || return; }
	local redirect=">& /dev/null"; [[ $verbose ]] && redirect=""

	(( verboseLevel > 1 )) &&  ScriptErr "checking port '$port' on host '$host' with timeout $timeout"
	if InPath ncat; then
		(( verboseLevel > 2 )) && ScriptErr "ncat --exec BOGUS --wait ${timeout}ms $host $port"
		eval ncat --exec "BOGUS" --wait ${timeout}ms "$host" "$port" $redirect
	elif InPath nmap; then
		(( verboseLevel > 2 )) && ScriptErr "nmap $host -p $port -Pn -T5"
		eval nmap "$host" -p "$port" -Pn -T5 '|&' grep -q "open" $redirect
	elif IsPlatform win && InPath chkport-ip.exe; then
		(( verboseLevel > 2 )) && ScriptErr "RunWin chkport-ip.exe $host $port $timeout" 
		eval RunWin chkport-ip.exe "$host" "$port" "$timeout" $redirect
	else
		return 0 
	fi
}

# IsPortAvailableUdp HOST PORT [TIMEOUT_MILLISECONDS] - return true if the host is available on the specified UDP port
IsAvailablePortUdp()
{
	# arguments
	local scriptName="IsAvailablePortUdp" host port timeout
	local force forceLevel forceLess noPrompt quiet test verbose verboseLevel verboseLess # for globalArgs

	while (( $# != 0 )); do
		case "$1" in "") : ;;
			--force|-f|-ff|-fff) ScriptOptForce "$1";;
			--no-prompt|-np) noPrompt="--no-prompt";;
			--quiet|-q) quiet="--quiet";;
			--test|-t) test="--test";;
			--verbose|-v|-vv|-vvv|-vvvv|-vvvvv) ScriptOptVerbose "$1";;
			*)
				! IsOption "$1" && [[ ! $host ]] && { host="$1"; shift; continue; }
				! IsOption "$1" && [[ ! $port ]] && { port="$1"; shift; continue; }
				! IsOption "$1" && [[ ! $timeout ]] && { timeout="$1"; shift; continue; }
				UnknownOption "$1"; return
		esac
		shift
	done
	[[ ! $host ]] && { MissingOperand "host"; return; }
	[[ ! $port ]] && { MissingOperand "port"; return; }
	[[ ! $timeout ]] && { timeout="$(AvailableTimeoutGet)"; }
	host="$(GetIpAddress "$host" --quiet)" || return
	local redirect=">& /dev/null"; [[ $verbose ]] && redirect=""

	# check
	if InPath nc; then # nc does not require root access
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
	local scriptName="PortResponse" host port timeout
	local force forceLevel forceLess noPrompt quiet test verbose verboseLevel verboseLess # for globalArgs

	while (( $# != 0 )); do
		case "$1" in "") : ;;
			--force|-f|-ff|-fff) ScriptOptForce "$1";;
			--no-prompt|-np) noPrompt="--no-prompt";;
			--quiet|-q) quiet="--quiet";;
			--test|-t) test="--test";;
			--verbose|-v|-vv|-vvv|-vvvv|-vvvvv) ScriptOptVerbose "$1";;
			*)
				! IsOption "$1" && [[ ! $host ]] && { host="$1"; shift; continue; }
				! IsOption "$1" && [[ ! $port ]] && { port="$1"; shift; continue; }
				! IsOption "$1" && [[ ! $timeout ]] && { timeout="$1"; shift; continue; }
				UnknownOption "$1"; return
		esac
		shift
	done
	[[ ! $host ]] && { MissingOperand "host"; return; }
	[[ ! $port ]] && { MissingOperand "port"; return; }
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

# ResolveCtlCheck - check if resolvectl is works (installed and will not hang)
ResolveCtlCheck() {	local timeout="200"; ResolveCtlInstalled && RunTimeout "$timeout" resolvectl status >& /dev/null; }

# ResolveCtlFix - fix resolvectl if needed (so it will not hang)
ResolveCtlFix()
{
	{ ! ResolveCtlInstalled || ResolveCtlCheck; } && return
	service restart systemd-resolved.service && ResolveCtlCheck
}

# ResolveCtlInstalled - return true if resolvectl is installed
ResolveCtlInstalled() { InPath resolvectl && systemctl is-active systemd-resolved >&/dev/null; }

# ResolveCtlValidate - check resolvectl and log a message if it is not functional
ResolveCtlValidate() { ResolveCtlCheck || ScriptErr "resolvectl status failed" "$1"; }

# WaitForAvailable HOST [HOST_TIMEOUT_MILLISECONDS] [WAIT_SECONDS]
WaitForAvailable()
{
	local scriptName="WaitForAvailable" host="$1"; [[ ! $host ]] && { MissingOperand "host"; return; }
	local timeout="${2-$(AvailableTimeoutGet)}" seconds="${3-$(AvailableTimeoutGet)}"

	printf "Waiting $seconds seconds for '$(RemoveDnsSuffix "$host")'..."
	for (( i=1; i<=$seconds; ++i )); do
 		ReadChars 1 1 && { echo "cancelled after $i seconds"; return 1; }
		printf "."
		IsAvailable "$host" "$timeout" && { echo "found"; return; }
	done

	echo "not found"; return 1
}

# WaitForNetwork NETWORK [HOST_TIMEOUT_MILLISECONDS] [WAIT_SECONDS]
WaitForNetwork()
{
	local scriptName="WaitForNetwork" network="$1"; [[ ! $network ]] && { MissingOperand "host"; return; }
	local timeout="${2-$(AvailableTimeoutGet)}" seconds="${3-$(AvailableTimeoutGet)}"

	[[ "$(NetworkCurrent)" == "$network" ]] && return

	printf "Waiting $seconds seconds for '$network' network..."
	for (( i=1; i<=$seconds; ++i )); do
 		ReadChars 1 1 && { echo "cancelled after $i seconds"; return 1; }
		printf "."
		[[ "$(NetworkCurrent)" == "$network" ]] && { echo "found"; return; }
		sleep 1
	done

	echo "not found"; return 1
}

# WaitForPort HOST[:PORT] [PORT] [TIMEOUT_MILLISECONDS] [WAIT_SECONDS]
WaitForPort()
{
	# arguments
	local scriptName="WaitForPort" host port seconds timeout
	local force forceLevel forceLess noPrompt quiet test verbose verboseLevel verboseLess # for globalArgs

	while (( $# != 0 )); do
		case "$1" in "") : ;;
			--force|-f|-ff|-fff) ScriptOptForce "$1";;
			--no-prompt|-np) noPrompt="--no-prompt";;
			--quiet|-q) quiet="--quiet";;
			--test|-t) test="--test";;
			--verbose|-v|-vv|-vvv|-vvvv|-vvvvv) ScriptOptVerbose "$1";;
			*)
				if ! IsOption "$1" && [[ ! $host ]]; then
					host="$1"; [[ "$host" =~ : ]] && port="$(GetUriPort "$host")" host="$(GetUriServer "$host")"
					shift; continue
				fi		
				! IsOption "$1" && [[ ! $port ]] && { port="$1"; shift; continue; }
				! IsOption "$1" && [[ ! $timeout ]] && { timeout="$1"; shift; continue; }
				! IsOption "$1" && [[ ! $seconds ]] && { seconds="$1"; shift; continue; }
				UnknownOption "$1"; return
		esac
		shift
	done
	[[ ! $host ]] && { MissingOperand "host"; return; }
	[[ ! $port ]] && { MissingOperand "port"; return; }
	[[ ! $timeout ]] && { timeout="$(AvailableTimeoutGet)"; }
	[[ ! $seconds ]] && { seconds="${4-$(AvailableTimeoutGet)}"; }
	local globalArgs globalArgsLess globalArgsLessForce globalArgsLessVerbose; ScriptGlobalArgsSet || return

	# return if available	
	IsAvailablePort "$host" "$port" "$timeout" "${globalArgsLessVerbose[@]}" && return

	# wait until available
	printf "Waiting for $host port $port..."
	for (( i=1; i<=$seconds; ++i )); do
 		ReadChars 1 1 && { echo "cancelled after $i seconds"; return 1; }
		printf "."
		IsAvailablePort "$host" "$port" "$timeout" "${globalArgsLessVerbose[@]}" && { echo "found"; return; }
	done

	echo "not found"; return 1
}

#
# network: configuration
#

NetworkCurrent() { UpdateGetForce "$NETWORK_CACHE"; } # NetworkCurrent - configured current network
NetworkOld() { UpdateGetForce "$NETWORK_CACHE_OLD"; } # NetworkOld - the previous network

# NetworkCurrentConfigShell - configure the shell with the current network configuration
NetworkCurrentConfigShell() { ScriptEval network vars proxy; HashiConf --force; }

# NetworkCurrentUpdate - update the current network we are on if needed
NetworkCurrentUpdate()
{
	local force forceLevel forceLess; ScriptOptForce "$@"

	# show detail if forcing
	if [[ $force || ! $(NetworkCurrent) ]]; then
		network current update "$@" || return
		ScriptEval network vars proxy "$@" || return
	else
		ScriptEval network vars proxy --quiet --update "$@" || return
	fi
}

#
# network: DNS
#

AddDnsSuffix() { GetArgs2; HasDnsSuffix "$1" && echo "$1" || echo "$1.$2"; } 	# AddDnsSuffix HOST DOMAIN - add the specified domain to host if a domain is not already present
GetDnsSuffix() { GetArgs; ! HasDnsSuffix "$1" && return; printf "${@#*.}"; }	# GetDnsSuffix HOST - the DNS suffix of the HOST
HasDnsSuffix() { GetArgs; local p="\."; [[ "$1" =~ $p ]]; }										# HasDnsSuffix HOST - true if the specified host includes a DNS suffix

# GetDnsSearch [--win] - get the system DNS search domains
GetDnsSearch()
{
	# arguments
	local scriptName="GetDnsSearch" win
	local force forceLevel forceLess noPrompt quiet test verbose verboseLevel verboseLess # for globalArgs

	while (( $# != 0 )); do
		case "$1" in "") : ;;
			--win|-w) win="--win";;

			--force|-f|-ff|-fff) ScriptOptForce "$1";;
			--no-prompt|-np) noPrompt="--no-prompt";;
			--quiet|-q) quiet="--quiet";;
			--test|-t) test="--test";;
			--verbose|-v|-vv|-vvv|-vvvv|-vvvvv) ScriptOptVerbose "$1";;
			*) UnknownOption "$1"; return;;
		esac
		shift
	done

	local search
	log4 "getting the DNS search paths"

	# win
	if [[ $win ]]; then
		log3 "using powershell"
		search="$(powershell '(Get-NetAdapter "'$(GetAdapterName)'" | Get-DnsClient).ConnectionSpecificSuffixSearchList' | RemoveCarriageReturn| sort | uniq | NewlineToSpace | RemoveSpaceTrim)"

	# mac
	elif IsPlatform mac; then
		log3 "using scutil"
		search="$(scutil --dns | grep 'search domain\[[0-9]*\]' | ${G}cut -d":" -f2- | sort | uniq | RemoveNewline | RemoveSpaceTrim)"
	
	# resolvectl - ensure it responds quickly, test using service stop dbus
	elif ResolveCtlInstalled && ResolveCtlValidate "GetDnsSearch"; then
		log3 "using resolvectl"
		search="$(resolveclt status |& grep "DNS Domain: " | head -1 | cut -d":" -f2 | RemoveSpaceTrim | SpaceToNewline | sort | uniq | NewlineToSpace | RemoveSpaceTrim)"
	fi

	# resolv.conf
	if [[ ! $search && -f "/etc/resolv.conf" ]]; then
		log3 "using resolv.conf"
		search="$(cat "/etc/resolv.conf" | grep "^search " | cut -d" " -f2- | sort | uniq | NewlineToSpace | RemoveSpaceTrim)"
	fi

	# ConfigGetCurrent
	if [[ ! $search ]]; then
		log3 "using ConfigGetCurrent"
		search="$(ConfigGetCurrent DnsSearch)"
	fi

	# return
	[[ $search ]] && { echo "$search"; return; }
	ScriptErrQuiet "unable to get the DNS search domains"
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
	# arguments
	local scriptName="DnsAlternate" host
	local force forceLevel forceLess noPrompt quiet test verbose verboseLevel verboseLess # for globalArgs

	while (( $# != 0 )); do
		case "$1" in "") : ;;
			--win|-w) win="--win";;

			--force|-f|-ff|-fff) ScriptOptForce "$1";;
			--no-prompt|-np) noPrompt="--no-prompt";;
			--quiet|-q) quiet="--quiet";;
			--test|-t) test="--test";;
			--verbose|-v|-vv|-vvv|-vvvv|-vvvvv) ScriptOptVerbose "$1";;
			*)
				! IsOption "$1" && [[ ! $host ]] && { host="$1"; shift; continue; }
				UnknownOption "$1"; return
				;;
		esac
		shift
	done

	# hardcoded to check if connected on VPN from the Butare network to the DriveTime network (coeixst.local suffix) 
	log3 "finding the alternate DNS server for host '$host'"
	if [[ ! $host || ("$host" =~ (^$|butare.net$) && "$(GetDnsSearch $quiet $verbose)" == "coexist.local") ]]; then
		echo "10.10.100.8" # butare.net primary DNS server
	fi

	return 0
}

# DnsResolve IP|NAME [SERVER] - resolve an IP address or host name to a fully qualified domain name, optional using the specified name server
# -4|-6 								use IPv4 or IPv6
# --use-alternate|-ua		suppress error message where possible
DnsResolve()
{
	# arguments
	local scriptName="DnsResolve" ipv name server useAlternate
	local force forceLevel forceLess noPrompt quiet test verbose verboseLevel verboseLess # for globalArgs
	
	while (( $# != 0 )); do
		case "$1" in "") : ;;
			-4) ipv="4";;
			-6) ipv="6";;
			--use-alternate|-ua) useAlternate="--use-alternate";;
			--win|-w) win="--win";;

			--force|-f|-ff|-fff) ScriptOptForce "$1";;
			--no-prompt|-np) noPrompt="--no-prompt";;
			--quiet|-q) quiet="--quiet";;
			--test|-t) test="--test";;
			--verbose|-v|-vv|-vvv|-vvvv|-vvvvv) ScriptOptVerbose "$1";;
			*)
				if ! IsOption "$1" && [[ ! $name ]]; then name="$1"
				elif ! IsOption "$1" && [[ ! $server ]]; then server="$1"
				else UnknownOption "$1"; return
				fi
				;;
		esac
		shift
	done
	local globalArgs globalArgsLess globalArgsLessForce globalArgsLessVerbose; ScriptGlobalArgsSet || return

	# cleanup and validate the name
	name="$(RemoveEnd "$name" ".")" # remove tailing periods, so we use the DNS search suffix
	[[ ! $name ]] && { MissingOperand "host"; return; } 

	# localhost - use the domain in the configuration
	IsLocalHost "$name" && name=$(AddDnsSuffix "$HOSTNAME" "$(GetNetworkDnsDomain)")

	# override the server if needed
	if [[ ! $server ]]; then
		if [[ $useAlternate ]]; then
			server="$(DnsAlternate $verbose)"
		else
			server="$(DnsAlternate "$name" $verbose)"
		fi
	fi

	# Resolve name using various commands
	# - -N 3 and -ndotes=3 allow the default domain names for partial names like consul.service

	# reverse DNS lookup for IP Address
	local lookup
	if IsIpAddress "$name"; then
		log3 "resolving IP address '$name' to a fully qualified DNS name using a reverse DNS lookup"

		if IsLocalHost "$name"; then
			lookup="localhost"
		
		# dscacheutil -q host -a ip_address 10.10.101.84 - returns unifi.hagerman.butare.net, IPv6 DNS issue?
		# elif [[ ! $server ]] && IsPlatform mac; then lookup="$(dscacheutil -q host -a ip_address "$name" | grep "^name:" | cut -d" " -f2)" || unset lookup
		
		elif InPath host; then
			log3 "using host"
			lookup="$(host -t A -4 "$name" $server |& ${G}grep -E "domain name pointer" | ${G}cut -d" " -f 5 | RemoveTrim ".")" || unset lookup
		
		else
			log3 "using nslookup"
			lookup="$(nslookup -type=A "$name" $server |& ${G}grep "name =" | ${G}cut -d" " -f 3 | RemoveTrim ".")" || unset lookup
		
		fi

		# use alternate for Butare network IP addresses, reverse lookup fails on mac using VPN
		if [[ ! $lookup && ! $useAlternate ]] && IsIpInCidr "$name" "10.10.100.0/22"; then
			log3 "using alternate DNS server"
			DnsResolve --use-alternate $quiet $verbose "$name" "${globalArgs[@]}"; return
		fi

	# forward DNS lookup to get the fully qualified DNS address
	else
		log3 "resolving '$name' to a fully qualified DNS name (FQDN) name using a forward DNS lookup"

		# getent - faster for known names, so use RunTimeout to limit it
		if [[ ! $server ]] && InPath getent; then
			log3 "using getent"
			lookup="$(RunTimeout getent ahostsv4 "$name" |& ${G}head -1 | tr -s " " | ${G}cut -d" " -f 3)" || unset lookup

		# dscacheutil - for mac
		elif [[ ! $server ]] && IsPlatform mac; then
			log3 "using dscacheutil"
			lookup="$(dscacheutil -q host -a name "$name" |& grep "^name:" | ${G}tail --lines=-1 | cut -d" " -f2)" || unset lookup # return the IPv4 name (the last name), dscacheutil returns ipv6 name first if present, i.e. dscacheutil -q host -a name "google.com"

		# host - faster for unknown names, slower for known names (2x slower than getent)
		elif InPath host; then
			log3 "using host"
			lookup="$(host -N 2 -t A -4 "$name" $server |& ${G}grep -v "^ns." | ${G}grep -E "domain name pointer|has address" | head -1 | cut -d" " -f 1)" || unset lookup
		
		# nslookup
		elif InPath nslookup; then
			log3 "using nslookup"
			lookup="$(nslookup -ndots=2 -type=A -timeout=1 "$name" $server |& ${G}tail --lines=-3 | ${G}grep "Name:" | ${G}cut -d$'\t' -f 2)" || unset lookup

		fi

	fi

	# error
	if [[ ! $lookup ]]; then
		log3 "unable to resolve hostname '$name'"
		[[ ! $quiet ]] && HostUnresolved "$name"; return 1
	fi

	# return lookup
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
# -4|-6 				use IPv4 or IPv6
# --all|-a			show all names, even those that could not be resolved
# --errors|-e		keep processing if an error occurs, return the total number of errors
# --full|-f  		return a fully qualified domain name
# --quiet|-q		suppress error message where possible
DnsResolveMac()
{
	local scriptName="DnsResolveMac" all errors macs=() quiet full="cat" ipv

	while (( $# != 0 )); do
		case "$1" in "") : ;;
			-4) ipv="4";;
			-6) ipv="6";;
			--all|-a) all="--all";;
			--errors|-e) errors=0;;
			--full|-f) full="DnsResolveBatch";;
			--quiet|-q) quiet="--quiet";;
			*)
				IsOption "$1" && { UnknownOption "$1"; return; }
				macs+=("$1")
				;;
		esac
		shift
	done

	[[ ! $macs ]] && { MissingOperand "mac"; return; } 	

	# validate
	local mac validMacs=()
	for mac in "${macs[@]}"; do
		IsMacAddress "$mac" && { validMacs+=("$mac"); continue; }
		ScriptErrQuiet "'$mac' is not a valid MAC address"
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
			ScriptErrQuiet "'$mac' was not found"
			[[ ! $errors ]] && return 1; (( ++errors ))
		fi

	done

	# show names
	[[ $names ]] && ArrayDelimit names $'\n' | $full; return $errors
}

# GetDnsServer [--win] - get the current DNS server
GetDnsServer()
{
	local check="www.msftconnecttest.com" server

	# arguments
	local win; [[ "$1" == "--win" ]] && win="--win"

	# win
	if [[ $win ]]; then
		server="$(nslookup.exe "$check" |& grep "^Address:" | head -1 | RemoveCarriageReturn | cut -d":" -f2- | RemoveSpaceTrim)"
		[[ $server ]] && { echo "$server"; return; }
		ipconfig /all | grep "$(GetAdapterName)" -A30 | grep "DNS Server" | cut -d":" -f2- | RemoveCarriageReturn | RemoveSpaceTrim
		return
	fi

	# resolvectl - check before nslookup since if resolvectl is used the nslookup DNS server is local (127.0.0.53)
	if ResolveCtlInstalled && ResolveCtlValidate "GetDnsServer"; then
		server="$(resolvectl status |& grep "^Current DNS Server: " | head -1 | cut -d":" -f2- | RemoveSpaceTrim | SpaceToNewline | sort | uniq | NewlineToSpace | RemoveSpaceTrim)" # Ubuntu >= 22.04
		[[ $server ]] && { echo "$server"; return; }		
	fi

	# nslookup
	server="$(nslookup "$check" |& grep "^Address:" | head -1 | cut -d":" -f2- | RemoveChar '	' | ${G}cut -d"#" -f1)"
	[[ $server ]] && { echo "$server"; return; }
}

# GetDnsServers [-4|-6|--win] - get all DNS servers
GetDnsServers()
{
	# arguments
	local scriptName="GetDnsServers" ipv win 
	local force forceLevel forceLess noPrompt quiet test verbose verboseLevel verboseLess # for globalArgs

	while (( $# != 0 )); do
		case "$1" in "") : ;;
			-4) ipv="4";;
			-6) ipv="6";;
			--win|-w) win="--win";;

			--force|-f|-ff|-fff) ScriptOptForce "$1";;
			--no-prompt|-np) noPrompt="--no-prompt";;
			--quiet|-q) quiet="--quiet";;
			--test|-t) test="--test";;
			--verbose|-v|-vv|-vvv|-vvvv|-vvvvv) ScriptOptVerbose "$1";;
			*) UnknownOption "$1"; return;;
		esac
		shift
	done

	# win
	if [[ $win ]]; then
		log3 "using powershell"
		powershell '(Get-DnsClientServerAddress -InterfaceAlias "'$(GetAdapterName)'")' | grep -E "IPv4|IPv6" | RemoveCarriageReturn | tr -s " " | cut -d" " -f5- | RemoveChar '{' | RemoveChar "}" | RemoveChar "," | SpaceToNewline | RemoveEmptyLines | sort | uniq | NewlineToSpace | RemoveSpaceTrim
		return
	fi

	# other
	local servers;
	if ResolveCtlInstalled && ResolveCtlValidate "GetDnsServers"; then
		log3 "using resolvectl"
		servers="$(resolvectl status |& grep "DNS Servers: " | head -1 | cut -d":" -f2- | RemoveSpaceTrim | SpaceToNewline | sort | uniq | NewlineToSpace | RemoveSpaceTrim)" # Ubuntu >= 22.04

	elif IsPlatform mac; then
		log3 "using scutil"
		servers="$(scutil --dns | grep 'nameserver\[[0-9]*\]' | ${G}cut -d":" -f2- | sort | uniq | RemoveNewline | RemoveSpaceTrim)"
	fi
	[[ $servers && $ipv ]] && servers="$(IpvInclude "$ipv" "$servers")"

	# resolv.conf
	if [[ ! $servers && -f "/etc/resolv.conf" ]]; then
		log3 "using resolv.conf"
		servers="$(cat "/etc/resolv.conf" | grep nameserver | cut -d" " -f2 | sort | uniq | NewlineToSpace | RemoveSpaceTrim)"
	fi
	[[ $servers && $ipv ]] && servers="$(IpvInclude "$ipv" "$servers")"

	# ConfigGetCurrent
	if [[ ! $servers ]]; then
		log3 "using ConfigGetCurrent"
		servers="$(ConfigGetCurrent DnsServers)"
	fi
	[[ $servers && $ipv ]] && servers="$(IpvInclude "$ipv" "$servers")"

	# return
	[[ $servers ]] && { echo "$servers"; return; }
	ScriptErrQuiet "unable to get the DNS servers"
}

MdnsResolve()
{
	local scriptName="MdnsResolve" name="$1" result; [[ ! $name ]] && { MissingOperand "host"; return; }

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
# network: protocols
#

# Ipv6Expand IP - expand an IPv6 address with all zeros
Ipv6Expand() { GetArgs; echo "$1" | awk '{if(NF<8){inner = "0"; for(missing = (8 - NF);missing>0;--missing){inner = inner ":0"}; if($2 == ""){$2 = inner} else if($3 == ""){$3 = inner} else if($4 == ""){$4 = inner} else if($5 == ""){$5 = inner} else if($6 == ""){$6 = inner} else if($7 == ""){$7 = inner}}; print $0}' FS=":" OFS=":" | awk '{for(i=1;i<9;++i){len = length($(i)); if(len < 1){$(i) = "0000"} else if(len < 2){$(i) = "000" $(i)} else if(len < 3){$(i) = "00" $(i)} else if(len < 4){$(i) = "0" $(i)}}; print $0}' FS=":" OFS=":"; }

# Ipv6Nibble IP [BITS](128) - expand and reverse IPv6 address to nibble format
# - https://docs.db.ripe.net/Database-Support/Configuring-Reverse-DNS/#reverse-dns-overview
# - bits is the number of bits to truncate the nibble to
# - if bits is negative, the nibble is truncated from the left (higher order) side
Ipv6Nibble()
{
	local ip="$1" bits="${2:-128}"; bits=$((bits/4))
	# expand and validate
	ip="$(Ipv6Expand "$ip")"
	! IsIpAddress6 "$ip" && { ScriptErr "'$ip' is not a valid IPv6 address" "Ipv6Token"; return 1; }

	# convert
	if (( bits < 0 )); then
		printf "$ip" | ${G}sed 's/://g' | rev | ${G}cut -c1-${bits/#-/} | ${G}sed -r 's/./&./g' | RemoveEnd "."
	else
		printf "$ip" | ${G}sed 's/://g' | ${G}cut -c1-$bits | rev | ${G}sed -r 's/./&./g' | RemoveEnd "."
	fi
}

# Ipv4Token [IP](adapter) - get an IPv4 token from an IPv6 address
Ipv4Token()
{
	local ip="$1"; [[ ! $ip ]] && { ip="$(GetIpAddress6)" ||  return; }

	# expand and validate
	ip="$(Ipv6Expand "$ip")"
	! IsIpAddress6 "$ip" && { ScriptErr "'$ip' is not a valid IPv6 address" "Ipv6Token"; return 1; }

	# get each IPv4 octet from the last two segments of the IPv6 address
	local octets=()
	octets+=("0x$(echo "$ip" | cut -d":" -f7 | cut -c1-2)")
	octets+=("0x$(echo "$ip" | cut -d":" -f7 | cut -c3-4)")
	octets+=("0x$(echo "$ip" | cut -d":" -f8 | cut -c1-2)")
	octets+=("0x$(echo "$ip" | cut -d":" -f8 | cut -c3-4)")
	
	# print
	printf "%d.%d.%d.%d\n" "${octets[@]}"
}

# Ipv6Token [IP](adapter) - get an IPv6 token from an IPv4 address
Ipv6Token()
{
	local ip="$1"; [[ ! $ip ]] && { ip="$(GetIpAddress4)" || return; }

	# validate
	! IsIpAddress4 "$ip" && { ScriptErr "'$ip' is not a valid IPv4 address" "Ipv6Token"; return 1; }

	# print
	local ips; StringToArray "$ip" "." ips
	printf "::%02x%02x:%02x%02x\n" "${ips[@]}"
}

# IpvInclude 4|6 SERVERS [DELIMITER]( ) - include only IPv4 or IPv6 servers from the delimited list of servers
IpvInclude()
{
	local ipv="$1" servers="$2" delimiter="${3:- }"; StringToArray "$servers" "$delimiter" servers
	local result; for server in "${servers[@]}"; do IsIpAddress${ipv} "$server" && result+="$server "; done
	echo "$(RemoveSpaceTrim "$result")"
}


#
# network: route
#

# RouteGet host - get the interface used to send to host
RouteGet()
{
	local host="${1:-"0.0.0.0"}"
	if IsPlatform mac; then route -n get $host | grep interface | cut -d":" -f2 | RemoveSpaceTrim
	else ip route show to match $host | cut -d" " -f5
	fi
}

# RoutePrint [--win] - print the default route table
RoutePrint()
{
	# arguments
	local win; [[ "$1" == "--win" ]] && win="--win"

	# win
	[[ $win ]] && { RunWin route.exe print; return; }

	# other
	netstat -rn
}

#
# network: services
#

# GetServer SERVICE [--quiet|-q|--use-alternate|-ua|-v] - get an active host for the specified service
GetServer() 
{
	# arguments
	local scriptName="GetServer" service useAlternate
	local force forceLevel forceLess noPrompt quiet test verbose verboseLevel verboseLess # for globalArgs

	while (( $# != 0 )); do
		case "$1" in "") : ;;
			--use-alternate|-ua) useAlternate="--use-alternate";;

			--force|-f|-ff|-fff) ScriptOptForce "$1";;
			--no-prompt|-np) noPrompt="--no-prompt";;
			--quiet|-q) quiet="--quiet";;
			--test|-t) test="--test";;
			--verbose|-v|-vv|-vvv|-vvvv|-vvvvv) ScriptOptVerbose "$1";;
			*)
				if ! IsOption "$1" && [[ ! $service ]]; then service="$1"
				else UnknownOption "$1"; return
				fi
				;;
		esac
		shift
	done

	[[ ! $service ]] && { MissingOperand "service"; return; }	

	local ip; ip="$(GetIpAddress $quiet "$service.service.$(GetNetworkDnsBaseDomain)")" || return
	log3 "getting the active host for service '$service'"
	DnsResolve $quiet $verbose $useAlternate "$ip" "$@"
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
	! IsOnNetwork "butare" && return 1	
	DnsResolve --quiet "$1.service.$(GetNetworkDnsDomain)" > /dev/null
}

#
# network: SSH
#

IsSsh() { [[ $SSH_CONNECTION || $XPRA_SERVER_SOCKET ]]; }		# IsSsh - return true if connected over SSH
IsXpra() { [[ $XPRA_SERVER_SOCKET ]]; }											# IsXpra - return true if connected using XPRA
RemoteServer() { echo "${SSH_CONNECTION%% *}"; }						# RemoveServer - return the IP addres of the remote server that the SSH session is connected from
RemoteServerName() { DnsResolve "$(RemoteServer)"; }				# RemoveServerName - return the DNS name remote server that the SSH session is connected from

SshConfigGet() { local host="$1" value="$2"; ssh -T -G "$host" | grep -i "^$value " | head -1 | cut -d" " -f2; } # SshConfigGet HOST VALUE - do not use SshHelp config get for speed
SshInPath() { SshHelper connect "$1" -- which "$2" >/dev/null; } 																							# SshInPath HOST FILE

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
	local sshDir="$HOME/.ssh" dir

	# validate existings SSH agents from environment files
	if SshAgentValidate "$HOME/.ssh/environment"; then return
	elif dir="$(GetWritableDir "$sshDir")" && [[ "$dir" != "$sshDir" ]] && SshAgentValidate "$dir/environment"; then return
	fi

	# return without error if no SSH keys are available
	! SshAgent check keys && { [[ $verbose ]] && ScriptErr "no SSH keys found in $HOME/.ssh", "SshAgentConf"; return 0; }

	# start the ssh-agent and set the environment
	(( verboseLevel > 1 )) && header "SSH Agent Configuration"
	SshAgent start "$@" && ScriptEval SshAgent environment "$@"
}

# SshAgentValidate FILE - load and validate the ssh-agent configuration in FILE - faster than calling SshAgent
SshAgentValidate()
{
	local file="$file"

	# load the environmnet variables from the file if possible
	[[ -f "$file" ]] && eval "$(cat "$file")"

	# valid if the ssh-agent has keys already loaded
	ssh-add -L >& /dev/null && { [[ $verbose ]] && SshAgent status; return 0; }

	# not valid
	return 1
}

SshAgentConfStatus() { SshAgentConf "$@" && SshAgent status; }

# SshSudoc HOST COMMAND ARGS - run a command on host using sudoc
SshSudoc() { SshHelper connect --credential --function "$1" -- sudoc "${@:2}"; }

# GetSshHost [USER@]HOST[:PORT] -> HOST
GetSshHost()
{
	GetArgs; local gsp="$1"

	# remove user
	gsp="${gsp/#$(GetSshUser "$gsp")@/}"

	# remove port
	gsp="${gsp/%:$(GetSshPort "$gsp")/}"

	# trim and return
	r "$(RemoveSpaceTrim "$gsp")" $2
}

# GetSshPort [USER@]HOST[:PORT] -> PORT
GetSshPort()
{
	# remove user
	GetArgs; local gsp="$1"; [[ "$gsp" =~ @ ]] && gsp="${gsp##*@}"

	# no port if no colon or we have a valid IPv6 address
	{ [[ ! "$gsp" =~ : ]] || IsIpAddress6 "$gsp"; } && { r "" $2; return; }

	# remove port
	gsp="${gsp##*:}"; r "$(RemoveSpaceTrim "$gsp")" $2	
}

# GetSshUser [USER@]HOST[:PORT] -> PORT
GetSshUser()
{
	GetArgs; local gsu; [[ "$1" =~ @ ]] && gsu="${1%@*}"; r "$(RemoveSpaceTrim "$gsu")" $2
}

#
# network: GIO shares - # .../smb-share:server=SERVER,share=SHARE/...
#

GetGioServer() { GetArgs; local ggs="${1#*server=}"; ggs="${ggs%,*}"; r "$ggs" $2; }
GetGioShare() { GetArgs; local ggs="${1#*share=}"; ggs="${ggs%%/*}"; r "$ggs" $2; }

#
# network: UNC shares - [PROTOCOL:]//[USER@]SERVER/SHARE[/DIRS][:PROTOCOL]
#

CheckNetworkProtocol() { [[ "$1" == @(|nfs|rclone|smb|ssh) ]] || IsInteger "$1"; }
GetUncRoot() { GetArgs; r "//$(GetUncServer "$1")/$(GetUncShare "$1")" $2; }																				# //SERVER/SHARE
GetUncServer() { GetArgs; local gus="${1#*( )*(*:)//}"; gus="${gus#*@}"; r "${gus%%/*}" $2; }												# SERVER
GetUncShare() { GetArgs; local gus="${1#*( )*(*:)//*/}"; gus="${gus%%/*}"; gus="${gus%:*}"; r "${gus:-$3}" $2; }		# SHARE
GetUncDirs() { GetArgs; local gud="${1#*( )*(*:)//*/*/}"; [[ "$gud" == "$1" ]] && gud=""; r "${gud%:*}" $2; } 			# DIRS
IsUncPath() { [[ "$1" =~ ^(\ |.*:)*//.* ]]; }

IsRcloneRemote() { [[ -f "$HOME/.config/rclone/rclone.conf" ]] && grep --quiet "^\[$1\]$" "$HOME/.config/rclone/rclone.conf"; }

# GetUncFull [--ip] UNC: return the UNC with server fully qualified domain name or an IP
GetUncFull()
{
	# arguments
	local scriptName="GetUncFull" ip unc
	local force forceLevel forceLess noPrompt quiet test verbose verboseLevel verboseLess # for globalArgs
	
	while (( $# != 0 )); do
		case "$1" in "") : ;;
			--ip) ip="true";;

			--force|-f|-ff|-fff) ScriptOptForce "$1";;
			--no-prompt|-np) noPrompt="--no-prompt";;
			--quiet|-q) quiet="--quiet";;
			--test|-t) test="--test";;
			--verbose|-v|-vv|-vvv|-vvvv|-vvvvv) ScriptOptVerbose "$1";;
			*)
				if ! IsOption "$1" && [[ ! $unc ]]; then unc="$1"
				else UnknownOption "$1"; return
				fi
		esac
		shift
	done

	[[ ! $unc ]] && { MissingOperand "unc"; return; }

	# parse the UNC
	local user="$(GetUncUser "$unc")"
	local server="$(GetUncServer "$unc")"
	local share="$(GetUncShare "$unc")"
	local dirs="$(GetUncDirs "$unc")"
	local protocol="$(GetUncProtocol "$unc")"

	# exclude if not a server
	{ [[ "$(LowerCase "$server")" == @(cryfs) ]] || IsRcloneRemote "$server"; } && { echo "$unc"; return; }

	# force use of the IP if the host requires an alternate DNS server
	[[ $(DnsAlternate "$server" $verbose) ]] && ip="--ip"

	# resolve the server
	if [[ ! "$server" ]]; then
		if [[ $ip ]]; then
			server="$(GetIpAddress "$server" $quiet $verbose)" || return
		else
			server="$(DnsResolve "$server" $quiet $verbose)" || return
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
	# [PROTOCOL:]//[USER@]SERVER/SHARE[/DIRS][:PROTOCOL]
	GetArgs; local gup="$(RemoveSpaceTrim "$1")"

	# protocol in front
	if [[ "$gup" =~ ^[a-zA-Z0-9]*:// ]]; then
		gup="${gup%%:*}"
		echo hi

	# protocol in end - remove //[USER@]SERVER/[/DIRS]:PROTOCOL
	elif gup="${gup##*/}" && [[ "$gup" =~ : ]]; then
		gup="${gup##*:}"  # //[USER@]SERVER/SHARE[/DIRS][:PROTOCOL]
	
	# no protocol specified - use default
	else
		gup="$3"
	
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
GetUriDirs() { GetArgs; local gud="${1#*//*/}"; [[ "$gud" == "$1" ]] && gud=""; r "$gud" $2; }
IsHttps() { GetArgs; [[ "$(GetUriProtocol "$@")" == "https" ]]; }

GetUriServer()
{
	GetArgs
	local gsh="${1#*//}" 	# remove protocol
	gsh="${gsh%%/*}"			# remove dirs

	# remove protocol - if an IPv6 address 9 colons assume the port is after the last colon
	if [[ "$gsh" =~ .*:.*:.* ]] ; then
		local parts; StringToArray "$gsh" ":" parts	
		(( ${#parts[@]} == 9 )) && gsh="${gsh%:*}"
	else
		gsh="${gsh%:*}"
	fi
		
	r "$(RemoveSpaceTrim "$gsh")" $2
}


GetUriPort()
{
	GetArgs; local gup="${1##*//}"; 

	# IPv6 address - if it has 9 colons assume the port is after the last colon
	if [[ "$gup" =~ .*:.*:.* ]] ; then
		local parts; StringToArray "$gup" ":" parts	
		(( ${#parts[@]} != 9 )) && { r "" $2; return; }
	fi

	# get the port
	gup="${1##*:}"; r "${gup%%/*}" $2
}


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

UriMake()
{
	local protocol="$1" server="$2" port="$3" dirs="$4"
	local uri="//$server"
	[[ $protocol ]] && uri="$protocol:$uri"
	[[ $port ]] && uri="$uri:$port"
	[[ $dirs ]] && uri="$uri/$(RemoveFront "$dirs" "/")"
	echo -n "$uri"
}

#
# network: URL - HTTP[S]://SERVER:PORT[/DIRS]
#

IsUrl() { [[ "$1" =~ ^[A-Za-z][A-Za-z0-9+-]+: ]]; }											# IsUrl URL - true if URL is a valid URL
UrlExists() { curl --output /dev/null --silent --head --fail "$1"; }		# UrlExists URL - true if the specified URL exists

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

UrlEncodeSpace()
{
	GetArgs
	echo "$1" | sed '
		s/ /%20/g 
  '
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
	IsPlatform rpm,yum && { echo "rpm"; return; }
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
	IsPlatform mac && exclude+=( atop fortune-mod hdparm inotify-tools iotop iproute2 ksystemlog ncat ntpdate psmisc squidclient unison-gtk virt-what )
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
	local force forceLevel forceLess; ScriptOptForce "$@"	
	[[ ! $force ]] && ! PackageInstalled "$1" && return

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

# PackageVersion - package version
PackageVersion()
{
	if IsPlatform apt; then apt policy "$@"
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
	local scriptName="IsPlatform" all host hostArg=() p platforms=() useHost

	# arguments
	while (( $# != 0 )); do
		case "$1" in "") : ;;
			-a|--all) all="true";;
			--host|-H)
				[[ $2 ]] && ! IsOption "$2" && { host="$2"; shift; }
				useHost="true" hostArg=(--host "$host")
				;;
			*)
				if ! IsOption "$1" && [[ ! $platforms ]]; then StringToArray "$1" "," platforms
				else UnknownOption "$1"; return
				fi
				;;
		esac
		shift
	done

	# set _platformOs variables
	if [[ $useHost && $host ]]; then		
		ScriptEval HostGetInfo "$host" || return
	elif [[ ! $useHost ]]; then
		local _platformTarget="localhost" _platformLocal="true" _platformOs="$PLATFORM_OS" _platformIdMain="$PLATFORM_ID_MAIN" _platformIdLike="$PLATFORM_ID_LIKE" _platformIdBase="$PLATFORM_ID_BASE" _platformKernel="$PLATFORM_KERNEL" _machine="$MACHINE" _wsl="$WSL"
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

# isPlatformCheck - for use by IsPlatform only
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
		deb|debian) [[ "$_platformIdMain" == "debian" || "$_platformIdLike" == "debian" ]];;
		debianbase) [[ "$_platformIdMain" == "debian" && "$_platformIdLike" == "" ]];;
		debianlike) [[ "$_platformIdLike" == "debian" ]];;
		armbian) [[ "$p" == "$_platformIdBase" ]];;

		# aliases
		embedded) IsPlatform pi,piKernel,rock,RockKernel "${hostArg[@]}";;
		nas) IsPlatform qnap|synology;;
		rh) IsPlatform rhel "${hostArg[@]}";; # Red Hat

		# windows
		wsl) [[ "$_platformOs" == "win" && "$_platformIdLike" == "debian" ]];; # Windows Subsystem for Linux
		wsl1|wsl2) [[ "$p" == "$_platformKernel" ]];;

		# hardware
		32|64) [[ "$p" == "$(os bits "$_machine" )" ]];;
		arm|mips|x86) [[ "$p" == "$(os architecture "$_machine" | LowerCase)" ]];;
		x64) eval IsPlatformAll x86,64 "${hostArg[@]}";;

		# kernel
		winkernel) [[ "$_platformKernel" == @(wsl1|wsl2) ]];;
		linuxkernel) [[ "$_platformKernel" == "linux" ]];;
		pikernel) [[ "$_platformKernel" == "pi" ]];;
		rock|rockkernel) [[ "$_platformKernel" == "rock" ]];;

		# HashiCorp
		consul) [[ "$(ps -p $PPID -o comm=)" == *"consul"* ]];;		# running inside a Consul service check script
		nomad) [[ $NOMAD_TASK_DIR ]];;														# running inside a Nomad task

		# other
		entware) IsPlatform qnap,synology "${hostArg[@]}";;
		
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
		host|physical) IsPhysical;;
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
	[[ "$PLATFORM_ID_BASE" != "$PLATFORM_OS" && -f "$1$PLATFORM_ID_BASE$2" ]] && files+=("$1$PLATFORM_ID_BASE2")
	[[ "$PLATFORM_ID_LIKE" != "$PLATFORM_OS" && -f "$1$PLATFORM_ID_LIKE$2" ]] && files+=("$1$PLATFORM_ID_LIKE$2")
	[[ "$PLATFORM_ID_MAIN" != "$PLATFORM_OS" && -f "$1$PLATFORM_ID_MAIN$2" ]] && files+=("$1$PLATFORM_ID_MAIN$2")
	IsPlatform PiKernel && [[ -f "$1pi$2" ]] && files+=("$1pi$2")

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
		[[ $1 ]] && { ScriptEval HostGetInfo "$1" || return; hostArg+=("$1"); }
	else
		local _platformOs="$PLATFORM_OS" _platformIdMain="$PLATFORM_ID_MAIN" _platformIdLike="$PLATFORM_ID_LIKE" _platformIdBase="$PLATFORM_ID_BASE" _platformKernel="$PLATFORM_KERNEL" _machine="$MACHINE" _wsl="$WSL"
	fi

	# run platform function
	[[ $_platformOs ]] && { RunFunction $function $_platformOs -- "$@" || return; }
	[[ $_platformIdBase ]] && { RunFunction $function $_platformIdBase -- "$@" || return; }
	[[ $_platformIdLike && "$_platformIdLike" != "$platformOs" ]] && { RunFunction $function $_platformIdLike -- "$@" || return; }
	[[ $_platformIdMain && "$platformIdMain" != "$platformOs" ]] && { RunFunction $function $_platformIdMain -- "$@" || return; }

	# run windows WSL functions
	if [[ "$PLATFORM_OS" == "win" ]]; then
		IsPlatform wsl "${hostArg[@]}" && { RunFunction $function wsl -- "$@" || return; }
		IsPlatform wsl1 "${hostArg[@]}" && { RunFunction $function wsl1 -- "$@" || return; }
		IsPlatform wsl2 "${hostArg[@]}" && { RunFunction $function wsl2 -- "$@" || return; }
	fi

	# run other functions
	IsPlatform cm4 --host && { RunFunction $function cm4 -- "$@" || return; }
	IsPlatform entware --host && { RunFunction $function entware -- "$@" || return; }
	IsPlatform pikernel --host && { RunFunction $function PiKernel -- "$@" || return; }
	IsPlatform proxmox --host && { RunFunction $function proxmox -- "$@" || return; }
	IsPlatform gnome --host && { RunFunction $function gnome -- "$@" || return; }
	IsPlatform vm --host && { RunFunction $function vm -- "$@" || return; }
	IsPlatform physical --host && { RunFunction $function physical -- "$@" || return; }

	return 0
}

# RunPlatformOs PREFIX [ARGS] - call platform functions for PLATFORM_OS only (faster)
function RunPlatformOs()
{
	local function="$1"; shift
	RunFunction "$function" "$PLATFORM_OS" -- "$@"
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
IsMacApp() { IsPlatform mac || return; FindMacApp "$1" >& /dev/null; }
IsRoot() { [[ "$USER" == "root" || $SUDO_USER ]]; }
IsSystemd() { IsPlatform mac && return 1; cat /proc/1/status | grep -i "^Name:[	 ]*systemd$" >& /dev/null; } # systemd must be PID 1
IsWinAdmin() { IsPlatform win && { IsInDomain sandia || RunWin net.exe localgroup Administrators | RemoveCarriageReturn | grep --quiet "$WIN_USER$"; }; }
pkillchildren() { pkill -P "$1"; } # pkillchildren PID - kill process and children
ProcessIdExists() {	kill -0 $1 >& /dev/null; } # kill is a fast check
pschildren() { ps --forest $(ps -e --no-header -o pid,ppid|awk -vp=$1 'function r(s){print s;s=a[s];while(s){sub(",","",s);t=s;sub(",.*","",t);sub("[0-9]+","",s);r(t)}}{a[$2]=a[$2]","$1}END{r(p)}'); } # pschildren PPID - list process with children
pschildrenc() { local n="$(pschildren "$1" | wc -l)"; (( n == 1 )) && return 1 || echo $(( n - 2 )); } # pschildrenc PPID - list count of process children
pscount() { ProcessList | wc -l; }
RunQuiet() { [[ $verbose ]] && { "$@"; return; }; "$@" 2> /dev/null; }		# RunQuiet COMMAND... - suppress stdout unless verbose logging
RunSilent() {	[[ $verbose ]] && { "$@"; return; }; "$@" >& /dev/null; }		# RunQuiet COMMAND... - suppress stdout and stderr unless verbose logging

# PipeStatus N - return the status of the 0 based Nth command in the pipe
if IsZsh; then
	PipeStatus() { echo "${pipestatus[$(($1+1))]}"; }
else
	PipeStatus() { return ${PIPESTATUS[$1]}; }
fi

# FindMacApp APP - return the location of a Mac applciation
FindMacApp()
{	
	! IsPlatform mac && return

	# check directory
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
	[[ -d "/System/Applications/$app.app" ]] && { echo "/System/Applications/$app.app"; return; }
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

# IsProcessRunning NAME - check if NAME is a running process
# -a|--all 		ensure check for all process
# -u|--user		ensure check only for user process
#
# - if nether --all or --user is specified, IsProcessRunning can check for all or only user processes
IsProcessRunning()
{

	local scriptName="IsProcessRunning" all name user win
	local force forceLevel forceLess noPrompt quiet test verbose verboseLevel verboseLess # for globalArgs

	while (( $# != 0 )); do
		case "$1" in "") : ;;
			--all|-a) all="--all";;
			--user|-u) user="--user";;

			--force|-f|-ff|-fff) ScriptOptForce "$1";;
			--no-prompt|-np) noPrompt="--no-prompt";;
			--quiet|-q) quiet="--quiet";;
			--test|-t) test="--test";;
			--verbose|-v|-vv|-vvv|-vvvv|-vvvvv) ScriptOptVerbose "$1";;
			*)
				! IsOption "$1" && [[ ! $name ]] && { name="$1"; shift; continue; }
				UnknownOption "$1"; return
		esac
		shift
	done
	[[ ! "$name" ]] && { MissingOperand "name"; return; }

	# check Windows process
	IsWindowsProcess "$name" && { IsProcessRunningList "$name" --win; return; }

	# pidof check - faster, searches all processes, uses path if present, deprecated for mac
	[[ ! $user && ! $hasFilePath ]] && InPath pidof && ! IsPlatform mac && { pidof -snq "$name"; return; }

	# user arguments - restrict to the real user ID
	local args=(); [[ ${UID:-$USER} ]] && [[ ! $all || $user ]] && user="--user" args+=("-U" "${UID:-$USER}")

	# pgrep for mac applications (which end in .app), assumes:
	# - name is the application directory, i.e. /Applications/GitKraken.app
	# - process name is the application directory without .app, i.e. GitKraken
	# - pgrep for mac - does not have the 15 character limit that newer versions of pgrep do (full option not required)
	if [[ "$name" =~ \.app$ ]] && IsPlatform mac; then
		name="$(GetFileNameWithoutExtension "$name")"
		pgrep "${args[@]}" "^${name}( .*|$)" > /dev/null
		return
	fi

	# pgrep check - name must exactly match argv[0] (with or without path)
	if InPath pgrep; then
		pgrep "${args[@]}" -f "^$name( .*|$)" > /dev/null
		return
	fi

	# ProcessList check - slowest
	ProcessList $user $all | qgrep ",${name}$"
}

# IsProcessRunningList [--user|--unix|--win] NAME - check if NAME is in the list of running processes.  Slower than IsProcessRunning.
IsProcessRunningList() 
{
	local scriptName="IsProcessRunningList" name="$1"; shift

	# get processes - grep fails if ProcessList call in the same pipline on Windows
	local processes; 
	if [[ $CACHED_PROCESSES ]]; then
		processes="$CACHED_PROCESSES"
		(( verboseLevel > 2 )) && ScriptErr "using cached processes to lookup '$name'"
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
	local name="$1"; [[ ! $1 ]] && { MissingOperand "name" "IsWindowsProcess"; return; }
	! IsPlatform win && return 1
	[[ "$(GetFileExtension "$name")" == "exe" ]] && return 0
	[[ ! -f "$name" ]] && { name="$(FindInPath "$name")" || return; }
	[[ "$(GetFileExtension "$name")" == "exe" ]] && return 0
	file "$name" | grep --quiet "PE32"
}

# ProcessClose|ProcessCloseWait|ProcessKill NAME... - close or kill the specified process
# --force|-f			do not check if the process exists
# --quiet|-q 			minimize informational messages
# --root|-r 			kill processes as root
# --timeout|-t		time to wait for the process to end in seconds
# --verbose|-v		verbose mode, multiple -v increase verbosity (max 5)
ProcessClose() 
{ 
	# arguments
	local scriptName="ProcessClose" args=() names=() root timeout=10
	local force forceLevel forceLess noPrompt quiet test verbose verboseLevel verboseLess # for globalArgs

	while (( $# != 0 )); do
		case "$1" in "") : ;;
			--root|-w) root="sudoc";;
			--timeout|--timeout=*|-t|-t=*) . script.sh && ScriptOptTimeout "$@";;

			--force|-f|-ff|-fff) ScriptOptForce "$1";;
			--no-prompt|-np) noPrompt="--no-prompt";;
			--quiet|-q) quiet="--quiet";;
			--test|-t) test="--test";;
			--verbose|-v|-vv|-vvv|-vvvv|-vvvvv) ScriptOptVerbose "$1";;
			*)
				! IsOption "$1" && { names+=("$1"); shift; continue; }
				UnknownOption "$1"; return
		esac
		shift
	done
	[[ ! $names ]] && { MissingOperand "name"; return; }

	# close
	local finalResult="0" name result win
	for name in "${names[@]}"; do

		# continue if the process is not running
		[[ ! $force ]] && ! IsProcessRunning $root "$name" && continue

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
			$root pkill -f "^${name}( .*|$)" "${args[@]}"; result="$?"
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
	local scriptName="ProcessCloseWait" names=() root seconds=10
	local force forceLevel forceLess noPrompt quiet test verbose verboseLevel verboseLess # for globalArgs
	
	# options
	while (( $# != 0 )); do
		case "$1" in "") : ;;
			--root|-r) root="--root";;

			--force|-f|-ff|-fff) ScriptOptForce "$1";;
			--no-prompt|-np) noPrompt="--no-prompt";;
			--quiet|-q) quiet="--quiet";;
			--test|-t) test="--test";;
			--verbose|-v|-vv|-vvv|-vvvv|-vvvvv) ScriptOptVerbose "$1";;
			*)
				! IsOption "$1" && { names+=("$1"); shift; continue; }
				UnknownOption "$1"; return
		esac
		shift
	done
	[[ ! $names ]] && { MissingOperand "name"; return; }

	# close
	local name
	for name in "${names[@]}"; do

		# continue if not running
		[[ ! $force ]] && ! IsProcessRunning $root "$name" && continue
		# close the process
		[[ ! $quiet ]] && printf "Closing process $name..."
		ProcessClose $root "$name"

		# wait for process to close
		local description="closed"
		for (( i=1; i<=$seconds; ++i )); do
	 		ReadChars 1 1 && { [[ ! $quiet ]] && echo "cancelled after $i seconds"; return 1; }
			[[ ! $quiet ]] && printf "."
			! IsProcessRunning $root "$name" && { [[ ! $quiet ]] && echo "$description"; return; }
			sleep 1; description="killed"; ProcessKill $root "$name"
		done

		[[ ! $quiet ]] && echo "failed"; return 1

	done
}

ProcessKill()
{
	# arguments
	local scriptName="ProcessKill" args=() force names=() quiet root rootArg win

	while (( $# != 0 )); do
		case "$1" in "") : ;;
			--force|-f) force="--force";;
			--quiet|-q) quiet="--quiet";;
			--root|-r) rootArg="--root" root="sudoc";;
			--win|-w) win="--win";;
			*)
				! IsOption "$1" && { names+=("$1"); shift; continue; }
				UnknownOption "$1"; return
		esac
		shift
	done
	[[ ! $names ]] && { MissingOperand "name"; return; }

	# kill
	local name output result resultFinal="0"
	for name in "${names[@]}"; do

		# continue if not running
		[[ ! $force ]] && ! IsProcessRunning $rootArg "$name" && continue

		# check for Windows process
		[[ ! $win ]] && IsWindowsProcess "$name" && win="true"

		# kill the process
		if [[ $win ]]; then
			output="$(start pskill.exe -nobanner "$name" |& grep "unable to kill process" | grep "^Process .* killed$")"
		else
			[[ ! $root ]] && args+=("--uid" "$USER")
			output="$($root pkill -9 -f "^${name}( .*|$)" "${args[@]}")"
		fi
		result="$?"

		# process result
		[[ ! $quiet && $output ]] && echo "$output"
		if (( $result != 0 )); then
			resultFinal="1"
			[[ ! $quiet ]] && ScriptErr "unable to kill '$name'"
		elif [[ $verbose ]]; then
			ScriptErr "killed process '$name'"
		fi

	done

	return "$resultFinal"
}

# ProcessList [--user|--unix|--win|--comm] - show process ID and executable name with a full path in format PID,NAME
# -a|--all		all processes (default)
# -u|--user		only user processes
# -U|--unix		only UNIX processes
# -w|--win		only Windows processes
# -c|--comm 	show command name (the executable name without the path)
ProcessList() 
{ 
	# arguments
	local scriptName="ProcessList" all comm unix="true" user win="true"

	while (( $# != 0 )); do
		case "$1" in "") : ;;
			-a|--all) all="--all";;
			-c|--comm) comm="--comm";;
			-u|--user) user="--user";;
			-U|--unix) unset win;;
			-w|--win) unset unix;;
			*) UnknownOption "$1"; return
		esac
		shift
	done

	# arguments
	local args=(-e); [[ ${UID:-$USER} ]] && [[ ! $all || $user ]] && user="--user" args+=("-U" "${UID:-$USER}")

	# mac proceses - ps behavior is differn than Linux, --comm has full path, -c removes path
	if IsPlatform mac; then
		 [[ $comm ]] && args+=(-c)
		 ps "${args[@]}" -o pid=,comm= | ${G}awk '{ print $1 "," substr($0, index($0, $2)) }'
		 return
	fi

	# unix processes
	if [[ $unix ]]; then
		if [[ $comm ]]; then
			ps $args -o pid=,comm= | awk '{ print $1 "," substr($0, index($0, $2)) }'
		else
			# command has arguments so assume program has no spaces, otherwsise we can't tell when the program end and the arguments start
			ps $args -o pid=,command= | awk '{ print $1 "," $2 }' 
		fi
	fi

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

# ProcessResource RESOURCE... - list processes using the resource
ProcessResource()
{
	if IsPlatform win; then
		[[ ! $@ ]] && { RunScript --elevate -- handle.exe -nobanner "$@"; return; }
		local resource
		for resource in "$@"; do 
			(( $# > 1 )) && header "$resource"
			RunScript --elevate -- handle.exe -nobanner "$resource" || return
		done
		return
	fi
	InPath lsof && { lsof "$@"; return; }
	ScriptErr "no process resource command is installed" "ProcessResource"
}

pstree()
{
	local pstreeOpts=(); IsPlatform mac && pstreeOpts+=(-g 2)
	InPath pstree && { command pstree "${pstreeOpts[@]}" "$@"; return; }
	! IsPlatform mac && { ps -axj --forest "$@"; return; }
	return
}

# RunTimeout [TIMEOUT_MILLISECONDS] COMMAND... - run a command with a timeout
RunTimeout()
{	
	# arguments
	local timeout="$1"
	if IsNumeric "$timeout"; then
		shift
	else
	 	timeout="$(AvailableTimeoutGet)"
	fi
	timeout="$(bc <<< "scale=4; $timeout/1000")"

	# run command
	timeout "$timeout" "$@"
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
	local scriptName="start" elevate file sudo terminal wait windowStyle
	local force forceLevel forceLess noPrompt quiet test verbose verboseLevel verboseLess # for globalArgs

	while (( $# != 0 )); do
		case "$1" in "") : ;;
			--elevate|-e) IsPlatform win && CanElevate && ! IsElevated && elevate="--elevate";;
			--help|-h) startUsage; return 0;;
			--sudo|-s) sudov || return; sudo="sudo";;
			--terminal|-T) [[ ! $2 ]] && { startUsage; return 1; }; terminal="$2"; shift;;
			--wait|-w) wait="--wait";;
			--window-style|-ws) [[ ! $2 ]] && { startUsage; return 1; }; windowStyle="$(LowerCase "$2")"; shift;;

			--force|-f|-ff|-fff) ScriptOptForce "$1";;
			--no-prompt|-np) noPrompt="--no-prompt";;
			--quiet|-q) quiet="--quiet";;
			--test|-t) test="--test";;
			--verbose|-v|-vv|-vvv|-vvvv|-vvvvv) ScriptOptVerbose "$1";;
			*)
				! IsOption "$1" && [[ ! $file ]] && { file="$1"; shift; break; }
				UnknownOption "$1"; return
		esac
		shift
	done

	[[ ! "$file" ]] && { MissingOperand "file"; return; }

	local args=( "$@" ) fileOrig="$file"

	# RunProcess.exe (Windows)
	local runProcess=()
	if IsPlatform win && InPath "RunProcess.exe"; then
		runProcess=(RunWin RunProcess.exe $wait $elevate)
		[[ $windowStyle ]] && runProcess+=(--window-style "$windowStyle")
		[[ $verbose ]] && runProcess+=(--verbose --pause)
	fi

	# open (Mac)	
	local openArgs=()
	if IsPlatform mac && InPath "open"; then
		[[ "$windowStyle" == "hidden" ]] && openArgs+=(-j) 
		[[ "$windowStyle" == "minimized" ]] && openArgs+=(-g) 
	fi

	# start Mac application 
	if IsMacApp "$file"; then
		
		# find the physical app location if possible
		[[ ! -d "$file" ]] && file="$(GetFileNameWithoutExtension "$file")"
		if [[ ! -d "$file" && -d "$P/$file.app" ]]; then file="$P/$file.app"
		elif [[ ! -d "$file" && -d "/System/Applications/$file.app" ]]; then file="/System/Applications/$file.app"
		elif [[ ! -d "$file" && -d "$HOME/Applications/$file.app" ]]; then file="$P/$file.app"
		fi

		local open=(open "${openArgs[@]}" -a "$file")
		[[ ! "$file" =~ TextEdit ]] && open+=(--args) # uses AppleEvents 
		open+=("${args[@]}")
		(( verboseLevel > 1 )) && ScriptArgs "${open[@]}"

		# we could not find the app, just try and open it
		[[ ! -d "$file" ]] && { "${open[@]}"; return; }

		# open the app, waiting for the OS to see newly installed apps if needed
		local result; result="$("${open[@]}")" && return
		[[ ! "$result" =~ "Unable to find application named" ]] && { ScriptErrQuiet "$result"; return 1; }
		StartWaitExists "$file"; return
	fi

	# find file in path
	[[ "$(GetCommandType "$file")" == "file" ]] && file="$(FindInPath "$file")"

	# open directories, URLs, and non-executable files
	if [[ -d "$file" ]] || IsUrl "$file" || { [[ -f "$file" ]] && ! IsExecutable "$file"; }; then

		# get the full path of files
		[[ -f "$file" ]] && file="$(GetFullPath "$file")"

		# determine open program
		local open=()
		if [[ -d "$file" ]]; then explore "$file"; return
		elif IsPlatform mac; then open=( open )
		elif IsPlatform win; then open=( explorer.exe )
		elif InPath xdg-open; then open=( xdg-open )
		else ScriptErrQuiet "unable to open '$fileOrig'"; return 1
		fi

		# open
		(( verboseLevel > 1 )) && ScriptMessage "opening file '$file'"
		(
			#IsPlatform win && ! drive IsWin . && cd "$WIN_ROOT"
			start $verbose "${open[@]}" "$file" "${args[@]}";
		)		
		return
	fi

	# validate file exists
	[[ ! -f "$file" ]] && { ScriptErrQuiet "unable to find '$fileOrig'"; return 1; }

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
			(( verboseLevel > 1 )) && ScriptArgs "${runProcess[@]}" "${p[@]}" --exec "$(FindInPath "$fullFile")" "${args[@]}"
			"${runProcess[@]}" "${p[@]}" --exec "$(FindInPath "$fullFile")" "${args[@]}"

		else
			(( verboseLevel > 1 )) && ScriptArgs "${runProcess[@]}" "$(utw "$fullFile")" "${args[@]}"
			"${runProcess[@]}" "$(utw "$fullFile")" "${args[@]}"
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
		PathAdd "$front" "$PYTHON_USER_BIN"
		
		PYTHON_CHECKED="true"
	fi

	# configure direnv for virtual environments
	if [[ -f ".envrc" ]] && InPath direnv; then
		DirenvConf || return
		qgrep pyenv ".envrc" && { PyenvConf || return; }
	fi

	return 0
}

# PyEnvCreate [dir](.) [version] - make a Python virtual environment in the current directory
PyEnvCreate()
{
	local scriptName="PyEnvCreate" dir="$1"; [[ $dir ]] && shift || { MissingOperand "dir"; return; }
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
MissingOption() { ScriptErr "missing $1 option" "$2"; }
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

# RunFunction NAME [SUFFIX] -- [ARGS] - call a function if it exists, optionally with the specified suffix (i.e. nameSuffix)
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
	local scriptName="RunFunctions" function functions=() ignoreErrors result

	while (( $# != 0 )); do
		case "$1" in "") : ;;
			--ignore-errors|-ie) ignoreErrors="--ignore-errors";;
			*)
				[[ "$1" == "--" ]] && { shift; break; }
				if ! IsOption "$1" && [[ ! $s ]]; then s="$1"
				elif ! IsOption "$1"; then functions+=("$1")
				else UnknownOption "$1"; return
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
ScriptFileCheck() { [[ -f "$1" ]] && return; [[ ! $quiet ]] && ScriptErr "file '$1' does not exist"; return 1; }
ScriptMessage() { EchoErr "$(ScriptPrefix "$2")$1"; } 																		# ScriptMessage MESSAGE - log a message with the script prefix
ScriptPrefix() { local name="$(ScriptName "$1")"; [[ ! $name ]] && return; printf "%s" "$name: "; }
ScriptReturnError() { [[ $suppressErrors ]] && echo 0 || echo 1; }
ScriptTry() { EchoErr "Try '$(ScriptName "$1") --help' for more information."; return 1; }
ScriptTryVerbose() { EchoErr "Use '--verbose' for more information."; return 1; }

# ScriptGlobalArgsSet - set the global arguments to pass to another script
ScriptGlobalArgsSet()
{	
	globalArgs=($force $noPrompt $quiet $test $verbose)
	globalArgsLess=($forceLess $noPrompt $quiet $test $verboseLess)
	globalArgsLessForce=($forceLess $noPrompt $quiet $test $verbose)
	globalArgsLessVerbose=($force $noPrompt $quiet $test $verboseLess)
}

# ScriptCd PROGRAM [ARG...] - run a script and change to the first directory returned
ScriptCd()
{
	[[ ! $@ ]] && { MissingOperand "program" "ScriptCd"; return; }
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
ScriptEval()
{
	local verbose verboseLevel verboseLess; ScriptOptVerbose "$1"; [[ $verbose ]] && shift

	export SCRIPT_EVAL="true"

	log4 "running '$*'" "ScriptEval"
	local result; result="$("$@")" || return

	LogScript "ScriptEval: evaluating" "$result"
	eval "$result"

	unset SCRIPT_EVAL 
}


# ScriptName [func] - return the function, or the name of root script
ScriptName()
{
	local name="${1:-$scriptName}"; [[ $name ]] && { printf "$name"; return; }
	name="$0"; IsZsh && name="$ZSH_SCRIPT"
	name="$(GetFileName "$name")"
	[[ "$name" == "function.sh" ]] && unset name
	printf "$name" 
}

# ScriptOptNoPrompt - find no prompt option.  Sets noPrompt.
ScriptOptNoPrompt()
{
	while (( $# > 0 )) && [[ "$1" != "--" ]]; do 
		case "$1" in
			-np|--no-prompt) noPrompt="--no-prompt";;
		esac
		shift; 
	done

	return 0
}

# ScriptOptForce - find force option.  Sets force, forceLevel, and forceLess.
ScriptOptForce()
{
	while (( $# > 0 )) && [[ "$1" != "--" ]]; do 
		case "$1" in
			-f|--force) force="-f"; forceLevel=1;;
			-ff) force="-ff"; forceLevel=2;;
			-fff) force="-fff"; forceLevel=3;;
			-ffff) force="-ffff"; forceLevel=4;;
			-fffff) force="-fffff"; forceLevel=5;;
		esac
		shift; 
	done

	unset forceLess; (( forceLevel > 1 )) && forceLess="-$(StringRepeat "f" "$(( forceLevel - 1 ))")"

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

	unset verboseLess; (( verboseLevel > 1 )) && verboseLess="-$(StringRepeat "v" "$(( verboseLevel - 1 ))")"

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

CertGetDates() { local c; for c in "$@"; do [[ ! $quiet ]] && echo "$c:"; SudoRead "$c" openssl x509 -in "$c" -text | grep "Not "; done; }
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
sudov() { sudoc "$@" -- sudo --validate; } 									 # update the cached credentials if needed
IsSudo() { sudo --validate --non-interactive >& /dev/null; } # return true if the sudo credentials are cached

# HasElevatedAccount - return true if the user has an elevated account that must be used for sudo
HasElevatedAccount() { IsInDomain "sandia" && [[ -d "$USERS/${USER}z" ]]; }

# CanSudo - return true if sudo is possible
#   --no-prompt|-np   only return true if sudo is possible without prompting
CanSudo()
{
	# can sudo sudo credentials are cached or if root
	{ IsSudo || IsRoot || [[ $sudoPasswordCache ]]; } && return

	# arguments
	local args=()
	local force forceLevel forceLess noPrompt quiet test verbose verboseLevel verboseLess # for globalArgs

	while (( $# != 0 )); do
		case "$1" in "") : ;;
			--force|-f|-ff|-fff) ScriptOptForce "$1";;
			--no-prompt|-np) noPrompt="--no-prompt";;
			--quiet|-q) quiet="--quiet";;
			--test|-t) test="--test";;
			--verbose|-v|-vv|-vvv|-vvvv|-vvvvv) ScriptOptVerbose "$1";;
			--) shift; args+=("$@"); break;;
			*) args+=("$1");;
		esac
		shift
	done

	# do not prompt no prompt if there is no stdin
	! IsStdIn && noPrompt="--no-prompt"

	# can sudo if we do not need to use an elevated account and can get the sudo password
	! HasElevatedAccount && sudoPasswordCache="$(SudoPassword)" && return

	# can sudo if we are allowed to prompt for the password
	[[ ! $noPrompt ]]
}

# sudoc COMMANDS - run COMMANDS using sudo and use the credential store to get the password if available
#   --no-prompt|-np   do not prompt or ask for a password
#   --preserve|-p   	preserve the existing path (less secure)
#   --stderr|-se   		prompt for a password using stderr
sudoc()
{
	# run the command - already root
	IsRoot && { env "$@"; return; } # use env to support commands with variable prefixes, i.e. sudoc VAR=12 ls

	# arguments
	local args=() preserve stderr
	local force forceLevel forceLess noPrompt quiet test verbose verboseLevel verboseLess # for globalArgs

	while (( $# != 0 )); do
		case "$1" in "") : ;;
			--preserve|-p) preserve="--preserve";;
			--stderr|-se) stderr="--stderr";;

			--force|-f|-ff|-fff) ScriptOptForce "$1";;
			--no-prompt|-np) noPrompt="--no-prompt";;
			--quiet|-q) quiet="--quiet";;
			--test|-t) test="--test";;
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

	# must prompt for elevated accounts
	HasElevatedAccount && [[ $noPrompt ]] && return 1

	# get password if possible
	local password; password="$(SudoPassword)" # ignore errors so we can prompt for password 
	[[ $verbose ]] && { [[ $password ]] && ScriptMessage "sudo pasword found" || ScriptMessage "sudo pasword not found"; }

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
	(( $? != 0 )) && { [[ ! $quiet ]] && ScriptErrEnd "unable to run command: '${args[*]}'" "sudoc"; return 1; }

	# run the command
	# - do not use -- to allow environment variables, i.e. sudoc TEST=1 ls
	"${command[@]}" --prompt="" "${args[@]}"
}

SudoPassword()
{
	# use the cache and clear it for security
	[[ $sudoPasswordCache ]] && { echo "$sudoPasswordCache"; unset sudoPasswordCache; return; }

	# determine which password to use based off auth method
	local passwordPath="secure" passwordName="default"
	if InPath opensc-tool && opensc-tool --list-readers | ${G}grep --quiet "Yes"; then passwordPath="ssh"
	elif IsDomainRestricted && echo "BOGUS" | { sudo --stdin --validate 2>&1; true; } | ${G}grep --quiet "^Enter PIN"; then passwordPath="ssh"
	fi
	[[ $verbose ]] && EchoErr "looking for password in the credential store: path='$passwordPath' name='$passwordName'"

	# get password if possible, ignore errors so we can prompt for it
	credential --quiet get $passwordPath $passwordName $verbose
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

# sudor [COMMAND|--dir|-d DIR] - sudo root, run commands or a shell as root with access to the users SSH Agent and credential manager
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

# SudoRun PROGRAM ARGS - run program using sudo if sudo is defined
SudoRun() { [[ ! $sudo ]] && return; sudo "$@"; }

#
# terminal
#

IsTty() { ${G}tty --silent;  }		# ??
IsTtyOk() {  { printf "" > "/dev/tty"; } >& "/dev/null"; } # 0 if /dev/tty is usable for reading input or sending output (useful when stdin or stdout is not available in a pipeline)
IsSshTty() { [[ $SSH_TTY ]]; }		# 0 if connected over SSH with a TTY
IsStdIn() { [[ -t 0 ]];  } 				# 0 if STDIN refers to a terminal, i.e. "echo | IsStdIn" is 1 (false)
IsStdOut() { [[ -t 1 ]];  } 			# 0 if STDOUT refers to a terminal, i.e. "IsStdOut | cat" is 1 (false)
IsStdErr() { [[ -t 2 ]];  } 			# 0 if STDERR refers to a terminal, i.e. "IsStdErr |& cat" is 1 (false)

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

	# development environment - check before cache
	IsVisualStudioCode && { echo "VisualStudioCodeHelper"; return; }

	# cache text editor
	local cache="get-text-editor"
	if [[ $isSshX ]]; then cache+="-sshx"
	elif [[ $ssh ]]; then cache+="-ssh"
	fi

	if ! e="$(UpdateGet "$cache")" || [[ ! $e ]]; then
		e="$(
			# initialize
			local sublimeProgram="$(sublime program --quiet)"

			# find native text editor
			if [[ ! $isSsh ]]; then
				[[ $sublimeProgram ]] && { echo "$sublimeProgram"; return 0; }
				IsPlatform win && InPath "$P/Notepad++/notepad++.exe" && { echo "$P/Notepad++/notepad++.exe"; return 0; }
				IsPlatform mac && { echo "/System/Applications/TextEdit.app"; return 0; }
				IsPlatform win && InPath notepad.exe && { echo "notepad.exe"; return 0; }
			fi

			# find X Windows text editor
			if ! IsPlatform mac && [[ $DISPLAY ]]; then
				IsPlatform win && sublimeProgram="$(sublime program --alternate --quiet)"
				[[ $sublimeProgram ]] && { echo "$sublimeProgram"; return 0; }
				InPath geany && { echo "geany"; return 0; }
				InPath gedit && { echo "gedit"; return 0; }
			fi

			# find console text editor
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
	! JsonIsValid "$json" && { [[ $verbose ]] && "json='$json'"; ScriptErrQuiet "the JSON is not valid"; return 1; }	

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
# update - state management in the file system
#

# update - manage update state in a temporary file location
UpdateDate() { UpdateInit "$1" && [[ -f "$updateFile" ]] && GetFileDateStamp "$updateFile"; } 	# UpdateDate FILE - return the last updated date
UpdateDone() { UpdateInit "$1" && ${G}touch "$updateFile"; }																		# UpdateDone FILE - update the last updated date
UpdateGet() { ! UpdateNeeded "$@" && UpdateGetForce "$updateFile"; }														# UpdateGet FILE - if an update is not needed, get the contents of the update file 
UpdateGetForce() { UpdateInit "$1" && [[ ! -f "$updateFile" ]] && return; cat "$updateFile"; }	# UpdateGetForce FILE - get the contents of the update file 
UpdateNeededEmpty() { UpdateNeeded "$@" || [[ ! $(UpdateGet "$updateFile") ]]; }								# UpdateNeededCheck FILE - return true if an update is needed or if the contents of the file is empty
UpdateRm() { UpdateInit "$1" && rm -f "$updateFile"; }																					# UpdateRm FILE - remove the update file
UpdateRmAll() { UpdateInitDir && DelDir --contents --hidden --files "$updateDir"; }							# UpdateRmAll - remove all update files
UpdateSet() { UpdateInit "$1" && printf "$2" > "$updateFile"; }																	# UpdateSet FILE TEXT - set the contents of the update file
UpdateSince() { ! UpdateNeeded "$@"; }																													# UpdateSince FILE [DATE_SECONDS](TODAY) - return true if the file was updated since the date, or today
UpdateRecent() { ! UpdateNeeded "$1" "$(( $(GetSeconds --no-ns) - ${2:-5} ))"; }								# UpdateRecent FILE [SECONDS](5) - return true if the file was updated in the last number of seconds

# UpdateInit [FILE] - initialize update system, sets updateDir, updateFile
UpdateInit() { UpdateInitDir && UpdateInitFile "$1"; }

# UpdateInitDir - initialize update directory, sets updateDir
UpdateInitDir()
{
	local baseDir="$DATA" suffix="update"
	local mainDir="$baseDir/$suffix"

	# set updateDir to writable filesystem and return if it exists
	[[ ! $updateDir ]] && { updateDir="$(GetWritableDir "$baseDir")/$suffix" || return; }
	[[ -d "$updateDir" ]] && return

	# create update directory
	{
		${G}mkdir --parents "$updateDir" &&
		{ ! InPath setfacl || setfacl --default --modify o::rw "$updateDir"; } &&
		sudoc chmod -R o+w "$updateDir"
	} || { ScriptErrQuiet "unable to create the update directory in '$updateDir'" "UpdateInitDir"; return; }

	# copy files from main update directory if needed
	[[ "$mainDir" != "$updateDir" ]] && { ${G}cp --preserve=timestamps "$mainDir/"* "$updateDir" || return; }

	return 0
}

# UpdateInitFile FILE - if specified initialize update file, sets updateFile
UpdateInitFile()
{
	[[ ! $1 ]] && { MissingOperand "file" "UpdateInitFile"; return; }
	HasFilePath "$1" && updateFile="$1" || updateFile="$updateDir/$1"
}

# UpdateNeeded FILE [DATE_SECONDS](TODAY) - return true if an update is needed based on the last file modification time.
# - SECONDS: if not specified, an update is needed if the file was not modified today.   If specified, update is needed 
#   if the file was not modified since the specified date in seconds
# - examples: UpdateNeeded 'update-os', UpdateNeeded 'update-os' "$(GetSeconds '-10 min')"
UpdateNeeded()
{
	local file="$1" dateSeconds="$2"

	# return if update needed
	{ [[ $force ]] || ! UpdateInit "$file" || [[ ! -f "$updateFile" ]]; } && return

	# check if the file was not modified in the specified number of seconds
	if [[ $dateSeconds ]]; then
		local fileModSeconds="$(GetFileModSeconds "$updateFile")"
		(( $(echo "$fileModSeconds <= $dateSeconds" | bc) )) # bc required for Bash since dateSeconds is a float

	# check if the file was not modified today
	else
		local dateStamp="$(GetDateStamp)" fileDateStamp="$(GetFileDateStamp "$updateFile")"
		[[ "$dateStamp" != "$fileDateStamp" ]]
	fi
	local result="$?"

	if (( result == 0 && verboseLevel >= 5 )); then
		if [[ $dateSeconds ]]; then
			ScriptErr "Update needed for '$file'.  fileModSeconds=$fileModSeconds dateSeconds=$dateSeconds"
		else
			ScriptErr "Update needed for '$file'.  fileDateStamp='$fileDateStamp' dateStamp='$dateStamp'"
		fi
	fi

	return "$result"
}

#
# virtual machine
#

IsChroot() { GetChrootName; [[ $CHROOT_NAME ]]; }
ChrootName() { GetChrootName; echo "$CHROOT_NAME"; }
ChrootPlatform() { ! IsChroot && return; [[ $(uname -r) =~ [Mm]icrosoft ]] && echo "win" || echo "linux"; }

IsContainer() { ! InPath systemd-detect-virt && return 1; [[ "$(systemd-detect-virt --container)" != @(none|wsl) ]]; }
IsDocker() { ! InPath systemd-detect-virt && return 1; [[ "$(systemd-detect-virt --container)" == "docker" ]]; }
IsVm() { [[ $(GetVmType) ]]; }
IsParallelsVm() { [[ "$(GetVmType)" == "parallels" ]]; }
IsProxmoxVm() { [[ "$(GetVmType)" == "proxmox" ]]; }
IsVmwareVm() { [[ "$(GetVmType)" == "vmware" ]]; }
IsHypervVm() { [[ "$(GetVmType)" == "hyperv" ]]; }
VmType() { echo "$(GetVmType)"; }

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
	local cache="vm-type"; UpdateGet "$cache" && return
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

	[[ $verbose ]] && { ScriptErr "type=$VM_TYPE"; }
	UpdateSet "$cache" "$result" && echo "$result"
}

IsPhysical()
{
	local cache="physical" r="false"
	! r="$(UpdateGet "$cache")" && ! IsChroot && ! IsContainer && ! IsVm && { r="true"; UpdateSet "$cache" "$r"; }
	[[ "$r" == "true" ]]
}

#
# window manager
#

HasWindowManager() { ! IsSsh || IsXServerRunning; } # assume if we are not in an SSH shell we are running under a Window manager
WinExists() { ! IsPlatform win && return 1; ! tasklist.exe /fi "WINDOWTITLE eq $1" | grep --quiet "No tasks are running"; }

InitializeXServer()
{
	local scriptName="InitializeXServer" force forceLevel forceLess; ScriptOptForce "$@"
	[[ ! $force && $X_SERVER_CHECKED ]] && return

	# return if X is not installed
	! InPath xauth && return

	# arguments
	local quiet 

	while (( $# != 0 )); do
		case "$1" in "") : ;;
			--force|-f|-ff|-fff) ScriptOptForce "$1";;
			--quiet|-q) quiet="--quiet";;
			*) $1; UnknownOption "$1"; return;;
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
					[[ ! $quiet ]] && ScriptErr "unable to initialize D-Bus: $result"
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

		[[ "$ip" == @(0.0.0.0) ]] && ip="127.0.0.1"
		IsAvailablePort "$ip" 6000 "$timeout" || return
	fi
	
	InPath xhost && { xhost >& /dev/null || return; }
	return 0
}

# LockScreen - lock the screen
LockScreen()
{
	if IsPlatform gnome; then gnome-screensaver-command -l
	elif IsPlatform mac; then open -a ScreenSaverEngine
	elif IsPlatform win; then rundll32.exe "user32.dll,LockWorkStation"
	fi
}

RestartWm()
{
	if IsPlatform win; then RestartExplorer
	elif IsPlatform mac; then RestartDock
	elif IsPlatform gnome; then start gnome-shell --replace
	fi
}

WinSetStateUsage()
{
	EchoWrap "\
Usage: WinSetState [OPTION](--activate) TITLE
	Set the state of the specified windows title or class.
	Title format can be WIN_TITLE|MAC_TITLE|LINUX_TITLE.

	-a, --activate 					make the window active
	-c, --close 						close the window gracefully

	-max, --maximize				maximize the window
	-min, --minimize				minimize the window

	-h, --hide							hide the window (Windows)
	-uh, --unhide						unhide the window (Windows)"
}

WinSetState()
{
	local scriptName="WinSetState" ahk wargs=( /res /act ) args=( -a ) title result

	# arguments
	while (( $# != 0 )); do
		case "$1" in "") : ;;
			-a|--activate) wargs=( front ) args=( -a );;
			-c|--close) wargs=( /res /act ) args=( -c ) ahk="close";;
			-max|--maximize) wargs=( maximized ) args=( -a );;
			-min|--minimize) wargs=( minimized ) ahk="minimize";;
			-H|--hide) wargs=( hidden );;
			-uh|--unhide) wargs=( show_default );;
			-h|--help) WinSetStateUsage; return 0;;
			*)
				if [[ ! $title ]]; then title="$1"
				else UnknownOption "$1"; return; fi
		esac
		shift
	done

	# get platform specific title
	local titles=(); StringToArray "$title" "|" titles; set -- "${titles[@]}"
	if [[ "$title" =~ \| ]]; then
		case "$PLATFORM_OS" in win) title="$1";; mac) title="$2";; linux) title="$3";; esac
		[[ ! $title ]] && return
	fi

	# Windows - see if the title matches a windows running in Windows
	if IsPlatform win; then
		AutoHotKey IsInstalled && [[ $ahk ]] && { AutoHotKey start "$ahk" "$title"; return; }
		InPath WindowMode.exe && { RunWin WindowMode.exe -title "$title" -mode "${wargs[@]}"; return; }
		return 0
	fi

	# X Windows - see if title matches a windows running on the X server
	if [[ $DISPLAY ]] && InPath wmctrl; then
		id="$(wmctrl -l -x | grep -i "$title" | head -1 | cut -d" " -f1)"

		if [[ $id ]]; then
			[[ $args ]] && { wmctrl -i "${args[@]}" "$id"; return; }
			return 0
		fi
	fi

	return 0
}

# platform specific functions
SourceIfExistsPlatform "$BIN/function." ".sh" || return

# source other scripts
SourcePlatformScripts "$@" || return

export FUNCTIONS="true"
