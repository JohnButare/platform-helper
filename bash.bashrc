# $bin/bash.bashrc, system-wide login initialization for all users and public scripts, executed by /etc/bash.bashrc

set -a # export variables and functions to child processes

#
# functions
#

# GetPlatform [host](local) - get the platform for the specified host, sets:
# platform=linux|mac|win
# platformLike=debian|mac|openwrt|qnap|synology|ubiquiti
# platformId=dsm|pi|pixel|qts|rock|srm|ubuntu
# wsl=1|2 (Windows)
# machine=aarch64|armv7l|mips|x86_64
# test:  sf; time GetPlatform nas3 && echo "success: $platform-$platformLike-$platformId"

function GetPlatform() 
{
	# arguments
	local host quiet trust verbose

	while (( $# != 0 )); do
		case "$1" in "") : ;;
			-q|--quiet) quiet="--quiet";;
			-T|--trust) trust="--trust";;
			-v|--verbose) verbose="--verbose";;
			*) 
				if [[ ! $host ]]; then host="$1"
				else echo "GetPlatform: unknow option '$1'"; return 1;
				fi
		esac
		shift
	done

	# /etc/os-release sets ID, ID_LIKE
	local cmd='
echo platform=$(uname);
echo kernel=\"$(uname -r)\";
echo machine=\"$(uname -m)\";
[[ -f /etc/os-release ]] && cat /etc/os-release;
[[ -f /etc/debian_chroot ]] && echo chroot=\"$(cat /etc/debian_chroot)\";
[[ -f /usr/bin/ubntconf || -f /usr/bin/ubnt-ipcalc ]] && echo ubiquiti=true;
[[ -f /proc/syno_platform ]] && echo synology=true;
[[ -f /bin/busybox ]] && echo busybox=true;
[[ -f /usr/bin/systemd-detect-virt ]] && echo container=\"$(systemd-detect-virt --container)\";
exit 0;'

	local results
	if [[ $host ]]; then
		results="$(SshHelper connect "$host" $quiet $trust $verbose  -- "$cmd")" || return 1
	else
		results="$(eval $cmd)"
	fi

	# don't let all of the variables defined in results leak out of this function	
	unset chroot platform platformLike platformId platformKernel wsl
	results="$(
		eval $results

		platformKernel="linux"
		if [[ $kernel =~ .*-Microsoft$ ]]; then platformKernel="wsl1"
		elif [[ $kernel =~ .*-microsoft-standard-WSL2$ ]]; then platformKernel="wsl2"
		elif [[ $kernel =~ .*-microsoft-standard$ ]]; then platformKernel="wsl2"
		elif [[ "$ID" == "raspbian" || $kernel =~ .*-raspi$ ]]; then platformKernel="pi"
		fi

		case "$platform" in
			Darwin)	platform="mac"  ID_LIKE="mac";;
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
			elif [[ $ID_LIKE =~ .*openwrt ]]; then ID_LIKE="openwrt"
			elif [[ $kernel =~ .*-rock ]]; then ID="rock"
			elif [[ $kernel =~ .*-qnap ]]; then ID_LIKE="qnap"
			elif [[ $synology ]]; then ID_LIKE="synology" ID="dsm"; [[ $busybox ]] && ID="srm"
			elif [[ $ubiquiti ]]; then ID_LIKE="ubiquiti"
			fi
		fi

		[[ "$ID" == "raspbian" ]] && ID="pi"

		if [[ "$ID" == "debian" && ! $ID_LIKE ]]; then
			ID="none" ID_LIKE="debian"
			which raspi-config >& /dev/null && ID="pixel"
		fi

		echo chroot=\""$chroot"\"
		echo platform="$platform"
		echo platformLike="$ID_LIKE"
		echo platformId="$ID"
		echo platformKernel="$platformKernel"
		echo machine="$machine"
		echo wsl="$wsl"
	)"

	eval "$results"
	return 0
}

CheckPlatform() # ensure PLATFORM, PLATFORM_LIKE, and PLATFORM_ID are set
{ 
	[[ "$PLATFORM" && "$PLATFORM_LIKE" && "$PLATFORM_ID" ]] && return
	GetPlatform || return
	export CHROOT="$chroot" PLATFORM="$platform" PLATFORM_ID="$platformId" PLATFORM_LIKE="$platformLike" PLATFORM_KERNEL="$platformKernel" MACHINE="$machine" WSL="$wsl"
	unset chroot platform platformId platformLike platformKernel wsl
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
}

#
# Platform
#

CheckPlatform || return

#
# Environment Variables
#

# P=apps, SRV=server apps, BIN=programs, PBIN=platform programs, DATA=common data, ADATA=application data, ACONFIG=application configuration
# PUB=public documents, USERS=users home directory, VOLUMES=mounted system volumes
P="/opt" SRV="/srv" BIN="" DATA="" ADATA="" ACONFIG="" PUB="" USERS="/home" VOLUMES="/mnt"

