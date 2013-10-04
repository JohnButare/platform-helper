#!/bin/bash
. app.sh

init()
{
	unset quiet
	localApps=(cpu7icon gridy hp SideBar SpeedFan ThinkPadFanControl ZoomIt ShairPort4W)
}

usage()
{
	echot "\
usage: app [startup|close|restart](startup) <apps>
	-q, --quiet 				minimal status messages"
	exit $1
}

args()
{
	command='startup'

	while [ "$1" != "" ]; do
		case $1 in
			-h|--help) usage 0;;
			-q|--quiet) quiet="-q";;
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
		MapApp
		[[ $quiet ]] && printf "."
		if IsFunction "${app,,}"; then
			${app,,}
		elif IsInArray "$app" localApps; then
			RunInternalApp
		else
			RunExternalApp
		fi
	done
	return "$?"
}

TaskStart()
{
	local program="$1"
	local title="$2"

	[[ ! -f "$program" ]] && program="$(FindInPath "$program")"
	[[ ! -f "$program" ]] && return

	if [[ "$command" == "startup" ]]; then
		IsTaskRunning "$program" && return
		ShowStatus
		task start --title "$title" "$program" "${@}"
	else
		IsTaskRunning "$program" || return
		ShowStatus
		task close --title "$title" "$program"
	fi
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
		cpu7icon|hp|ThinkPadFanControl) close="pskill";;
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
		$close "$(GetFilename "$program")"
	fi
}

RunExternalApp()
{
	! GetAppFile && return
	! IsAppInstalled && return

	if [[ "$command" == "startup" ]]; then
		IsAppRunning && return
	else
		! IsAppRunning && return
	fi;

	ShowStatus
	"$app" "${command}"
}

ShowStatus()
{
	[[ $quiet ]] && printf "$app..." || echo "$status $app..."
}

GetAppFile()
{
	appFile="$(FindInPath "$app")"
	[[ -z "$appFile" ]] && echo "App $app was not found"
	[[ $appFile ]]
}

IsAppInstalled()
{
	if ! CommandExists IsInstalled "$appFile"; then
		echo "App $app does not have an IsInstalled command"
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
		ProcExp|pe) app="ProcessExplorer";;
		tc) app="TrueCrypt";;
		keys) app="AutoHotKey";;
		PuttyAgent) app="pu";;
		wmc) app="WindowsMediaCenter";;
		wmp) app="WindowsMediaPlayer";;
		X|XWindows) app="Xming";;
	esac
}

anydvd() { IsTaskRunning "AnyDVDtray" || TaskStart "AnyDVD"; }
aspnetversionswitcher() { [[ "$command" == "startup" ]] && TaskStart "$P/ASPNETVersionSwitcher/ASPNETVersionSwitcher.exe"; }
clonedvd() { [[ "$command" == "startup" ]] && TaskStart "$P32/Elaborate Bytes/CloneDVD2/CloneDVD2.exe"; }
groove() { TaskStart "$P32/Microsoft Office/Office12/GROOVE.EXE" "" -background; }
intelactivemonitor() { TaskStart "$P32/Intel/Intel(R) Active Monitor/iActvMon.exe"; }
pinnaclegameprofiler() {	TaskStart "$P32/KALiNKOsoft/Pinnacle Game Profiler/pinnacle.exe"; }

explorer()
{
	if [[ "$command" == "startup" ]]; then
		IsTaskRunning explorer || start explorer
	else
		IsTaskRunning explorer && tc explorer.btm CloseSoft
	fi;
}

inteldesktopcontrolcenter() 
{ 
	program="$P32/Intel/Intel(R) Desktop Control Center/idcc.exe"
	{ [[ "$command" == "startup" && -f "$program" ]] && IsTaskRunning idcc; } && 
		start --directory="$(GetPath "$program")" "$program"
}

processexplorer()
{
	if [[ "$command" == "startup" ]]; then
		start "%PUB/documents/data/bin/win64/ProcExp.exe" "Process Explorer*" "/t /p:l"
	elif IsTaskRunning "procexp"; then
		SendKeys "Process Explorer.*" "!Fx"
	fi;
}

run "$@"