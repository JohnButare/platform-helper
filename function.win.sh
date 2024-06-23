#
# Applications
#

mmc() {	( cmd.exe /c mmc.exe "$@" & ) >& /dev/null; }

#
# File System
#

# MakeShortcut FILE LINK ARGUMENTS ICON_FILE ICON_RESOURCE_NUMBER [MAX|MIN] START_IN_FOLDER HOT_KEY
MakeShortcut() 
{ 
	local suppress; [[ "$1" == @(-s|--suppress) ]] && { suppress="true"; shift; }
	(( $# < 2 )) && { EchoErr "usage: MakeShortcut TARGET NAME ..."; return 1; }

	local f="$1" link="$2"

	[[ ! -e "$f" ]] && f="$(FindInPath "$1")"
	[[ ! -e "$f" && $suppress ]] && { return 1; }
	[[ ! -e "$f" ]] && { EchoErr "MakeShortcut: could not find file $1"; return 1; }

	if InPath create-shortcut.exe; then
		local args=()
		[[ $3 ]] && args+=(--arguments "$3")
		[[ $4 ]] && args+=(--icon-file "$(utw "$4")")
		args+=("$(utw "$f")" "$(utw "$link")")
		create-shortcut.exe "${args[@]}"
	elif Inpath nircmd.exe; then
		local linkDir="$(utw "$(GetFilePath "$link")")"
		local linkName="$(GetFileName "$link")"
		start nircmd.exe shortcut "$f" "$linkDir" "$linkName" "${@:3}"
	else
		return
	fi
}

#
# Explorer
#

RestartExplorer() { taskkill.exe /f /im explorer.exe  && start explorer.exe; }

#
# Network
#

GetWslGateway() { route -n | grep '^0.0.0.0' | awk '{ print $2; }'; } # GetWslGateway - default the gateway WSL is using

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
		file "$file" | grep PE32 > /dev/null && return;
		echo $file | grep "WindowsApps" > /dev/null && return; # assume WindowsApps are executable, the file command does not work properly for them (i.e. files in "$UADATA/Microsoft/WindowsApps")
		return
	else
			return 0
	fi
}

# Windows process elevation (use Administrator token) 
elevate()
{
	! CanElevate && { ScriptErr "unable to elevate" "elevate"; return 1; }

	# Launch a terminal elevated in the current directory
	if [[ "$#" == "0" ]]; then
		InPath wt.exe && { start --elevate wt.exe -d "$PWD"; return; }
		start --elevate wsl.exe; return;
	fi

	# Launch the specified program elevated
	start --elevate "$@"
}

#
# user
#

GetSid() { PsGetsid.exe -nobanner jjbutare | tail -2 | head | RemoveNewline | RemoveCarriageReturn; }

#
# done
#

return 0