# USER=logged on user, SUDO_USER, HOME=home directory, DOC=user documents, UDATA=user data, UBIN=user programs
# UDATA=user data, UADATA=user application data, CODE=source code
USER="${USERNAME:-$USER}" DOC="" UDATA="" UADATA="$HOME/.config" UBIN=""

# G=GNU program prefix (i.e. gls)
G="" 

case "$PLATFORM" in 
	mac) USERS="/Users" P="/Applications" G="g" VOLUMES="/Volumes" UADATA="$HOME/Library/Application Support" 
		# Homebrew
		unset -v HOMEBREW_PREFIX HOMEBREW_CELLAR HOMEBREW_REPOSITORY
		if [[ -f "/usr/local/bin/brew" ]]; then export HOMEBREW_PREFIX="/usr/local" HOMEBREW_CELLAR="$HOMEBREW_PREFIX/Cellar" HOMEBREW_REPOSITORY="/usr/local/Homebrew"
		elif [[ -f "/opt/homebrew/bin/brew" ]]; then export HOMEBREW_PREFIX="/opt/homebrew" HOMEBREW_CELLAR="$HOMEBREW_PREFIX/Cellar" HOMEBREW_REPOSITORY="$HOMEBREW_PREFIX"	
		fi
		;;
	win)
		WIN_ROOT="/mnt/c" WINDIR="$WIN_ROOT/Windows"
		WIN_HOME="$WIN_ROOT/Users/$USER" 
		WIN_CODE="$WIN_HOME/code"
		WIN_DOC="$WIN_HOME/Documents"
		WIN_UDATA="$WIN_HOME/data"	
		P="$WIN_ROOT/Program Files" P32="$P (x86)" PROGRAMDATA="$WIN_ROOT/ProgramData" UADATA="$WIN_HOME/AppData/Local"
		;;
esac

case "$PLATFORM_LIKE" in 
	qnap) USERS="/share/home";;
esac

DATA="/usr/local/data" ADATA="$DATA/appdata" ACONFIG="$DATA/appconfig" BIN="$DATA/bin" PBIN="$DATA/platform/$PLATFORM" PUB="${PUB:-$USERS/Shared}"
DOC="$HOME/Documents" CLOUD="$HOME/Dropbox" CODE="$HOME/code" UDATA="$HOME/data" UBIN="$UDATA/bin"
HOSTNAME="${HOSTNAME:-$(hostname -s)}"
declare {TMPDIR,TMP,TEMP}="${TMPDIR:-$HOME/tmp}"
[[ ! -d "$TMP" ]] && mkdir "$TMP" >& /dev/null

set +a

#
# configuration
# 

if [[ "$COLUMNS" != "0" ]]; then
	export LINES COLUMNS 						# make available for dialogs in executable scripts
	kill -SIGWINCH $$	>& /dev/null 	# ensure LINES and COLUMNS is set for a new termnal before it is resized
fi

#
# paths
#

InfoPathAdd "/usr/local/share/info"
ManPathAdd "/usr/local/man" "/usr/local/share/man" "$DATA/man"

case "$PLATFORM" in 
	mac)
		PathAdd front "/opt/local/bin" "/opt/local/sbin" 	# Mac Ports
		PathAdd "/opt/X11/bin" 														# XQuartz

		# Homebrew
		if [[ $HOMEBREW_PREFIX ]]; then
			PathAdd front "$HOMEBREW_PREFIX/bin" "$HOMEBREW_PREFIX/sbin" # use Homebrew utilities before system utilities
			InfoPathAdd "$HOMEBREW_PREFIX/share/info"
			ManPathAdd "$HOMEBREW_PREFIX/share/man"
		fi
		;;
	win) 
 		PATH="${PATH//'\/mnt\/c\/WINDOWS'*:/}" # remove paths with incorrect case
		PathAdd "$WINDIR" "$WINDIR/system32" "$WINDIR/System32/Wbem" "$WINDIR/System32/WindowsPowerShell/v1.0/" "$WINDIR/System32/OpenSSH/" "$UADATA/Microsoft/WindowsApps"
		PathAdd front "$DATA/platform/linux"
		[[ -d "$UADATA/Programs/Microsoft VS Code/bin" ]] && PathAdd "$UADATA/Programs/Microsoft VS Code/bin"
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

# root user setup
if [[ "$USER" == "root" ]]; then

	# use this users aliases
	! grep -q "ConfigGet" "$HOME/.bashrc" && echo ". \"$USERS/\$(ConfigGet "user")/.bashrc\"" >> "$HOME/.bashrc"

	# do not execute .bashrc for non-interactive shells (Raspberry Pi OS does not check this)
	! grep -q '\[ -z "$PS1" \]' "$HOME/.bashrc" && sed -i '1s/^/[ -z "$PS1" ] \&\& return\n/' "$HOME/.bashrc"

fi

# warning message for interactive shells if the configuration was not set properly
if [[ $BASHRC ]]; then
	echo "System configuration was not set in /etc/bash.bashrc" >&2
	unset BASHRC
fi
