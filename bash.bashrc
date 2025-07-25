# $bin/bash.bashrc, system-wide login initialization for all users and public scripts, executed by /etc/bash.bashrc

set -a # export variables and functions to child processes

#
# functions
#

# GetPlatform [host](local) - get the platform for the specified host
# sets: busybox chroot platformOs platformIdMain platformIdLike platformIdDetail platformKernel machine wsl
# platformOs=linux|mac|win
# platformIdMain=dsm|pi|pixel|qts|rhel|rock|srm|ubuntu
# platformIdLike=debian|openwrt|qnap|synology|ubiquiti
# platformIdDetail=platform:el9 (RedHat)
# wsl=1|2 (Windows)
# machine=aarch64|armv7l|mips|x86_64
# test:  sf; time GetPlatform nas3 && echo "success: $platformOs-$platformIdMain-$platformIdLike"

function GetPlatform() 
{
	# arguments
	local host noCheck quiet trust verbose

	while (( $# != 0 )); do
		case "$1" in "") : ;;
			--quiet|-q) quiet="--quiet";;
			--trust|-T) trust="--trust";;
			--no-check|-nc) noCheck="--no-check";;			
			--verbose|-v|-vv|-vvv|-vvvv|-vvvvv) verbose="$1";;
			*) 
				if [[ ! $host ]]; then host="$1"
				else echo "GetPlatform: unknow option '$1'"; return 1;
				fi
		esac
		shift
	done

	# /etc/os-release sets ID, ID_LIKE - https://www.man7.org/linux/man-pages/man5/os-release.5.html
	unset ID ID_LIKE
	local cmd='
echo platformOs=$(uname);
echo kernel=\"$(uname -r)\";
echo machine=\"$(uname -m)\";
[[ -f /etc/os-release ]] && cat /etc/os-release;
[[ -f /etc/debian_chroot ]] && echo chroot=\"$(cat /etc/debian_chroot)\";
[[ -f /sbin/ubntconf || -f /usr/bin/ubntconf || -f /usr/bin/ubnt-ipcalc ]] && echo ID_LIKE=ubiquiti;
[[ -f /proc/syno_platform ]] && echo ID=dsm ID_LIKE=synology;
[[ -d /etc/casaos ]] && echo ID=casaos ID_LIKE=debian;
[[ -f /bin/busybox ]] && echo busybox=true;
[[ -f /usr/bin/systemd-detect-virt ]] && echo container=\"$(systemd-detect-virt --container)\";
exit 0;'

	local results
	if [[ $host ]]; then
		results="$(SshHelper connect "$host" $noCheck $quiet $trust $verbose -- "$cmd")" || return 1
	else
		results="$(eval $cmd)"
	fi

	# don't let all of the variables defined in results leak out of this function	
	unset busybox chroot platformOs platformIdMain platformIdLike platformIdDetail platformKernel wsl

	# evaluate results - set variables based on results
	# kernel (uname --r) - platformKernel=pi if Ubuntu=6.5.0-1015-raspi, Debian=6.6.28+rpt-rpi-2712

	results="$(
		eval $results

		platformKernel="linux"
		if [[ $kernel =~ .*-Microsoft$ ]]; then platformKernel="wsl1"
		elif [[ $kernel =~ .*-microsoft-standard-WSL2+$ ]]; then platformKernel="wsl2"
		elif [[ $kernel =~ .*-microsoft-standard-WSL2$ ]]; then platformKernel="wsl2" # macOS error using (|\\+)
		elif [[ $kernel =~ .*-microsoft-standard$ ]]; then platformKernel="wsl2"
		elif [[ $kernel =~ (.*-rock|-rk) ]]; then platformKernel="rock"
		elif [[ "$ID" == "raspbian" || $kernel =~ .*-([0-9]+-raspi|rpi-[0-9]+)$ ]]; then platformKernel="pi"
		fi

		case "$platformOs" in
			Darwin)	platformOs="mac";;
			Linux) platformOs="linux";;
			MinGw*) platformOs="win"; ID_LIKE=mingw;;
		esac

		case "$container" in
			""|none|wsl) container="";;
			*) container="true";;
		esac

		if [[ ! $chroot && ! $container ]]; then
			if [[ "$platformKernel" == "wsl1" ]]; then platformOs="win" wsl=1
			elif [[ "$platformKernel" == "wsl2" ]]; then platformOs="win" wsl=2
			elif [[ $ID_LIKE =~ .*openwrt ]]; then ID_LIKE="openwrt"			
			elif [[ $kernel =~ .*-qnap ]]; then ID_LIKE="qnap"
			elif [[ "$ID_LIKE" == "casaos" ]]; then ID="casaos" ID_LIKE="debian"
			elif [[ $ubiquiti ]]; then ID_LIKE=""
			fi
		fi

		[[ "$ID" == "raspbian" ]] && ID="pi"

		echo busybox=\""$busybox"\"
		echo chroot=\""$chroot"\"
		echo platformOs="$platformOs"
		echo platformIdMain="$ID"
		echo platformIdLike="$ID_LIKE"
		echo platformIdDetail="$PLATFORM_ID"
		echo platformKernel="$platformKernel"
		echo machine="$machine"
		echo wsl="$wsl"
	)"

	eval "$results"
	return 0
}

