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
	done
	return "$?"
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
	GetAppFile || return
	IsAppInstalled || return

	if [[ "$command" == "startup" ]]; then
		IsAppRunning && return
	else
		! IsAppRunning && return
	fi;

	ShowStatus
	"$app" --brief "${command}"
	[[ ! $brief ]] && echo done
}

TaskStart()
{
	local runInDir=""; [[ "$1" == "--run-in-dir" ]] && { runInDir="$1"; shift; }
	local program="$1"
	local title="$2"
	local args=( "${@:2}" )
	
	[[ ! -f "$program" ]] && program="$(FindInPath "$program")"
	[[ ! -f "$program" ]] && return

	if [[ "$command" == "startup" ]]; then
		IsTaskRunning "$program" && return
		ShowStatus || return
		task start $runInDir --brief --title "$title" "$program" "${args[@]}"
		[[ ! $brief ]] && echo done
	else
		IsTaskRunning "$program" || return
		ShowStatus || return
		task close --brief --title "$title" "$program" || return
		[[ ! $brief ]] && echo done
	fi
}

ShowStatus()
{
	[[ $brief ]] && printf "$app..." || printf "$status $app..."
}

GetAppFile()
{
	appFile="$(FindInPath "$app")"
	#[[ ! $appFile ]] && { echo "app: $app was not found"; return 1; }
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
	case "$app" in
		cctray) app="CruiseControlTray";;
		ProcExp|pe) app="ProcessExplorer";;
		tc) app="TrueCrypt";;
		keys) app="AutoHotKey";;
		PuttyAgent) app="pu";;
		wmc) app="WindowsMediaCenter";;
		wmp) app="WindowsMediaPlayer";;
		X|XWindows) app="Xming";;
	esac
}

AltTabTerminator() { IsTaskRunning "AltTabTer64" || TaskStart "$P/SAlt-Tab Terminator/AltTabTer64.exe" "" /startup; }
AquaSnap() { IsTaskRunning "AquaSnap.Daemon" && return; printf "AquaSnap..."; RunInDir --cmd --background "$P32/AquaSnap/AquaSnap.Daemon.exe"; }
AspnetVersionSwitcher() { [[ "$command" == "startup" ]] && TaskStart "$P/ASPNETVersionSwitcher/ASPNETVersionSwitcher.exe"; }
cue() { CorsairUtilityEngine; }; CorsairUtilityEngine() { IsTaskRunning "iCUE" || TaskStart "$P32\Corsair\CORSAIR iCUE Software\iCUE Launcher.exe" "" --autorun; }
Duet() { TaskStart "C:\Program Files\Kairos\Duet Display\duet.exe"; }
Explorer() { [[ "$command" == "startup" ]] && ! IsTaskRunning explorer && start explorer; }
GlassWire() { IsTaskRunning "GlassWire" || TaskStart "$P32/GlassWire/glasswire.exe" "" -hide; }
Greenshot() { IsTaskRunning "Greenshot" || TaskStart "$P/Greenshot/Greenshot.exe" "" ; }
IntelActiveMonitor() { TaskStart "$P32/Intel/Intel(R) Active Monitor/iActvMon.exe"; }
IntelRapidStorage() { IsTaskRunning "IAStorIcon" || RunInDir --background "$P/Intel/Intel(R) Rapid Storage Technology/IAStorIcon.exe"; }
SyncPlicity() { TaskStart "$P/Syncplicity/Syncplicity.exe"; }
TidyTabs() { IsTaskRunning "TidyTabs.Daemon" && return; printf "TidyTabs..."; RunInDir --cmd --background "$P32/TidyTabs/TidyTabs.Daemon.exe"; }

sshd()
{ 
	! IsPlatform wsl && return

	if [[ "$command" != "startup" ]]; then
		printf "sshd."
		service stop ssh # >& /dev/null
		return
	fi

	if ! service running ssh; then
		printf "sshd."
		service start ssh # >& /dev/null
		return
	fi

	return 0
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