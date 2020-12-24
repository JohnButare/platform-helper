# common functions for application scripts
. script.sh
. bootstrap-config.sh

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

AppGetBackupDir() { echo "$(unc mount //$fileServer/root$DATA/appdata/backup)"; }

# AppBackup APP SRC...
AppBackup()
{
	local app="$1" dest src; shift
	 
	dest="$(AppGetBackupDir)/$app.zip" || return
	[[ -f "$dest" ]] && { rm "$dest" || return; }

	# backup using zip
	hilight "Backing up $app..."
	for src in "$@"; do
		IsUncPath "$src" && { src="$(unc mount "$src")" || return; }
		[[ -e "$src" ]] && { zip -r --symlinks "$dest" "$src" || return; }
	done
}
