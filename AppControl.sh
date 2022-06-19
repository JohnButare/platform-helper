# AppControl.sh - control another application

AppClose() { AppCommand close "$1"; }
AppCommandExists() { AppFunctionExists "${1}Command" "$2" ; } # AppCommandExists COMMAND APP - application supports command
AppExists() { FindInPath "$1" > /dev/null; }
AppFunctionExists() { grep -q "$1"'()' "$2"; } # AppFunctionExists FUNCTION FILE - function exists in file
AppIsInstalled() { AppCommand IsInstalled "$1"; }
AppInstallCheck() { AppIsInstalled "$app" && return; [[ ! $quiet ]] && ScriptErr "application is not installed" "$1"; return 1; }
AppIsRunning() { AppCommand IsRunning "$1"; }
AppStart() { AppCommand start "$1"; }
AppStartRestore() { [[ ! $wasRunning ]] && return 0; AppStart "$1"; }

AppCloseSave()
{
	! AppIsInstalled "$1" && return 0
	! AppIsRunning "$1" && return 0
	wasRunning="true"
	AppClose "$1"
}

AppCommand() # AppCommand COMMAND APP - execute COMMAND on APP if exists
{
	local command="$1" app="$2" appPath
	appPath="$(FindInPath "$app")" || return
	if AppCommandExists "$command" "$appPath"; then
		[[ "$command" == @(start|startup) ]] && echo "Starting $app..."
		[[ "$command" == @(close) ]] && echo "Closing $app..."
		"$app" "$command" || return
	fi
	return 0
}