# AppControl.sh - control another application

AppClose() { AppCommand close "$1"; }
AppCommandExists() { AppFunctionExists "${1}Command" "$2" ; } # AppCommandExists COMMAND APP - application supports command
AppExists() { local app="$(AppHelper "$1")"; FindInPath "$app" > /dev/null && AppCommandExists isInstalled "$(FindInPath "$app")"; } # AppExists APP - return true if the application is a helper file
AppFunctionExists() { local app="$(AppHelper "$2")"; [[ -f "$app" ]] && ${G}grep --quiet "^$1"'()' "$app"; } # AppFunctionExists FUNCTION APP - return true if the function exists in the app
AppInstallCheck() { AppIsInstalled "$1" && return; [[ ! $quiet ]] && ScriptErr "application is not installed" "$1"; return 1; }
AppIsHelper() { [[ "$(GetFilePath "$(FindInPath "$1")")" == "$BIN" ]]; }
AppIsInstalled() { AppCommand isInstalled "$1"; }
AppIsRunning() { AppCommand isRunning "$1"; }
AppStart() { AppCommand start "$1"; }
AppStartRestore() { [[ ! $wasRunning ]] && return 0; AppStart "$1"; }

AppCloseSave()
{
	! AppIsInstalled "$1" && return 0
	! AppIsRunning "$1" && return 0
	wasRunning="true"
	AppClose "$1"
}

# AppCommand COMMAND APP - execute COMMAND on APP
AppCommand()
{
	local command="$1" app="$(AppHelper "$2")" appPath

	appPath="$(FindInPath "$app")" || return

	! AppCommandExists "$command" "$appPath" && return 1
	[[ "$command" == @(start|startup) ]] && echo "Starting $app..."
	[[ "$command" == @(close) ]] && echo "Closing $app..."
	"$app" "$command"
}

# AppHelper APP - return the helper application for the app
AppHelper()
{
	local app="$1"
	[[ "$app" == @(1Password) ]] && app="${app}Helper"
	echo "$app"
}
