#!/usr/bin/env bash
. app.sh

init()
{
	unset brief
	localApps=(cpu7icon gridy hp SideBar SpeedFan ThinkPadFanControl ZoomIt ShairPort4W)
}

usage()
{
	echot "\
usage: app [startup|close|restart](startup) <apps>
	-b, --brief 				brief status messages"
	exit $1
}

args()
{
	unset -v brief
	command='startup'

	while [ "$1" != "" ]; do
		case $1 in
			-h|--help) usage 0;;
			-b|--brief) brief="--brief";;
			startup|close) command=$1;;
			*)
				args=( "${@:1}" )
				break;;
		esac
		shift
	done
	[[ "$command" == "startup" ]] && status="Starting" || status="Closing"
}

run()
{	
	init
	args "$@"
	
	for app in "${args[@]}"
	do
		MapApp || return
		[[ $brief ]] && printf "."
		if f="$(GetFunction "$app")"; then
			"$f"
		elif IsInArray "$app" localApps; then
			RunInternalApp
		else
			RunExternalApp
		fi
		(( $? != 0 )) && { EchoErr "app: unable to run $app"; return 1; }
	done
	
	return 0
}

RunInternalApp()
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
		IsTaskRunning "$program" && return
		ShowStatus
		start "$program" $args
	else
		IsTaskRunning "$program" || return
		ShowStatus
		$close "$(GetFileName "$program")"
	fi
}

RunExternalApp()
{
	GetAppFile || return 0
	IsAppInstalled || return 0

	if [[ "$command" == "startup" ]]; then
		IsAppRunning && return
	else
		! IsAppRunning && return
	fi;

	ShowStatus
	"$app" --brief "${command}" || return
	[[ ! $brief ]] && echo done
	return 0
}

RunService()
{ 
	! IsPlatform wsl && return

	local service="$1"
	
	! service exists "$1" && return

	if [[ "$command" != "startup" ]]; then
		printf "$service."
		service stop $service # >& /dev/null
		return
	fi

	if ! service running $service; then
		printf "$service."
		service start $service > /dev/null
		IsPlatform wsl2 && [[ "$service" == "ssh" ]] && { RunScript --elevate -- powershell.exe WslPortForward.ps1 > /dev/null; }
		return 0
	fi

	# For wsl2 running systemd the ssh service will already be running, so just forward the ssh ports
	if IsPlatform wsl2 && IsSystemd && [[ "$service" == "ssh" ]] && service running $service; then
		printf "$service ports."
		RunScript --elevate -- powershell.exe WslPortForward.ps1 > /dev/null
	fi

	return 0
}

TaskStart()
{
	local program="$1"
	local title="$2"
	local args=( "${@:2}" )
	
	[[ ! -f "$program" ]] && program="$(FindInPath "$program")"
	[[ ! -f "$program" ]] && return

	if [[ "$command" == "startup" ]]; then
		IsTaskRunning "$program" && return
		ShowStatus || return
		task start --brief --title "$title" "$program" "${args[@]}"
		[[ ! $brief ]] && echo done
	else
		IsTaskRunning "$program" || return
		ShowStatus || return
		task close --brief --title "$title" "$program" || return
		[[ ! $brief ]] && echo done
	fi

	return 0
}

ShowStatus()
{
	[[ $brief ]] && printf "$appDesc..." || printf "$status $appDesc..."
}

GetAppFile()
{
	appFile="$(FindInPath "$app")"
	[[ -f "$appFile" ]]
}

IsAppInstalled()
{
	if ! CommandExists IsInstalled "$appFile"; then
		echo "app: $app does not have an IsInstalled command"
		return 1
	fi

	"$appFile" IsInstalled
}

IsAppRunning()
{
	if ! CommandExists IsRunning "$appFile"; then
		echo "App $app does not have an IsRunning command"
		return 1
	fi

	"$appFile" IsRunning
}

