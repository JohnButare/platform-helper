# common functions for application scripts
. function.sh

FunctionExists() { grep -q "$1"'()' "$2"; } # FunctionExists FUNCTION FILE - function exists in file
CommandExists() { FunctionExists "${1}Command" "$2" ; } # CommandExists COMMAND APP - application supports command

AppExists() { FindInPath "$1" > /dev/null; }
AppIsInstalled() { AppCommand IsInstalled "$1"; }
AppStart() { AppCommand start "$1"; }
AppClose() { AppCommand close "$1"; }
AppIsRunning() { AppCommand IsRunning "$1"; }

AppCloseSave()
{
	! AppIsInstalled "$1" && return 0
	! AppIsRunning "$1" && return 0
	wasRunning="true"
	AppClose "$1"
}

AppStartRestore()
{
	[[ ! $wasRunning ]] && return 0
	AppStart "$1"
}

AppCommand() # AppCommand COMMAND APP - execute COMMAND on APP if exists
{
	local command="$1" app="$2" appPath
	appPath="$(FindInPath "$app")" || return
	if CommandExists "$command" "$appPath"; then
		[[ "$command" == @(start|startup) ]] && echo "Starting $app..."
		[[ "$command" == @(close) ]] && echo "Closing $app..."
		"$app" "$command" || return
	fi
	return 0
}
