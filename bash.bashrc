# $bin/bash.bashrc, system-wide login initialization for all users and public scripts, executed by /etc/bash.bashrc
#. function.bashrc.sh

set -a # export variables and functions to child processes

#
# functions
#

# GetPlatform [host](local) - get the platform for the specified host, sets platform, platformLike, platformId, and wsl
# test:  sf; time GetPlatform nas? && echo "success: $platform-$platformLike-$platformId"
# PLATFORM=linux|mac|win
# PLATFORM_LIKE=cygwin|debian|openwrt|qnap|synology
# PLATFORM_ID=dsm|pixel|qts|raspian|rock|srm|ubiquiti|ubuntu
# WSL=1|2 (Windows)
function GetPlatform() 
{
	local results host="$1" cmd='echo platform=$(uname); echo kernel=\"$(uname -r)\"; [[ -f /etc/os-release ]] && cat /etc/os-release; [[ -f /var/sysinfo/model ]] && echo ubiquiti=true; [[ -f /proc/syno_platform ]] && echo synology=true && [[ -f /bin/busybox ]] && echo busybox=true'

	if [[ $host ]]; then
		#IsAvailable $host || { EchoErr "$host is not available"; return 1; } # adds .5s
		results="$(ssh ${host,,} "$cmd")" ; (( $? > 1 )) && return 1
	else
		results="$(eval $cmd)"
	fi

	results="$(
		eval $results
		case "$platform" in 
			CYGWIN*) platform="win"; ID_LIKE=cygwin;;
			Darwin)	platform="mac";;
			Linux) platform="linux";;
			MinGw*) platform="win"; ID_LIKE=mingw;;
		esac

		if [[ $kernel =~ .*-Microsoft$ ]]; then platform="win" wsl=1
		elif [[ $kernel =~ .*-microsoft-standard$ ]]; then platform="win" wsl=2
		elif [[ $ID_LIKE =~ openwrt ]]; then ID_LIKE="openwrt"
		elif [[ $kernel =~ .*-rock ]]; then ID="rock"
		elif [[ $kernel =~ .*-qnap ]]; then ID_LIKE="qnap"
		elif [[ $synology ]]; then ID_LIKE="synology" ID="dsm"; [[ $busybox ]] && ID="srm"
		elif [[ $ubiquiti ]]; then ID="ubiquiti"
		fi

		if [[ "$ID" == "debian" && ! $ID_LIKE ]]; then
			ID="none" ID_LIKE="debian"
			which raspi-config >& /dev/null && ID="pixel"
		fi

		echo platform="$platform"
		echo platformLike="$ID_LIKE"
		echo platformId="$ID"
		echo wsl="$wsl"
	)"

	eval $results
	return 0
}

CheckPlatform() # ensure PLATFORM, PLATFORM_LIKE, and PLATFORM_ID are set
{ 
	[[ "$PLATFORM" && "$PLATFORM_LIKE" && "$PLATFORM_ID" ]] && return
	GetPlatform || return
	export PLATFORM="$platform" PLATFORM_ID="$platformId" PLATFORM_LIKE="$platformLike" WSL="$wsl"
	unset platform platformId platformLike wsl
}

PathAdd() # PathAdd [front] DIR...
{
	local front; [[ "$1" == "front" ]] && front="true"

	for f in "$@"; do 
		[[ ! -d "$f" ]] && continue
		[[ $front ]] && { PATH="$f:${PATH//:$f:/:}"; continue; } # force to front
		[[ ! $PATH =~ (^|:)$f(:|$) ]] && PATH+=":$f" # add to back if not present
	done
}

ManPathAdd()
{ 
	local front; [[ "$1" == "front" ]] && front="true"

	for f in "$@"; do
		[[ ! -d "$f" ]] && continue
		[[ $front ]] && { MANPATH="$f:${MANPATH//:$f:/:}"; continue; }
		[[ ! $MANPATH =~ (^|:)$f(:|$) ]] && MANPATH+=":$f"
	done
}	

