# AppControl.sh - control another application

AppClose() { AppCommand close "$@"; }
AppIsInstalled() { AppCommand isInstalled "$@"; }
AppInstallCheck() { AppIsInstalled "$1" && return; [[ ! $quiet ]] && ScriptErr "application is not installed" "$1"; return 1; }
AppIsRunning() { AppCommand isRunning "$@"; }
AppStart() { AppCommand start "$@"; }

# AppCloseSave/AppStartRestore APP - close an application and restore it's previous state
AppCloseSave() { AppIsInstalled "$@" && AppIsRunning "$@" && { wasRunning="true"; AppClose "$@"; return; }; return 0; }
AppStartRestore() { [[ ! $wasRunning ]] && return 0; AppStart "$@"; }

# AppHasHelper APP - return true if the application has a helper script
AppHasHelper() { local app="$(AppHelper "$1")" && appCommandExists isInstalled "$app"; } 

# AppCommand COMMAND APP - execute COMMAND on APP
AppCommand()
{
	local command="$1" app="$2" appOrig="$2"; shift 2; app="$(AppHelper "$app")" || return

	# check if the application has the command
	appCommandExists "$command" "$app" || { ScriptErrQuiet "application '$appOrig' does not have a '$command' command"; return 1; }

	# logging
	[[ "$command" == @(start|startup) ]] && ScriptEchoQuiet "Starting $app..."
	[[ "$command" == @(close) ]] && ScriptEchoQuiet "Closing $app..."

	# run the command
	"$app" "$command" "$@"
}

appCommandExists() { local command="$1" app="$2"; [[ -f "$app" ]] && ${G}grep --quiet "^${command}Command"'()' "$app"; }
