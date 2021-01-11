# $bin/bash.bashrc, system-wide login initialization for all users and public scripts, executed by /etc/bash.bashrc

set -a # export variables and functions to child processes

#
# functions
#

# GetPlatform [host](local) - get the platform for the specified host, sets platform, platformLike, platformId, and wsl
# test:  sf; time GetPlatform nas? && echo "success: $platform-$platformLike-$platformId"
# PLATFORM=linux|mac|win
# PLATFORM_LIKE=debian|openwrt|qnap|synology
# PLATFORM_ID=dsm|pixel|qts|raspian|rock|srm|ubiquiti|ubuntu
# WSL=1|2 (Windows)

function GetPlatform() 
{
	local results host="$1" chroot ubiquiti synology busybox container cmd='
echo platform=$(uname);
echo kernel=\"$(uname -r)\";
[[ -f /etc/os-release ]] && cat /etc/os-release;
[[ -f "/etc/debian_chroot" ]] && echo chroot=\""$(cat "/etc/debian_chroot")"\";
[[ -f /usr/bin/ubntconf ]] && echo ubiquiti=true;
[[ -f /proc/syno_platform ]] && echo synology=true;
[[ -f /bin/busybox ]] && echo busybox=true;
[[ -f /usr/bin/systemd-detect-virt ]] && echo container=\"$(systemd-detect-virt --container)\";
exit 0;'

	if [[ $host ]]; then
		results="$(ssh $host "$cmd")" || return 1

	else
		results="$(eval $cmd)"
	fi

	# don't let all of the variables defined in results leak out of this function
	results="$(
		eval $results

		platformKernel="linux"
		if [[ $kernel =~ .*-Microsoft$ ]]; then platformKernel="wsl1"
		elif [[ $kernel =~ .*-microsoft-standard$ ]]; then platformKernel="wsl2"
		elif [[ $kernel =~ .*-microsoft-standard$ ]]; then platformKernel="wsl2"
		elif [[ "$ID" == "raspbian" || $kernel =~ .*-raspi$ ]]; then platformKernel="pi"
		fi

		case "$platform" in
			Darwin)	platform="mac";;
			Linux) platform="linux";;
			MinGw*) platform="win"; ID_LIKE=mingw;;
		esac

		case "$container" in
			""|none|wsl) container="";;
			*) container="true";;
		esac

		if [[ ! $chroot && ! $container ]]; then
			if [[ "$platformKernel" == "wsl1" ]]; then platform="win" wsl=1
			elif [[ "$platformKernel" == "wsl2" ]]; then platform="win" wsl=2
			elif [[ $ID_LIKE =~ openwrt ]]; then ID_LIKE="openwrt"
			elif [[ $kernel =~ .*-rock ]]; then ID="rock"
			elif [[ $kernel =~ .*-qnap ]]; then ID_LIKE="qnap"
			elif [[ $synology ]]; then ID_LIKE="synology" ID="dsm"; [[ $busybox ]] && ID="srm"
			elif [[ $ubiquiti ]]; then ID="ubiquiti"
			fi
		fi

		[[ "$ID" == "raspbian" ]] && ID="pi"

		if [[ "$ID" == "debian" && ! $ID_LIKE ]]; then
			ID="none" ID_LIKE="debian"
			which raspi-config >& /dev/null && ID="pixel"
		fi

		echo platform="$platform"
		echo platformLike="$ID_LIKE"
		echo platformId="$ID"
		echo platformKernel="$platformKernel"
		echo wsl="$wsl"
		echo chroot="\"$chroot\""
	)"

	eval $results
	return 0
}

CheckPlatform() # ensure PLATFORM, PLATFORM_LIKE, and PLATFORM_ID are set
{ 
	[[ "$PLATFORM" && "$PLATFORM_LIKE" && "$PLATFORM_ID" ]] && return
	GetPlatform || return
	export CHROOT="$chroot" PLATFORM="$platform" PLATFORM_ID="$platformId" PLATFORM_LIKE="$platformLike" PLATFORM_KERNEL="$platformKernel" WSL="$wsl"
	unset chroot platform platformId platformLike platformKernel wsl
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

# P=applications, BIN=programs, PBIN=platform programs, DATA=common data, ADATA=application data
# PUB=public documents, USERS=users home directory, VOLUMES=mounted system volumes
P="/opt" BIN="" DATA="" PUB="" USERS="/home" VOLUMES="/mnt" ADATA="$HOME/.config"

# USER=logged on user, SUDO_USER, HOME=home directory, DOC=user documents, UDATA=user data, UBIN=user programs
# UDATA=user data, CODE=source code
USER="${USERNAME:-$USER}" DOC="" UDATA="" UBIN=""

# G=GNU program prefix (i.e. gls)
G="" 

case "$PLATFORM" in 
	mac) USERS="/Users" P="/Applications" G="g" VOLUMES="/Volumes" ADATA="$HOME/Library/Application Support" BREW_DIR="/usr/local/bin" BREW_SBIN="/usr/local/sbin"
		[[ -d "/opt/homebrew/bin" ]] && { BREW_DIR="/opt/homebrew/bin" BREW_SBIN="/opt/homebrew/sbin"; };;
	win) WIN_ROOT="/mnt/c" WINDIR="$WIN_ROOT/Windows" P="$WIN_ROOT/Program Files" P32="$P (x86)" PROGRAMDATA="$WIN_ROOT/ProgramData" WIN_HOME="$WIN_ROOT/Users/$USER" ADATA="$WIN_HOME/AppData/Local";;
esac

DATA="/usr/local/data" BIN="$DATA/bin" PBIN="$DATA/platform/$PLATFORM"
DOC="$HOME/Documents" CLOUD="$HOME/Dropbox" UDATA="$DOC/data" UBIN="$UDATA/bin"
CODE="$HOME/code"
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
	mac)
		PathAdd fron "/opt/local/bin" "/opt/local/sbin" # Mac Ports
		PathAdd front "$BREW_DIR" "$BREW_SBIN";; # use brew utilities before system utilities
	win) 
 		PATH="${PATH//'\/mnt\/c\/WINDOWS'*:/}" # remove paths with incorrect case
		PathAdd "$WINDIR" "$WINDIR/system32" "$WINDIR/System32/Wbem" "$WINDIR/System32/WindowsPowerShell/v1.0/" "$WINDIR/System32/OpenSSH/" "$ADATA/Microsoft/WindowsApps"
		PathAdd front "$DATA/platform/linux"
		;;
esac

case "$PLATFORM_ID" in	
	ubuntu) PathAdd "/usr/games";; # cowsay, lolcat, ... on Ubuntu 19.04+
esac

case "$PLATFORM_LIKE" in	
	debian) PathAdd front "/usr/local/games" "/sbin" "/usr/sbin" "/usr/local/sbin";;
	qnap|synology) PathAdd front "/opt/sbin" "/opt/bin"; PathAdd "/usr/local/sbin" "/usr/local/bin" "/share/CACHEDEV1_DATA/.qpkg/container-station/bin";;
esac

PathAdd front "$DATA/platform/agnostic" "$PBIN" "$BIN"
PathAdd "$UBIN"

#
# Interactive Initialization
#

[[ "$-" != *i* ]] && return

[[ ! $FUNCTIONS && -f "$BIN/function.sh" ]] && . "$BIN/function.sh"

# warning message for interactive shells if the configuration was not set properly
if [[ $BASHRC ]]; then
	echo "System configuration was not set in /etc/bash.bashrc" >&2
	unset BASHRC
fi
