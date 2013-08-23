#!/bin/bash
. app.sh

usage()
{
	echot "\
usage: app [startup|close|restart](startup) <apps>"
	exit $1
}

init()
{
	localApps="cpu7icon gridy SpeedFan ThinkPadFanControl ZoomIt ShairPort4W"
}

ProcessExplorer()
{
	echo "ProcessExplorer $command"
}

run()
{
	init
	args "$@"
	for app in "${args[@]}"
	do
		MapApp
		if IsFunction "${app,,}"; then
			${app,,}
		elif IsInList "$localApps" "$app"; then
			RunInternalApp
		else
			RunExternalApp
		fi
	done
	return "$?"
}

RunInternalApp()
{
	local close="process -q"
	local program="${app}.exe"

	case "$app" in
		"cpu7icon") close="pskill";;
		"SpeedFan") program="$P32/SpeedFan/speedfan.exe";;
		"ThinkPadFanControl")
			program="$P/TPFanControl/TPFanControl.exe"
			set close=pskill;;
	esac

	[[ ! -f "$program" ]] && program="$(FindInPath "$program")"
	[[ ! -f "$program" ]] && return

	if [[ "$command" == "startup" ]]; then
		IsTaskRunning "$program" && return
		ShowStatus
		start "$program"
	else
		IsTaskRunning "$program" || return
		ShowStatus
		$close "$(GetFilename "$program")"
	fi
}

RunExternalApp()
{
	! GetAppFile && return
	! IsInstalled && return

	if [[ "$command" == "startup" ]]; then
		IsRunning && return
	else
		! IsRunning && return
	fi;

	ShowStatus
	"$app" "${command}"
}

ShowStatus()
{
	if [[ "$command" == "startup" ]]; then
		echo "Starting $app..."
	else
		echo "Closing $app..."
	fi;
}

GetAppFile()
{
	appFile="$(FindInPath "$app")"
	[[ -z "$appFile" ]] && echo "App $app was not found"
	[[ $appFile ]]
}

IsInstalled()
{
	if ! CommandExists "$appFile" IsInstalled; then
		echo "App $app does not have an IsInstalled command"
		return 1
	fi

	"$appFile" IsInstalled
}

IsRunning()
{
	if ! CommandExists "$appFile" IsRunning; then
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

args()
{
	command='startup'

	while [ "$1" != "" ]; do
		case $1 in
			-h|--help) usage 0;;
			startup|close) command=$1;;
			*)
				args=( "${@:1}" )
				break;;
		esac
		shift
	done
}

TaskStart()
{
	echo "starting $1"
}

anydvd() { IsTaskRunning "AnyDVDtray" || TaskStart "AnyDVD"; }
aspnetversionswitcher() { [[ "$command" == "startup" ]] && TaskStart "$P/ASPNETVersionSwitcher/ASPNETVersionSwitcher.exe"; }
clonedvd() { [[ "$command" == "startup" ]] && TaskStart "$P32/Elaborate Bytes/CloneDVD2/CloneDVD2.exe"; }
groove() { TaskStart "$P32/Microsoft Office/Office12/GROOVE.EXE" "" -background; }
intelactivemonitor() { TaskStart "$P32/Intel/Intel(R) Active Monitor/iActvMon.exe"; }
pinnaclegameprofiler() {	TaskStart "$P32/KALiNKOsoft/Pinnacle Game Profiler/pinnacle.exe"; }

inteldesktopcontrolcenter() 
{ 
	program="$P32/Intel/Intel(R) Desktop Control Center/idcc.exe"
	{ [[ "$command" == "startup" && -f "$program" ]] && IsTaskRunning idcc; } && 
		cygstart --directory "$(GetPath "$dir")" "$(utw "$program")"
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