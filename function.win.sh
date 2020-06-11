#
# Applications
#

mmc() {	( cmd.exe /c mmc.exe "$@" & ) >& /dev/null; }

#
# File System
#

FileHideAndSystem() { for file in "${@}"; do attrib.exe +h +s "$(utw "$file")" || return; done; }

# MakeShortcut FILE LINK ARGUMENTS ICON_FILE ICON_RESOURCE_NUMBER [MAX|MIN] START_IN_FOLDER HOT_KEY
MakeShortcut() 
{ 
	local suppress; [[ "$1" == @(-s|--suppress) ]] && { suppress="true"; shift; }
	(( $# < 2 )) && { EchoErr "usage: MakeShortcut TARGET NAME ..."; return 1; }

	local f="$1" link="$2"

	[[ ! -e "$f" ]] && f="$(FindInPath "$1")"
	[[ ! -e "$f" && $suppress ]] && { return 1; }
	[[ ! -e "$f" ]] && { EchoErr "MakeShortcut: could not find file $1"; return 1; }

	local linkDir="$(utw "$(GetFilePath "$link")")"
	local linkName="$(GetFileName "$link")"

	start NirCmd shortcut "$f" "$linkDir" "$linkName" "${@:3}";
}

GetWinDriveLabel() { cmd.exe /c vol "$1": |& RemoveCarriageReturn | grep "Volume in" | cut -d" " -f7; }

GetWinDrives() 
{
	local drives=( $(fsutil.exe fsinfo drives | sed 's/:\\//g' | tr '[:upper:]' '[:lower:]' | RemoveCarriageReturn ) ) result=()
	echo "${drives[@]:1}"
}

GetWinRemovableDrives() 
{
	local drives

	for drive in "$(GetWinDrives)"; do
		fsutil.exe fsinfo driveType "${drive}:\\" |& grep "Removable Drive" >& /dev/null && drives+=( "$drive" )
	done

	echo "${drives[@]}"
}

MountWinDrive()
{
	local drive="$1"
	[[ "$drive" == "c" ]] && return 1
	[[ ! -d "/mnt/$drive" ]] && { sudo mkdir "/mnt/$drive" || return 1; }
	mount |& grep "$drive: on /mnt/$drive type drvfs" >& /dev/null && return 0
	sudo mount -t drvfs "$drive:" "/mnt/$drive" >& /dev/null
}

#
# Explorer
#

RestartExplorer() { ProcessKill explorer && start explorer; }

#
# Process
#

IsConsoleProgram() { file "$(FindInPath "$1")" | grep "(console)" >& /dev/null; }
IsShellScript() { file "$(FindInPath "$1")" | grep "shell script" >& /dev/null; }

# IsWindowsProgram: true if the file is a native windows program
IsWindowsProgram() 
{
	local file="$(FindInPath "$1")"

	if IsPlatform win; then
		file "$file" | grep PE32 > /dev/null; return;
	else
			return 0
	fi
}

# Windows process elevation (use Administrator token) 
elevate() { IsElevated && "$@" || start --elevate "$@"; }
IsElevated() { $WIN_ROOT/Windows/system32/whoami.exe /groups | grep 'BUILTIN\\Administrators' | grep "Enabled group" >& /dev/null; } # have the Windows Administrator token

RunScriptElevated() # run a scripts elevated that has quoted arguments, used in InstallAppFromZip SetVar
{
	local dir="$TMP/RunScriptElevated.$RANDOM"
	local script="$dir/script.sh" log="$dir/log.txt" scriptResult="$dir/result.txt"

	rm -fr "$dir"; mkdir "$dir" || return

	touch "$log" # ensure log file exists so inotifywait does not return when it is created

	echo "$@ |& tee $log; echo \${PIPESTATUS[0]} > $scriptResult" > "$script"
	elevate RunScript source "$script"

	if ! IsElevated; then
		inotifywait -e create --quiet --quiet "$dir/" # wait for result file
		[[ -f "$log" ]] && cat "$log"
	fi

	[[ -f "$scriptResult" ]] && scriptResult="$(cat "$scriptResult")"
	rm -fr "$dir"
	
	return "$scriptResult"
}


#
# Window
#

WinActivate() { start cmdow "$1" /res /act; }
WinClose() { start cmdow "$1" /cls; }
WinMin() { start cmdow "$1" /min; }
WinList() { start cmdow /f; }

return 0