MapApp()
{
	appDesc="$app"

	case "$app" in
		cctray) app="CruiseControlTray";;
		ProcExp|pe) app="ProcessExplorer";;
		tc) app="TrueCrypt";;
		keys) app="AutoHotKey";;
		PuttyAgent) app="pu";;
		terminator) app="TerminatorHelper";;
		wmc) app="WindowsMediaCenter";;
		wmp) app="WindowsMediaPlayer";;
		X|XWindows) app="xserver";;
	esac
}

AltTabTerminator() { IsTaskRunning "AltTabTer.exe" || TaskStart "$P/Alt-Tab Terminator/AltTabTer.exe" "" /startup; }
AspnetVersionSwitcher() { [[ "$command" == "startup" ]] && TaskStart "$P/ASPNETVersionSwitcher/ASPNETVersionSwitcher.exe"; }
chrony() { RunService "chrony"; }
cron() { RunService "cron"; }
cue() { CorsairUtilityEngine; }; CorsairUtilityEngine() { IsTaskRunning "iCUE.exe" || TaskStart "$P32\Corsair\CORSAIR iCUE Software\iCUE Launcher.exe" "" --autorun; }
dbus() { RunService "dbus"; }
discord() { IsTaskRunning Discord.exe || TaskStart "$ADATA/Discord/app-0.0.305/Discord.exe" --start-minimized; }
docker() { RunService "docker"; }
duet() { TaskStart "$P/Kairos/Duet Display/duet.exe"; }
Explorer() { [[ "$command" == "startup" ]] && ! IsTaskRunning explorer.exe && start explorer; }
GlassWire() { IsTaskRunning "GlassWire.exe" || TaskStart "$P32/GlassWire/glasswire.exe" "" -hide; }
Greenshot() { IsTaskRunning "Greenshot.exe" || TaskStart "$P/Greenshot/Greenshot.exe" "" ; }
incron() { RunService "incron"; }
IntelActiveMonitor() { TaskStart "$P32/Intel/Intel(R) Active Monitor/iActvMon.exe"; }
IntelRapidStorage() { IsTaskRunning "$P/Intel/Intel(R) Rapid Storage Technology/IAStorIcon.exe" || start "$P/Intel/Intel(R) Rapid Storage Technology/IAStorIcon.exe"; }
LogitechOptions() { [[ ! -f "$P/Logitech/LogiOptions/LogiOptions.exe" ]] && return; IsTaskRunning LogiOptions.exe || start "$P/Logitech/LogiOptions/LogiOptions.exe" "/noui"; }
PowerPanel() { local p="$P32/CyberPower PowerPanel Personal/PowerPanel Personal.exe"; [[ ! -f "$p" ]] && return; IsTaskRunning "$p" || start "$p"; }
SecurityHealthTray() { IsTaskRunning SecurityHealthSystray.exe || start "$WINDIR/system32/SecurityHealthSystray.exe"; } # does not work, RunProcess cannot find programs in $WINDIR/system32
sshd() { RunService "ssh"; }
SyncPlicity() { TaskStart "$P/Syncplicity/Syncplicity.exe"; }

OneDrive()
{
	IsTaskRunning OneDrive.exe && return

	local file="$P32/Microsoft OneDrive/OneDrive.exe"; [[ ! -f "$file" ]] && file="$ADATA/Microsoft/OneDrive/OneDrive.exe"
	start "$file" /background; 
}

IntelDesktopControlCenter() 
{ 
	program="$P32/Intel/Intel(R) Desktop Control Center/idcc.exe"
	{ [[ "$command" == "startup" && -f "$program" ]] && IsTaskRunning idcc; } && 
		start --directory="$(GetFilePath "$program")" "$program"
}

ProcessExplorer()
{
	if [[ "$command" == "startup" ]]; then
		TaskStart "$DATA/platform/win/ProcExp.exe" "Process Explorer*" /t /p:l
	elif IsTaskRunning "procexp"; then
		SendKeys "Process Explorer.*" "!Fx"
	fi;
}

run "$@"
