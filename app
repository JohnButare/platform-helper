#!/usr/bin/env bash
. "${BASH_SOURCE[0]%/*}/function.sh" script AppControl || exit

usage()
{
	ScriptUsage "$1" "\
Usage: $(ScriptName) [OPTION]... [startup|close|restart](startup) [APP]...
Run applications.
	
	-b, --brief 				brief status messages"
}

init()
{
	defaultCommand="startup"
	localApps=(cpu7icon gridy hp SideBar SpeedFan ThinkPadFanControl ZoomIt ShairPort4W)
}

argStart() { unset -v brief; }

opt()
{
	case "$1" in
		-b|--brief) brief="true";;
		*) return 1;;
	esac
}

args() { apps=( "$@" ); shift="$#"; }
argEnd() { [[ "$command" == "startup" ]] && status="Starting" || status="Closing"; }
closeCommand() { run "close"; }
restartCommand() { run "restart"; }
startCommand() { run "start"; }
startupCommand() { run "startup"; }

#
# applications
#

AltTabTerminator() { IsProcessRunning "AltTabTer.exe" || taskStart "$P/Alt-Tab Terminator/AltTabTer.exe" "" /startup; }
AspnetVersionSwitcher() { [[ "$command" == "startup" ]] && taskStart "$P/ASPNETVersionSwitcher/ASPNETVersionSwitcher.exe"; }
chrony() { runService "chrony"; }
cron() { runService "cron"; }
cue() { CorsairUtilityEngine; }; CorsairUtilityEngine() { IsProcessRunning "iCUE.exe" || taskStart "$P32\Corsair\CORSAIR iCUE Software\iCUE Launcher.exe" "" --autorun; }
discord() { IsProcessRunning Discord.exe || taskStart "$UADATA/Discord/app-0.0.305/Discord.exe" --start-minimized; }
duet() { taskStart "$P/Kairos/Duet Display/duet.exe"; }
Explorer() { [[ "$command" == "startup" ]] && ! IsProcessRunning explorer.exe && start explorer; }
FixTime() { [[ ! $force ]] && ClockHelper check && return; printf "time."; ClockHelper fix $force $verbose; }
GlassWire() { IsProcessRunning "GlassWire.exe" || taskStart "$P32/GlassWire/glasswire.exe" "" -hide; }
Greenshot() { IsProcessRunning "Greenshot.exe" || taskStart "$P/Greenshot/Greenshot.exe" "" ; }
incron() { runService "incron"; }
IntelActiveMonitor() { taskStart "$P32/Intel/Intel(R) Active Monitor/iActvMon.exe"; }
IntelRapidStorage() { IsProcessRunning "$P/Intel/Intel(R) Rapid Storage Technology/IAStorIcon.exe" || start "$P/Intel/Intel(R) Rapid Storage Technology/IAStorIcon.exe"; }
NetworkUpdate() { NetworkCurrentUpdate --brief; }
PowerPanel() { local p="$P32/CyberPower PowerPanel Personal/PowerPanel Personal.exe"; [[ ! -f "$p" ]] && return; IsProcessRunning "$p" || start "$p"; }
SecurityHealthTray() { IsProcessRunning SecurityHealthSystray.exe || start "$WINDIR/system32/SecurityHealthSystray.exe"; } # does not work, RunProcess cannot find programs in $WINDIR/system32
sshd() { runService "ssh"; }
SyncPlicity() { taskStart "$P/Syncplicity/Syncplicity.exe"; }
UltraMon() { IsProcessRunning "UltraMon.exe" || taskStart "$P/UltraMon/UltraMon.exe" "" ; }

consul() { hashi service retry "consul" --host="localhost"; }
nomad() { hashi service retry "nomad" --host="localhost"; }
vault() { hashi service retry "vault" --host="localhost"; }

BgInfo()
{
	# return if needed
	local file="$UADATA/Microsoft/Windows/Themes/Custom.theme"
	{ ! InPath Bginfo64.exe || [[ ! "$file" ]]; } && return
	[[ ! $force ]] && grep '^Wallpaper=' "$file" | qgrep BGInfo && return

	# find configuration file
	local dir="$DATA/setup" file
	{ file="$dir/$HOSTNAME.bgi" && [[ -f "$file" ]]; } || \
	{ file="$dir/$(GetDomain).bgi" && [[ -f "$file" ]]; } || \
	file="$dir/default.bgi"
	[[ ! -f "$file" ]] && return
	
	# set background
	Bginfo64.exe "$(utw "$DATA/setup/default.bgi")" /timer:0
}

dbus()
{	
	! IsPlatform wsl && return

	DbusConf || return

	if [[ ! -d "$XDG_RUNTIME_DIR" ]]; then
		sudoc ${G}mkdir "$XDG_RUNTIME_DIR" || return
		sudo chmod 700 "$XDG_RUNTIME_DIR" || return
		sudo chown "$(${G}id -un):$(${G}id -gn)" "$XDG_RUNTIME_DIR" || return
	fi

	runService "dbus" || return
  
  if [[ ! -e "$XDG_RUNTIME_DIR/bus" ]]; then
  	[[ $brief ]] && printf "dbus-daemon..."
  	"/usr/bin/dbus-daemon" --session --address="$DBUS_SESSION_BUS_ADDRESS" --nofork --nopidfile --syslog-only &
  fi
}

