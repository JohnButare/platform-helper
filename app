#!/usr/bin/env bash
. app.sh

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
startupCommand() { run "startup"; }

#
# applications
#

AltTabTerminator() { IsProcessRunning "AltTabTer.exe" || taskStart "$P/Alt-Tab Terminator/AltTabTer.exe" "" /startup; }
AspnetVersionSwitcher() { [[ "$command" == "startup" ]] && taskStart "$P/ASPNETVersionSwitcher/ASPNETVersionSwitcher.exe"; }
chrony() { runService "chrony"; }
cron() { runService "cron"; }
cue() { CorsairUtilityEngine; }; CorsairUtilityEngine() { IsProcessRunning "iCUE.exe" || taskStart "$P32\Corsair\CORSAIR iCUE Software\iCUE Launcher.exe" "" --autorun; }
dbus() { runService "dbus"; }
discord() { IsProcessRunning Discord.exe || taskStart "$UADATA/Discord/app-0.0.305/Discord.exe" --start-minimized; }
docker() { runService "docker"; }
duet() { taskStart "$P/Kairos/Duet Display/duet.exe"; }
Explorer() { [[ "$command" == "startup" ]] && ! IsProcessRunning explorer.exe && start explorer; }
GlassWire() { IsProcessRunning "GlassWire.exe" || taskStart "$P32/GlassWire/glasswire.exe" "" -hide; }
Greenshot() { IsProcessRunning "Greenshot.exe" || taskStart "$P/Greenshot/Greenshot.exe" "" ; }
incron() { runService "incron"; }
IntelActiveMonitor() { taskStart "$P32/Intel/Intel(R) Active Monitor/iActvMon.exe"; }
IntelRapidStorage() { IsProcessRunning "$P/Intel/Intel(R) Rapid Storage Technology/IAStorIcon.exe" || start "$P/Intel/Intel(R) Rapid Storage Technology/IAStorIcon.exe"; }
NetworkUpdate() { network current update --brief $force; }
PowerPanel() { local p="$P32/CyberPower PowerPanel Personal/PowerPanel Personal.exe"; [[ ! -f "$p" ]] && return; IsProcessRunning "$p" || start "$p"; }
SecurityHealthTray() { IsProcessRunning SecurityHealthSystray.exe || start "$WINDIR/system32/SecurityHealthSystray.exe"; } # does not work, RunProcess cannot find programs in $WINDIR/system32
sshd() { runService "ssh"; }
SyncPlicity() { taskStart "$P/Syncplicity/Syncplicity.exe"; }

FixTime() 
{
	! InPath chronyc && return
	local skew="$(chronyc tracking | grep "^System time" | cut -d" " -f8)"
  (( $(echo "$skew < 10" | bc -l) )) && return
  printf "time." && sudoc chronyc makestep > /dev/null
}

IntelDesktopControlCenter() 
{ 
	program="$P32/Intel/Intel(R) Desktop Control Center/idcc.exe"
	{ [[ "$command" == "startup" && -f "$program" ]] && IsProcessRunning idcc; } && 
		start --directory="$(GetFilePath "$program")" "$program"
}

OneDrive()
{
	IsProcessRunning OneDrive.exe && return

	local file="$P32/Microsoft OneDrive/OneDrive.exe"; [[ ! -f "$file" ]] && file="$UADATA/Microsoft/OneDrive/OneDrive.exe"
	start "$file" /background; 
}

ports()
{
	# only need to open ports for Windows WSL
	! IsPlatform wsl && return

	# initialize
	SshAgentConf --quiet "${globalArgs[@]}" || return

	# check if SSH port 22 is being forwarded  
	# - in Windows the port may show as open even if the port is not being forwarded
	# - turn off host key checking to avoid prompting (we trust ourself)
	[[ ! $force ]] && ssh -o "ConnectTimeout=1" -o "UserKnownHostsFile=/dev/null" -o "StrictHostKeyChecking=no" "$(GetIpAddress)" -p 22 "true" >& /dev/null && return 

	showStatus
	local r; [[ $brief && ! $verbose ]] && r="RunSilent"; [[ $verbose ]] && EchoErr
	RunScript --elevate "${globalArgs[@]}" -- RunScript $r powershell.exe WslPortForward.ps1
	[[ ! $brief ]] && echo done
	return 0
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
	local command="$1"

	for app in "${apps[@]}"
	do
		mapApp || return
		[[ $verbose ]] && printf "$app.."
		[[ $brief ]] && printf "."

		if f="$(FindFunction "$app")"; then
			"$f"
		elif IsInArray "$app" localApps; then
			runInternalApp
		else
			runExternalApp
		fi
		(( $? != 0 )) && { EchoErr "app: unable to run $app"; return 1; }
	done
	
	return 0
}

runExternalApp()
{
	getAppFile || return 0
	isAppInstalled || return 0

	if [[ "$command" == "startup" ]]; then
		isAppRunning && return
	else
		! isAppRunning && return
	fi;

	showStatus
	"$app" --quiet "${command}" || return
	[[ ! $brief ]] && echo done
	return 0
}

runInternalApp()
{
	local program="${app}.exe" close="ProcessClose" args=""

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
}

runService()
{ 
	! IsPlatform wsl && return

	local service="$1"
	
	! service exists "$1" --quiet && return

	if [[ "$command" != "startup" ]]; then
		! service running "$service" && return
		printf "$service."
		service stop $service >& /dev/null
		return
	fi

	if ! service running $service; then
		printf "$service."
		service start $service > /dev/null
		return 0
	fi

	return 0
}

getAppFile()
{
	appFile="$(FindInPath "$app")"
	[[ -f "$appFile" ]]
}

isAppInstalled()
{
	if ! CommandExists isInstalled "$appFile"; then
		echo "\n"; ScriptErr "'$app' does not have an IsInstalled command"; return 1
	fi

	"$appFile" --quiet IsInstalled
}

isAppRunning()
{
	if ! CommandExists isRunning "$appFile"; then
		echo "\n"; ScriptErr "'$app' does not have an IsRunning command"; return 1
	fi

	"$appFile" --quiet IsRunning
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
	[[ $brief ]] && printf "$appDesc..." || printf "$status $appDesc..."
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
		showStatus || return
		task start --brief --title "$title" "$program" "${args[@]}"
		[[ ! $brief ]] && echo done
	else
		IsProcessRunning "$program" || return
		showStatus || return
		task close --brief --title "$title" "$program" || return
		[[ ! $brief ]] && echo done
	fi

	return 0
}

ScriptRun "$@"
