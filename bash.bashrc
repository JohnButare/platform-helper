# $bin/bash.bashrc, system-wide login initialization for all users and public scripts, executed by /etc/bash.bashrc

# Variables
# PLATFORM: ROOT P P32 G VOLUMES USERS PUB DATA BIN CODE
# USER: USER SUDO_USER HOME DOC UDATA UBIN ADATA
set -a

# LANG="en_US" - on Raspberry Pi settings this causes perl to start with errors, on Ubuntu this is set automatically

HOSTNAME="${HOSTNAME:-$(hostname -s)}" 

ROOT="" P="/opt" G="" VOLUMES="/mnt" USERS="/home" ADATA="$HOME/Library/Application Support"

case "$(uname)" in 
	CYGWIN*) PLATFORM="win" ROOT="/cygdrive/c" USERS="$ROOT/Users" PUB="$USERS/Public" P="$ROOT/Program Files" P32="$P (x86)" VOLUMES="/cygdrive" USER="$USERNAME" ADATA="$HOME/AppData/Roaming";;
	Darwin)	PLATFORM="mac" USERS="/Users" P="/Applications" G="g" VOLUMES="/Volumes";;
	Linux) PLATFORM="linux";;
esac

PUB="${PUB:-$USERS/Shared}"
DATA="/usr/local/data" BIN="$DATA/bin" CODE="$ROOT/Projects" 
DOC="$HOME/Documents" CLOUD="$HOME/Dropbox" UDATA="$DOC/data" UBIN="$UDATA/bin"

set +a

if [[ "$TMP" != "/tmp"  ]]; then
	export TMP="/tmp"
	export TEMP="/tmp"
fi;

#
# configuration
# 

shopt -s nocasematch

#
# terminal
#

export LINES COLUMNS 							# make available for dialogs in executable scripts
kill -SIGWINCH $$	>& /dev/null		# ensure LINES and COLUMNS is set for a new Cygwin termnal before it is resized

#
# Windows 
#

# ensure programs receive the correct paths.  Unix programs uses upper case variables and Windows receives lower case variables

if [[ "$PLATFORM" == "WIN" ]]; then
	if [[ "$APPDATA" == *\\* ]]; then
		export appdata="$APPDATA"
		export APPDATA=$(cygpath -u "$appdata" 2> /dev/null)
	fi

	if [[ "$LOCALAPPDATA" == *\\* ]]; then
		export localappdata="$LOCALAPPDATA"
		export LOCALAPPDATA=$(cygpath -u "$localappdata" 2> /dev/null)
	fi

	if [[ "$PROGRAMDATA" == "" || "$PROGRAMDATA" == *\\* ]]; then
		export programdata="c:\\ProgramData"
		export PROGRAMDATA="/cygdrive/c/ProgramData"
	fi

	if [[ "$WINDIR" == *\\* ]]; then
		export windir="$WINDIR"
		export WINDIR=$(cygpath -u "$windir" 2> /dev/null)
	fi

	if [[ "$PLATFORM" == "WIN" && ! $tmp ]]; then
		export tmp="$localappdata\Temp"
		export temp="$localappdata\Temp"
	fi

	SetWinVars()
	{
		export APPDATA="$appdata" LOCALAPPDATA="$localappdata" PROGRAMDATA="$programdata"
		export WINDIR="$windir" TMP="$tmp" TEMP="$temp"
		unset appdata localappdata programdata windir tmp temp
	}

	[[ $WIN_VARS ]] && SetWinVars
fi

#
# paths
#

# (Man)PathAdd <path> [front], front adds to front and drops duplicates in middle
PathAdd() {	[[ ! -d "$1" ]] && return; if [[ "$2" == "front" ]]; then PATH=$1:${PATH//:$1:/:}; elif [[ ! $PATH =~ (^|:)$1(:|$) ]]; then PATH+=:$1; fi; }
ManPathAdd() { [[ ! -d "$1" ]] && return; if [[ "$2" == "front" ]]; then MANPATH=$1:${MANPATH//:$1:/:}; elif [[ ! $MANPATH =~ (^|:)$1(:|$) ]]; then MANPATH+=:$1; fi; }

case "$PLATFORM" in 
	"mac") PathAdd "/usr/local/bin" front;; # use brew utilities before system utilities
	"win") PathAdd "/usr/bin" front # use CygWin utilities before system utilities (/etc/profile adds them first, but profile does not when called by "ssh <host> <script>.sh"
esac

PathAdd "$DATA/platform/$PLATFORM" front
PathAdd "$BIN" front
PathAdd "$UDATA/bin"

ManPathAdd "$DATA/man"

# interactive initialization - remainder not needed in child processes or scripts
[[ "$-" != *i* ]] && return

# common functions
[[ ! $FUNCTIONS && -f "$BIN/function.sh" ]] && . "$BIN/function.sh"

#
# install
#

i() # --find --cd
{ 
	local find force noRun select
	if [[ "$1" == "--help" ]]; then echot "\
usage: i [APP*|cd|force|info|select]
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
	elif [[ "$1" == @(info) ]]; then
		echo "The installation directory is $InstallDir"
	elif [[ ! $find ]]; then
		inst --hint "$InstallDir" $noRun "$@"
	fi
}
