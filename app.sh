# common functions for application scripts
. script.sh || exit

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

AppGetBackupDir()
{
	local server; server="$(network current server backup --service=smb)" || return
	local dir unc="//$(ConfigGet "fsUser")@$server/root$DATA/appdata/backup" # //user@server/share/dirs:protocol

	if ! dir="$(unc mount "$unc" ${globalArgs[@]})"; then # globalArgs not quoted in case not set
		EchoErr "AppGetBackupDir: unable to mount '$unc'"
		return 1
	fi

	[[ ! -d "$dir" ]] && { ${G}mkdir --parents "$dir" || return; }

	echo "$dir"
}

# AppBackup APP SRC... -- [ZIP_OPTION]...
AppBackup()
{
	# arguments
	local app="$1"; shift

	local src sources=()
	for src in "$@"; do
		[[ "$src" == "--" ]] && { shift; break; }
		sources+="$1"; shift
	done

	# initialize	 
	local dest; dest="$(AppGetBackupDir)/$app.zip" || return
	[[ -f "$dest" ]] && { bak --move "$dest" || return; }

	# backup
	hilight "Backing up $app..."

	# add each source directory to the zip file
	for src in "${sources[@]}"; do
		echo "Backing up $(FileToDesc "$src")..."

		# mount the directory if needed
		IsUncPath "$src" && { src="$(unc mount "$src")" || return; }		

		# backup
		local base="$(GetFilePath "$src")"; src="$(GetFileName "$src")"
		cd "$base" || return
		zip -r --symlinks "$dest" "$src" "$@" || return

	done

	echo "Backup completed to $(FileToDesc "$dest")"
}