IntelDesktopControlCenter() 
{ 
	program="$P32/Intel/Intel(R) Desktop Control Center/idcc.exe"
	{ [[ "$command" == "startup" && -f "$program" ]] && IsProcessRunning idcc; } && 
		start --directory="$(GetFilePath "$program")" "$program"
}

ports() 
{	
	{ ! IsPlatform wsl || ! CanElevate || wsl supports mirrored; } && return	
	[[ ! $force ]] && wsl port all --status && return
	showStatus
	local r; [[ $brief && ! $verbose ]] && r="RunSilent"; [[ $verbose ]] && EchoErr
	$r wsl port all --enable && showStatusDone "$?"
}

processExplorer()
{
	if [[ "$command" == "startup" ]]; then
		taskStart "$DATA/platform/win/ProcExp.exe" "Process Explorer*" /t /p:l
	elif IsProcessRunning "procexp"; then
		SendKeys "Process Explorer.*" "!Fx"
	fi;
}

#
# helper
#

run()
{	
	local command="$1" time errors=0
	TIMEFORMAT='%R seconds'

	for app in "${apps[@]}"
	do
		mapApp || return

		if (( verboseLevel == 1 )); then printf "$app "
		elif (( verboseLevel > 1 )); then echo; header "$app"; time="time"
		elif [[ $brief ]]; then printf "."
		fi

		if f="$(FindFunction "$app")"; then
			eval $time "$f"
		elif IsInArray "$app" localApps; then
			eval $time runInternalApp "$app"
		else
			eval $time runExternalApp "$app"
		fi

	done

	return $errors
}

runExternalApp()
{
	local app; app="$(findApp "$1")" || return 0

	! AppIsInstalled "$app" && return

	if [[ "$command" == @(start|startup) ]]; then
		AppIsRunning "$app" "${globalArgs[@]}" && return
	else
		! AppIsRunning "$app" "${globalArgs[@]}" && return
	fi;

	showStatus
	"$app" --quiet "${command}" "${globalArgs[@]}"
	showStatusDone "$?"
}

runInternalApp()
{
	local program="${1}.exe" close="ProcessClose" args=""

	case "$app" in
		hp) program="$P32/Hewlett-Packard/HP HotKey Support/QLBController.exe";;
		SideBar) program="$P/Windows Sidebar/sidebar.exe";;
		SpeedFan) program="$P32/SpeedFan/speedfan.exe";;
		ThinkPadFanControl) program="$P/TPFanControl/TPFanControl.exe"
	esac

	case "$app" in
		hp) args=/start;;
	esac

	case "$app" in
		cpu7icon|hp|ThinkPadFanControl) close="ProcessKill";;
	esac

	[[ ! -f "$program" ]] && program="$(FindInPath "$program")"
	[[ ! -f "$program" ]] && return

	if [[ "$command" == "startup" ]]; then
		IsProcessRunning "$program" && return
		showStatus
		start "$program" $args
	else
		IsProcessRunning "$program" || return
		showStatus
		$close "$(GetFileName "$program")"
	fi

	showStatusDone "$?"
}

runService()
{ 
	local service="$1"
	
	! IsSystemd && return # assume systemd, otherwise Chrony does not appear running in WSL
	! service exists "$1" --quiet "${globalArgs[@]}" && return

	if [[ "$command" != "startup" ]]; then
		! service running "$service" && return
		[[ ! $quiet ]] && printf "$service."
		service stop $service --quiet "${globalArgs[@]}"
		return
	fi

	service running $service && return
	[[ ! $quiet ]] && printf "$service."
	service start $service --quiet "${globalArgs[@]}"
}

findApp()
{
	local app="$1" appHelper
	if appHelper="$(AppHelper "$app")"; then app="$appHelper"
	elif AppIsInstalled "${app^}Helper"; then app="${app^}Helper"
	elif ! AppIsInstalled "$app" "${globalArgs[@]}"; then return 1
	fi
	echo "$app"
}

mapApp()
{
	appDesc="$app"

	case "$app" in
		cctray) app="CruiseControlTray";;
		ProcExp|pe) app="ProcessExplorer";;
		tc) app="TrueCrypt";;
		keys) app="AutoHotKey";;
		network) app="NetworkUpdate";;
		PuttyAgent) app="pu";;
		terminator) app="TerminatorHelper";;
		time) app="FixTime";;
		wmc) app="WindowsMediaCenter";;
		wmp) app="WindowsMediaPlayer";;
		X|XWindows) app="xserver";;
	esac
}

showStatus()
{
	[[ $quiet ]] && return
	[[ $brief ]] && printf "$appDesc" || printf "$status $appDesc"
}

showStatusDone()
{
	local status="$1"

	if (( status != 0 )); then
		if [[ ! $brief ]] || (( verboseLevel > 1)); then EchoErr "app: unable to run $app"
		else printf " (failed).."
		fi
		(( errors++ ))
	fi

	[[ ! $brief ]] && echo "...done"

	return "$status"
}

taskStart()
{
	local program="$1"
	local title="$2"
	local args=( "${@:2}" )
	
	[[ ! -f "$program" ]] && program="$(FindInPath "$program")"
	[[ ! -f "$program" ]] && return

	if [[ "$command" == "startup" ]]; then
		IsProcessRunning "$program" && return
		showStatus
		task start --brief --title "$title" "$program" "${args[@]}"
		showStatusDone "$?"
	else
		! IsProcessRunning "$program" && return
		showStatus
		task close --brief --title "$title" "$program"
		showStatusDone "$?"
	fi

	return 0
}

ScriptRun "$@"
