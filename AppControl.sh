# AppControl.sh - control another application

AppList() { ${G}find $BIN -maxdepth 1 -type f -not -name '.*' | grep -e '^isInstalledCommand()' | cut -d':' -f1 | sort; }
AppIsInstalled() { AppCommand isInstalled "$@"; }
AppInstallVerify() { AppIsInstalled "$1" && return; ScriptErrQuiet "application '$1' is not installed" "$1"; }
AppIsRunning() { AppCommand isRunning "$@"; }
AppStart() { AppCommand start "$@"; }

# AppCloseSave/AppStartRestore APP - close an application and restore it's previous state
AppCloseSave() { AppHasHelper "$@" && AppIsInstalled "$@" && AppIsRunning "$@" && { wasRunning="true"; AppClose "$@"; return; }; return 0; }
AppStartRestore() { [[ ! $wasRunning ]] && return 0; AppStart "$@"; }

# AppHasHelper APP - return true if the application has a helper script
AppHasHelper() { local app="$(AppHelper "$1")" && appCommandExists isInstalled "$app"; } 

# AppClose [--wait] app
AppClose()
{
	# arguments
	local wait; [[ "$(LowerCase "$1")" == @(--wait|-w) ]] && { shift; wait="--wait"; }
	local app="$1"

	# return if app does not have a helper, is not installed, or is not running
	! { AppHasHelper "$app" && AppIsInstalled "$@" && AppIsRunning "$app"; } && return

	# close the application
	AppCommand close "$@" || return
	[[ ! $wait ]] && return

	# wait for the app to close
	printf "Waiting for '$app' to close..."
	while AppIsRunning "$app"; do
		ReadChars 1 1 && { [[ ! $quiet ]] && echo "cancelled after $i seconds"; return 1; }
		printf "."
	done

	echo "done"
}

# AppCommand COMMAND APP - execute COMMAND on APP
AppCommand()
{
	local command="$1" app="$2" appOrig="$2"; shift 2; app="$(AppHelper "$app")" || return

	# check if the application has the command
	appCommandExists "$command" "$app" || { ScriptErrQuiet "application '$appOrig' does not have a '$command' command"; return 1; }

	# logging
	[[ "$command" == @(start|startup) ]] && PrintQuiet "Starting '$appOrig'..."
	[[ "$command" == @(close) ]] && PrintQuiet "Closing '$appOrig'..."

	# run the command
	local result; "$app" "$command" "$@"; result="$?"

	# logging
	[[ "$command" == @(close|start|startup) ]] && EchoQuiet "done"

	return "$result"
}

appCommandExists() { local command="$1" app="$2"; [[ -f "$app" ]] && ${G}grep --quiet "^${command}Command"'()' "$app"; }