CheckPlatform() # ensure PLATFORM_OS, PLATFORM_ID_MAIN, and PLATFORM_ID_LIKE are set
{ 
	[[ "$PLATFORM_OS" && "$PLATFORM_ID_MAIN" && "$PLATFORM_ID_LIKE" ]] && return
	GetPlatform || return
	export CHROOT="$chroot" PLATFORM_OS="$platformOs" PLATFORM_ID_MAIN="$platformIdMain" PLATFORM_ID_LIKE="$platformIdLike" PLATFORM_ID_DETAIL="$platformIdDetail" PLATFORM_KERNEL="$platformKernel" MACHINE="$machine" WSL="$wsl"
	unset chroot platform platformIdMain platformIdLike platformIdDetail platformKernel wsl
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

#
# Platform
#

CheckPlatform || return

#
# Environment Variables
#

# P=apps, PUSER=user apps, SRV=server apps, BIN=programs, PBIN=platform programs, DATA=common data, ADATA=application data, ACONF=application configuration
# PUB=public documents, USERS=users home directory
P="/opt" PUSER="" SRV="/srv" BIN="" DATA="" ADATA="" ACONF="" PUB="" USERS="/home"

# USER=logged on user, SUDO_USER, HOME=home directory, DOC=user documents, UDATA=user data, UBIN=user programs
# UDATA=user data, UADATA=user application data, CODE=source code
USER="${USERNAME:-$USER}"
[[ ! $USER ]] && USER="$(whoami)"
[[ ! $USERNAME ]] && USERNAME="$USER"
[[ ! $HOME ]] && HOME="$HOME/$USER"
DOC="" UDATA="" UADATA="$HOME/.config" UBIN=""

DATA="/usr/local/data" ADATA="$DATA/appdata" ACONF="$DATA/appconfig" BIN="$DATA/bin" PBIN="$DATA/platform/$PLATFORM_OS"
DOC="$HOME/Documents" CODE="$HOME/code" UDATA="$HOME/data" UBIN="$UDATA/bin"
HOSTNAME="${HOSTNAME:-$(hostname -s)}"
G="" 		# G=GNU program prefix (i.e. gls)
EXE="" 	# executable program suffix, i.e. .exe
WIN_ROOT="/" WIN_HOME="$HOME"

# PLATFORM_OS environment variables
case "$PLATFORM_OS" in
	mac) USERS="/Users" P="/Applications" G="g" SRV="/opt" UADATA="$HOME/Library/Application Support" PUSER="$HOME/Applications"

		# Homebrew
		unset -v HOMEBREW_PREFIX HOMEBREW_CELLAR HOMEBREW_REPOSITORY
		if [[ -f "/opt/homebrew/bin/brew" ]]; then export HOMEBREW_PREFIX="/opt/homebrew" HOMEBREW_CELLAR="$HOMEBREW_PREFIX/Cellar" HOMEBREW_REPOSITORY="$HOMEBREW_PREFIX"	
		elif [[ -f "/usr/local/bin/brew" ]]; then export HOMEBREW_PREFIX="/usr/local" HOMEBREW_CELLAR="$HOMEBREW_PREFIX/Cellar" HOMEBREW_REPOSITORY="/usr/local/Homebrew"
		fi
		;;

	win) EXE=".exe"
		WIN_ROOT="/mnt/c" WINDIR="$WIN_ROOT/Windows"
		P="$WIN_ROOT/Program Files" P32="$P (x86)" PROGRAMDATA="$WIN_ROOT/ProgramData"

		# for performance and stability assume the Windows username is the same (calling cmd.exe here causes Docker hangs)		
		if [[ -d "$WIN_ROOT/Users/$USER" ]]; then	
			WIN_USER="$USER" WIN_HOME="$WIN_ROOT/Users/$USER"
			UADATA="$WIN_HOME/AppData/Local" PUSER="$UADATA/Programs"
		else
			WIN_USER="" WIN_HOME="" PUSER=""
		fi
		;;

