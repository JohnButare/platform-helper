# $bin/bash.bashrc, system-wide login initialization for all users and public scripts, 
# executed by /etc/bash.bashrc

set -a
case "$(uname)" in CYGWIN*) PLATFORM=win;; Darwin) PLATFORM=mac;; Linux) PLATFORM=linux;; esac
LANG=en_US
[[ -d "/cygdrive/d/users" ]] && export USERS="/cygdrive/d/users" || export USERS="/cygdrive/c/users"
PUB="$USERS/Public" DATA="$PUB/Documents/data" BIN="$DATA/bin" 
P32="/cygdrive/c/Program Files (x86)" P64="/cygdrive/c/Program Files" P="$P64"
CODE="/cygdrive/c/Projects"
DOC="$HOME/Documents" UDATA="$DOC/data" UBIN="$UDATA/bin"
set +a

#
# terminal
#

export LINES COLUMNS 	# make available for dialogs in executable scripts
kill -SIGWINCH $$			# ensure LINES and COLUMNS is set for a new Cygwin termnal before it is resized

#
# Directories
#

# Ensure correct format for Unix (TMP/TEMP) and Windows (tmp/temp) programs

if [[ "$TMP" != "/tmp"  ]]; then
	export tmp=$(cygpath -w "$TMP" 2> /dev/null)
	export temp=$(cygpath -w "$TEMP" 2> /dev/null)
	export TMP="/tmp"
	export TEMP="/tmp"
fi;

if [[ "$APPDATA" == *\\* ]]; then
	export appdata="$APPDATA"
	export APPDATA=$(cygpath -u "$appdata" 2> /dev/null)
fi

if [[ "$PROGRAMDATA" == "" || "$PROGRAMDATA" == *\\* ]]; then
	export programdata="c:\\ProgramData"
	export PROGRAMDATA="/cygdrive/c/ProgramData"
fi

if [[ "$WINDIR" == *\\* ]]; then
	export windir="$WINDIR"
	export WINDIR=$(cygpath -u "$windir" 2> /dev/null)
fi

#
# paths
#

# (Man)PathAdd <path> [front], front adds to front and drops duplicates in middle
PathAdd() {	if [[ "$2" == "front" ]]; then PATH=$1:${PATH//:$1:/:}; elif [[ ! $PATH =~ (^|:)$1(:|$) ]]; then PATH+=:$1; fi; }
ManPathAdd() { if [[ "$2" == "front" ]]; then MANPATH=$1:${MANPATH//:$1:/:}; elif [[ ! $MANPATH =~ (^|:)$1(:|$) ]]; then MANPATH+=:$1; fi; }

# ensure Cygwin utilities are used before Microsoft utilities
# /etc/profile adds them first, but profile does not when called by "ssh <host> <script>.sh
PathAdd "/usr/bin" "front"
PathAdd "/usr/local/bin" "front"

ManPathAdd "$PUB/documents/data/man"

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
