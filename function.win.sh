#
# Applications
#

mmc() { start cmd.exe /c mmc.exe "$@"; }

#
# Windows Subsystem for Linux (WSL)
#
IsWsl2() { wsl.exe --help | iconv -f utf-16 -t UTF-8 | grep 'set-version' >& /dev/null; }
LxRunOffline() { "$P/LxRunOffline/LxRunOffline.exe" "$@"; }

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

	start NirCmd shortcut "$f" "$linkDir" "$linkName" "${@:3}";
}

#
# Process
#

elevate() { IsElevated && "$@" || start --elevate "$@"; }
ElevatePause() { elevate RunPauseError "$@"; } # elevate the passed program and pause if there is an error
ElevatePauseAlways() { elevate RunPause "$@"; } # elevate the passed program and always pause
IsConsoleProgram() { file "$(FindInPath "$1")" | grep "(console)" >& /dev/null; }
IsShellScript() { file "$(FindInPath "$1")" | grep "shell script" >& /dev/null; }
IsWindowsProgram() { file "$(FindInPath "$1")" | grep "(GUI)" >& /dev/null; }
IsElevated() { $WIN_ROOT/Windows/system32/whoami.exe /groups | grep 'BUILTIN\\Administrators' | grep "Enabled group" >& /dev/null; } # have the Windows Administrator token

# IsWindowsProgram: true if the file is a native windows program which requires windows paths for arguments (c:\...) instead of POSIX paths (/...)
IsWindowsProgram() 
{
	local file="$(FindInPath "$file")"

	if IsPlatform win; then
		file "$file" | grep PE32 > /dev/null; return;
	else
			return 0
	fi
}

#
# Window
#

WinActivate() { start cmdow "$1" /res /act; }
WinClose() { start cmdow "$1" /cls; }
WinMin() { start cmdow "$1" /min; }
WinList() { start cmdow /f; }

return 0
