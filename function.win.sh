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

	local linkDir="$(utw "$(GetFilePath "$link")")"
	local linkName="$(GetFileName "$link")"

	start nircmd shortcut "$f" "$linkDir" "$linkName" "${@:3}";
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
		file "$file" | grep PE32 > /dev/null && return;
		echo $file | grep "WindowsApps" > /dev/null && return; # the file command does not work properly for Windows Apps (file "$LOCALAPPDATA/Microsoft/WindowsApps/wt.exe")
		return
	else
			return 0
	fi
}

# Windows process elevation (use Administrator token) 
elevate()
{
	# Launch a terminal elevated in the current directory
	if [[ "$#" == "0" ]]; then
		InPath wt.exe && { start --elevate wt.exe -d "$PWD"; return; }
		start --elevate wsl.exe; return;
	fi

	# Launch the specified program elevated
	start --elevate "$@"
}

IsElevated() # return true if the user has an Admministrator token
{ 
	# if the user is in the Administrators group they have the Windows Administrator token
	# cd / to fix WSL 2 error running from network share
	( cd /; whoami.exe /groups ) | grep 'BUILTIN\\Administrators' | grep "Enabled group" >& /dev/null; 
} 

return 0
