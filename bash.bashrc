# $bin/bash.bashrc, system-wide login initialization for all users and public scripts, executed by /etc/bash.bashrc

#
# Variables
#
# PLATFORM=linux|mac|win
# PLATFORM_LIKE=cygwin|debian|openwrt|qnap|synology
# PLATFORM_ID=dsm|qts|srm|raspian|ubiquiti|ubuntu
#
# PLATFORM: P G VOLUMES USERS PUB DATA BIN PBIN CODE
# USER: USER SUDO_USER HOME DOC UDATA UBIN ADATA
# WINDOWS: WIN_ROOT WIN_USERS WIN_HOME

set -a

# LANG="en_US" - on Raspberry Pi settings this causes perl to start with errors, on Ubuntu this is set automatically

HOSTNAME="${HOSTNAME:-$(hostname -s)}" 

P="/opt" G="" VOLUMES="/mnt" USERS="/home" PUB="" DATA="" BIN="" DATAD="/" # DATAD (Data Drive)
USER="${USERNAME:-$USER}" DOC="" UDATA="" UBIN=""

# PLATFORM variables are not set until function.sh
case "$(uname)" in 
	Darwin)	PLATFORM="mac" USERS="/Users" P="/Applications" G="g" VOLUMES="/Volumes" ADATA="$HOME/Library/Application Support";;
	Linux) PLATFORM="linux" ADATA="$HOME/.config";;
	CYGWIN*) PLATFORM="win" PLATFORM_LIKE="cygwin";;
	MINGW*) PLATFORM="win"; PLATFORM_LIKE="mingw";;
esac

case "$(uname -r)" in 
	*-Microsoft) PLATFORM="win" DATAD="/mnt/c" WIN_ROOT="/mnt/c" WIN_USERS="$WIN_ROOT/Users" WIN_HOME="$WIN_USERS/$USER" P="$WIN_ROOT/Program Files" P32="$P (x86)" ADATA="$WIN_HOME/AppData/Roaming";;
	*-qnap) PLATFORM_LIKE="qnap" PUB="/share/Public" DATAD="/share/data";;
esac

[[ -f /proc/syno_platform ]] && { PLATFORM_LIKE="synology" PUB="/volume1/public"; }

PUB="${PUB:-$USERS/Shared}"
DATA="/usr/local/data" BIN="$DATA/bin" PBIN="$DATA/platform/$PLATFORM"
DOC="$HOME/Documents" CLOUD="$HOME/Dropbox" UDATA="$DOC/data" UBIN="$UDATA/bin"
CODE="$HOME/source"

set +a

[[ "$TMP" != "/tmp"  ]] && { export TMP="/tmp"; export TEMP="/tmp"; }

if [[ "$PLATFORM" == "win" ]]; then
	export APPDATA="$WIN_HOME/AppData/Roaming"
	export LOCALAPPDATA="$WIN_HOME/AppData/Local"
	export PROGRAMDATA="$WIN_ROOT/ProgramData"
	export WINDIR="$WIN_ROOT/Windows"

	# Unix programs uses upper case variables and Windows receives lower case variables (at least in Cygwin)
	[[ "$PLATFORM_LIKE" == "cygwin" ]] && wslpath() { cygpath "$@"; }
	utw() { [[ ! "$@" ]] && return; [[ "$PLATFORM" == "win" ]] && { wslpath -aw "$*"; return; } || echo "$@"; } # UnixToWin

	# APPDATA and LOCALAPPDATA are truncated when using sudoc, i.e. sudoc service start ssh
	[[ -d "$APPDATA" ]] && export appdata="$(utw "$APPDATA")";
	[[ -d "$LOCALAPPDATA" ]] && export localappdata="$(utw "$LOCALAPPDATA")";

	export programdata="$(utw "$PROGRAMDATA")"
	export windir="$(utw "$WINDIR")"
	export tmp="$localappdata\Temp"
	export temp="$localappdata\Temp"

	SetWinVars()
	{
		export APPDATA="$appdata" LOCALAPPDATA="$localappdata" PROGRAMDATA="$programdata"
		export WINDIR="$windir" TMP="$tmp" TEMP="$temp"
		unset appdata localappdata programdata windir tmp temp
	}

	[[ $WIN_VARS ]] && SetWinVars
fi

#
# configuration
# 

shopt -s nocasematch
export LINES COLUMNS 						# make available for dialogs in executable scripts
kill -SIGWINCH $$	>& /dev/null 	# ensure LINES and COLUMNS is set for a new termnal before it is resized

#
# paths
#

# (Man)PathAdd <path> [front], front adds to front and drops duplicates in middle
PathAdd() {	[[ ! -d "$1" ]] && return; if [[ "$2" == "front" ]]; then PATH=$1:${PATH//:$1:/:}; elif [[ ! $PATH =~ (^|:)$1(:|$) ]]; then PATH+=:$1; fi; }
ManPathAdd() { [[ ! -d "$1" ]] && return; if [[ "$2" == "front" ]]; then MANPATH=$1:${MANPATH//:$1:/:}; elif [[ ! $MANPATH =~ (^|:)$1(:|$) ]]; then MANPATH+=:$1; fi; }

case "$PLATFORM" in 
	"mac") PathAdd "/usr/local/bin" front;; # use brew utilities before system utilities
	"ubuntu") PathAdd "/usr/games";; # cowsay, lolcat, ... on Ubuntu 19.04+
	"win") PathAdd "/usr/bin" front # use CygWin utilities before system utilities (/etc/profile adds them first, but profile does not when called by "ssh <host> <script>.sh"
esac

case "$PLATFORM_LIKE" in
	"qnap") PathAdd "/usr/local/sbin"; PathAdd "/usr/local/bin";;
esac

PathAdd "$PBIN" front
PathAdd "$BIN" front
PathAdd "$UDATA/bin"
ManPathAdd "$DATA/man"

# interactive initialization - remainder not needed in child processes or scripts
[[ "$-" != *i* ]] && return
[[ ! $FUNCTIONS && -f "$BIN/function.sh" ]] && . "$BIN/function.sh"
IsPlatform wsl && PathAdd "$WIN_ROOT/Windows/system32"

#
# install
#

i() # --find --cd
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

	if [[ ! $noRun && ($force || $select || ! $InstallDir) ]]; then
		ScriptEval FindInstallFile --eval $select || return
		export INSTALL_DIR="$InstallDir"
	fi

	[[ "$1" == @(force|select) ]] && return 0
	
	if [[ $# == 0 || "$1" == @(cd) ]]; then
		cd "$InstallDir"
	elif [[ "$1" == @(dir) ]]; then
		echo "$InstallDir"
	elif [[ "$1" == @(info) ]]; then
		echo "The installation directory is $InstallDir"
	elif [[ ! $find ]]; then
		inst --hint "$InstallDir" $noRun "$@"
	fi
}