#
# Platform
#

CheckPlatform || return

#
# Environment Variables
#

# P=applications, BIN=programs, PBIN=platform programs, DATA=common data, DATAD=data drive (large data files), ADATA=application data
# PUB=public documents, USERS=users home directory, VOLUMES=mounted system volumes
P="/opt" BIN="" DATA="" DATAD="/" PUB="" USERS="/home" VOLUMES="/mnt" ADATA="$HOME/.config"

# USER=logged on user, SUDO_USER, HOME=home directory, DOC=user documents, UDATA=user data, UBIN=user programs
# UDATA=user data, CODE=source code
USER="${USERNAME:-$USER}" DOC="" UDATA="" UBIN=""

# G=GNU program prefix (i.e. gls)
G="" 

case "$PLATFORM" in 
	mac) USERS="/Users" P="/Applications" G="g" VOLUMES="/Volumes" ADATA="$HOME/Library/Application Support";;
	win) DATAD="/mnt/c" WIN_ROOT="/mnt/c" WIN_USERS="$WIN_ROOT/Users" WIN_HOME="$WIN_USERS/$USER" P="$WIN_ROOT/Program Files" P32="$P (x86)"
		WINDIR="$WIN_ROOT/Windows" PROGRAMDATA="$WIN_ROOT/ProgramData" ADATA="$WIN_HOME/AppData/Roaming" LOCALAPPDATA="$WIN_HOME/AppData/Local"
		APPDATA="$ADATA";;
esac

case "$PLATFORM_LIKE" in 	
	qnap) PUB="/share/Public" DATAD="/share/data";;
	synology) PUB="/volume1/public";;
esac

DATA="/usr/local/data" BIN="$DATA/bin" PBIN="$DATA/platform/$PLATFORM"
DOC="$HOME/Documents" CLOUD="$HOME/Dropbox" UDATA="$DOC/data" UBIN="$UDATA/bin"
CODE="$HOME/source"
HOSTNAME="${HOSTNAME:-$(hostname -s)}"
PUB="${PUB:-$USERS/Shared}"
declare {TMPDIR,TMP,TEMP}="${TMPDIR:-/tmp}"

set +a

#
# configuration
# 

export LINES COLUMNS 						# make available for dialogs in executable scripts
kill -SIGWINCH $$	>& /dev/null 	# ensure LINES and COLUMNS is set for a new termnal before it is resized

#
# paths
#

ManPathAdd "/usr/local/man" "$DATA/man"

case "$PLATFORM" in 
	mac) PathAdd front "/usr/local/bin";; # use brew utilities before system utilities
	ubuntu) PathAdd "/usr/games";; # cowsay, lolcat, ... on Ubuntu 19.04+
	win) PathAdd "$WINDIR" "$WINDIR/system32" "$WINDIR/System32/Wbem" "$WINDIR/System32/WindowsPowerShell/v1.0/" "$WINDIR/System32/OpenSSH/" "$LOCALAPPDATA/Microsoft/WindowsApps";;
esac

case "$PLATFORM_LIKE" in	
	debian) PathAdd front "/usr/local/games" "/sbin" "/usr/sbin" "/usr/local/sbin";;
	qnap|synology) PathAdd front "/opt/sbin" "/opt/bin"; PathAdd "/usr/local/sbin" "/usr/local/bin" "/share/CACHEDEV1_DATA/.qpkg/container-station/bin";;
esac

PathAdd front "$PBIN" "$BIN"
PathAdd "$UBIN"

#
# Interactive Initialization
#

[[ "$-" != *i* ]] && return

[[ ! $FUNCTIONS && -f "$BIN/function.sh" ]] && . "$BIN/function.sh"

# warning message for interactive shells if the configuration was not set properly
if [[ $BASHRC ]]; then
	echo "System configuration was not set in /etc/bash.bashrc" > /dev/stderr # SUDO_USER PS1
	unset BASHRC
fi
