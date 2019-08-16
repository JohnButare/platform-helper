#
# Applications
#

mmc() { start cmd.exe /c mmc.exe "$@"; }

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

	if IsPlatform cygwin; then 
		utw "$file" | egrep -iv cygwin > /dev/null; return;
	elif IsPlatform win; then
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

if [[ "$PLATFORM_LIKE" == "cygwin" ]]; then
	sudo() 
	{
		local program="mintty" ext standard direct hold="error" arguments wait
		local cygstartOptions hstartOptions="/D="$(utw $PWD)"" powerShellOptions

		while IsOption "$1"; do

			if [[ "$1" == +(-s|--standard) ]]; then 
				standard="true"
				hstartOptions+=( /noelevate )

			elif [[ "$1" == +(-h|--hide) ]]; then
				hstartOptions+=( /noconsole )

			elif [[ "$1" == +(-t|--test) ]]; then
				hstartOptions+=( /test )

			elif [[ "$1" == +(-w|--wait) ]]; then 
				wait="true"
				cygstartOptions+=( --wait )
				hstartOptions+=( /wait )
				powerShellOptions+=( -Wait )
				hold="always"

			elif [[ "$1" == +(-d|--direct) ]]; then
				direct="--direct"

			else
				echot "\
	usage: sudo [-s|--standard] [command](mintty) [arguments]... - start a command as a super user
		[-s|--standard]  start the program non-elevated (hstart only)
		[-w|--wait]      wait for the command to finish"
				return 1
			fi

			shift
		done

		[[ ! $standard ]] && hstartOptions+=( /nouac )

		[[ $# > 0 ]] && { program="$1"; shift; }
		! type -P "$program" >& /dev/null && { EchoErr "start: $program: command not found"; return 1; }

		program="$(FindInPath "$program")" # IsShellScript requires full path
		arguments="$@"

		# determine if hstart is not needed to change contexts
		local elevated; IsElevated && elevated="true"
		
		if [[ (! $elevated && $standard) || ($elevated && ! $standard) ]]; then
			if IsShellScript "$program"; then
				"$program" "$@"
			else
				start $direct "${cygstartOptions[@]}" "$program" "$@"
			fi
			return
		fi

		# elevate with hstart if available and not waiting (hstart /wait flag only works for elevated starts)
		if InPath hstart && [[ ! $wait ]]; then
			if IsShellScript "$program"; then
				hstart.exe "${hstartOptions[@]}" """mintty.exe"" --hold $hold bash.exe -l ""$program"" $arguments";
			else
				program="$(utw "$program")"
				hstart.exe "${hstartOptions[@]}" """$program"" $arguments";
			fi

		# elevate with PowerShell
		else
			if IsShellScript "$program"; then
				powershell -Command "Start-Process $powerShellOptions -Verb RunAs -FilePath mintty.exe \"--hold $hold bash.exe -l \"\"$program\"\" $arguments\"";
			else
				program="$(utw "$program")"
				[[ $arguments ]] && arguments="-ArgumentList \"$@\""
				powershell -Command "Start-Process $powerShellOptions -Verb RunAs -FilePath \"$program\" $arguments";
			fi
		fi

	}
fi