esac

# platform dependant variables
PUB="${PUB:-$USERS/Shared}"

# PLATFORM_ID_LIKE environment variables
case "$PLATFORM_ID_LIKE" in 
	qnap) USERS="/share/home";;
esac

# temp directory
declare {TMPDIR,TMP,TEMP}="${TMPDIR:-$HOME/tmp}"
[[ ! -d "$TMP" ]] && ${G}mkdir "$TMP" >& /dev/null

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

case "$PLATFORM_OS" in 
	linux) PathAdd "/sbin";;
	mac) [[ $HOMEBREW_PREFIX ]] && PathAdd front "$HOMEBREW_PREFIX/bin" "$HOMEBREW_PREFIX/sbin";; # use Homebrew utilities before system utilities
	win) 
 		PATH="${PATH//'\/mnt\/c\/WINDOWS'*:/}" # remove paths with incorrect case
		PathAdd "$WINDIR" "$WINDIR/system32" "$WINDIR/System32/Wbem" "$WINDIR/System32/WindowsPowerShell/v1.0/" "$WINDIR/System32/OpenSSH/" "$UADATA/Microsoft/WindowsApps"
		PathAdd front "$DATA/platform/linux"
		;;
esac

case "$PLATFORM_ID_LIKE" in	
	debian) PathAdd front "/usr/local/games" "/sbin" "/usr/sbin" "/usr/local/sbin";;
	qnap|synology) PathAdd front "/opt/sbin" "/opt/bin"; PathAdd "/usr/local/sbin" "/usr/local/bin" "/share/CACHEDEV1_DATA/.qpkg/container-station/bin";;
esac

PathAdd front "$DATA/platform/agnostic" "$PBIN" "$BIN"
PathAdd "$UBIN"

#
# Interactive Initialization
#

export BASHRC="true"
[[ "$-" != *i* ]] && return

# functions
[[ ! $FUNCTIONS && -f "$BIN/function.sh" ]] && . "$BIN/function.sh"

# root user setup - for sudor
if [[ "$USER" == "root" ]]; then

	if IsPlatform mac; then

		# HOME is not updated
	 	export HOME=~root

	 	# the mac credential manager does not work as root
	 	export CREDENTIAL_MANAGER="remote"

	 	# root shell is sh which runs .profile
	 	[[ ! -f ~/.profile ]] && echo "[ $BASH ] && . \"$USERS/\$(ConfigGetCurrent "user")/.bashrc\"" >> "$HOME/.profile"

	else
		# link configuration users .inputrc
		[[ ! -f "$HOME/.inputrc" ]] && { MakeLink create "$USERS/$(ConfigGetCurrent "user")/.inputrc" "$HOME/.inputrc" || return; }

		# use aliases from the configuration user
		grep -q "ConfigGet " "$HOME/.bashrc" && sed -i '/ConfigGet /d' "$HOME/.bashrc" # cleanup
		! grep -q "ConfigGetCurrent" "$HOME/.bashrc" && echo ". \"$USERS/\$(ConfigGetCurrent "user")/.bashrc\"" >> "$HOME/.bashrc"

		# do not execute .bashrc for non-interactive shells (Raspberry Pi OS does not check this)
		! grep -q '\[ -z "$PS1" \]' "$HOME/.bashrc" && ${G}sed -i '1s/^/[ -z "$PS1" ] \&\& return\n/' "$HOME/.bashrc"
	fi
fi

# warning message for interactive shells if the configuration was not set properly, except for GitKraken terminal
if [[ $bashrcWarn && ! $GITKRAKEN_BINARY_PATH ]]; then
	echo "System configuration was not set in /etc/bash.bashrc" >&2
	unset bashrcWarn
fi
