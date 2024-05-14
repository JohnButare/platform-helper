# common functions for application scripts
. script.sh || exit

AppInstallCheck() { isInstalledCommand && return; [[ "${command[0]}" != "isInstalled" ]] && ScriptErrQuiet "application '$(ScriptName)' is not installed"; return 1; }

AppStart() { AppCommand start "$1"; }

AppGetBackupDir()
{
	local server; server="$(GetServer "file")" || return
	local dir unc; unc="//$(ConfigGetCurrent "BackupUser")@$server/public/backup" # //user@server/share/dirs:protocol

	if ! dir="$(unc mount "$unc" "${globalArgs[@]}")"; then # globalArgs not quoted in case it is not set
		EchoErr "AppGetBackupDir: unable to mount '$unc'"
		return 1
	fi

	[[ ! -d "$dir" ]] && { "${G}mkdir" --parents "$dir" || return; }

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
		sources+=("$1"); shift
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

# AppBackup FILE - prepare to backup to FILE, returns complete path to backup file
AppBackupFile()
{
	local file="$1"
	local dest; dest="$(AppGetBackupDir)/$file" || return
	[[ -f "$dest" ]] && { bak --move "$dest" >& /dev/stderr || return; }
	echo "$dest"
}
