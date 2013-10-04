# System-wide configuration for all users and public scripts, executed by /etc/bash.bashrc

set -a
LANG=en_US
[[ -d "/cygdrive/d/users" ]] && export USERS="/cygdrive/d/users" || export USERS="/cygdrive/c/users"
PUB="$USERS/Public" BIN="$PUB/Documents/data/bin" DOC="$HOME/Documents"
P32="/cygdrive/c/Program Files (x86)" P64="/cygdrive/c/Program Files" P="$P64"
CODE="/cygdrive/c/Projects"
set +a

#
# terminal
#

export LINES COLUMNS 	# make available for dialogs in executable scripts
kill -SIGWINCH $$			# ensure LINES and COLUMNS is set for a new Cygwin termnal before it is resized

#
# Windows Directory Setup 
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

if [[ "$PROGRAMDATA" == "" ]]; then
	export programdata="$ProgramData"
	export PROGRAMDATA=$(cygpath -u "$ProgramData" 2> /dev/null)
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