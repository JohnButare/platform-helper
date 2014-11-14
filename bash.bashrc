# $bin/bash.bashrc, system-wide login initialization for all users and public scripts, 
# executed by /etc/bash.bashrc

set -a # PLATFORM DATA BIN UDATA UBIN ROOT P P32 PUB USERS USER HOME DOC
LANG="en_US" G="" # GNU Core Utils
ROOT=""
USERS="/Users"
VOLUMES="/Volumes"
case "$(uname)" in 
	CYGWIN*) PLATFORM="win" ROOT="/cygdrive/c" USER="$USERNAME" P="$ROOT/Program Files" P32="$ROOT/Program Files (x86)" VOLUMES="/cygdrive"
		[[ -d "/cygdrive/d/users" ]] && USERS="/cygdrive/d/users" || USERS="$ROOT/users"; PUB="$USERS/Public";;
	Darwin)	PLATFORM="mac" P="/Applications" G="g" PUB="$USERS/Shared";;
	Linux) PLATFORM="linux" P="/opt";; 
esac
DATA="/usr/local/data" BIN="$DATA/bin" CODE="$ROOT/Projects" 
DOC="$HOME/Documents" UDATA="$DOC/data" UBIN="$UDATA/bin"
[[ ! $COMPUTERNAME ]] && COMPUTERNAME="$(hostname -s)"
set +a

#
# configuration
# 

shopt -s nocasematch

#
# terminal
#

export LINES COLUMNS 	# make available for dialogs in executable scripts
kill -SIGWINCH $$			# ensure LINES and COLUMNS is set for a new Cygwin termnal before it is resized

#
# Directories
#

# Ensure programs receive the correct paths.  Generally Unix programs uses upper case variables and Windows receives lower case variables

if [[ "$TMP" != "/tmp"  ]]; then
	export TMP="/tmp"
	export TEMP="/tmp"
fi;

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

#
# paths
#

# (Man)PathAdd <path> [front], front adds to front and drops duplicates in middle
PathAdd() {	[[ ! -d "$1" ]] && return; if [[ "$2" == "front" ]]; then PATH=$1:${PATH//:$1:/:}; elif [[ ! $PATH =~ (^|:)$1(:|$) ]]; then PATH+=:$1; fi; }
ManPathAdd() { [[ ! -d "$1" ]] && return; if [[ "$2" == "front" ]]; then MANPATH=$1:${MANPATH//:$1:/:}; elif [[ ! $MANPATH =~ (^|:)$1(:|$) ]]; then MANPATH+=:$1; fi; }

# use CygWin utilities before Microsoft utilities (/etc/profile adds them first, but profile does not when called by "ssh <host> <script>.sh
if [[ "$PLATFORM" == "win" ]]; then
	PathAdd "/usr/bin" front
	PathAdd "/usr/local/bin" front
fi

PathAdd "$UDATA/bin"
ManPathAdd "$DATA/man"
PathAdd ~/bin # Ruby gems
PathAdd "$P/nodejs"; PathAdd "$APPDATA/npm" # Node.js

# interactive initialization - remainder not needed in child processes or scripts
[[ "$-" != *i* ]] && return

# common functions
[[ ! $FUNCTIONS && -f "$BIN/function.sh" ]] && . "$BIN/function.sh"

#
# install
#

i() # --find --cd
{ 
	local find force select
	if [[ "$1" == "--help" ]]; then echot "\
usage: i [APP*|cd|force|info|select]
	Install applications
	-f, --force		check for a new installation location
  -s, --select	select the install location"
	return 0
	fi

	[[ "$1" == @(--force|-f) ]] && { force="true"; shift; }
	[[ "$1" == @(--select|-s) ]] && { select="--select"; shift; }
	[[ "$1" == @(select) ]] && { select="--select"; }
	[[ "$1" == @(force) ]] && { force="true"; }

	[[ $force || $select || ! $InstallDir ]] && 
		{ ScriptEval FindInstallFile --eval $select || return; }

	[[ "$1" == @(force|select) ]] && return 0
	
	if [[ $# == 0 || "$1" == @(cd) ]]; then
		cd "$InstallDir"
	elif [[ "$1" == @(info) ]]; then
		echo "The installation directory is $InstallDir"
	elif [[ ! $find ]]; then
		inst --hint "$InstallDir" "$@"
	fi
}
