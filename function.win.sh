#
# Applications
#

mmc() { start cmd.exe /c mmc.exe "$@"; }

#
# File System
#

# MakeShortcut FILE LINK
MakeShortcut() 
{ 
	local suppress; [[ "$1" == @(-s|--suppress) ]] && { suppress="true"; shift; }
	(( $# < 2 )) && { EchoErr "usage: MakeShortcut TARGET NAME ..."; return 1; }

	local t="$1"; [[ ! -e "$t" ]] && t="$(FindInPath "$1")"
	[[ ! -e "$t" && $suppress ]] && { return 1; }
	[[ ! -e "$t" ]] && { EchoErr "MakeShortcut: could not find target $1"; return 1; }

	local linkDir="$(utw "$(GetFilePath "$2")")"
	local linkName="$(GetFileName "$2")"

	RunInDir NirCmd.exe shortcut "$(utw "$t")" "$linkDir" "$linkName" "${@:3}";
}

#
# Process
#

elevate() { IsElevated && "$@" || RunInDir hstart64.exe /NOUAC /WAIT "wsl.exe $*"; } # asyncronous even with /WAIT and return result is not correct
ElevateNoConsole() { IsElevated && "$@" || RunInDir hstart64.exe /NOCONSOLE /NOUAC /WAIT "wsl.exe $*"; }
ElevatePause() { elevate RunPause "$*"; } # elevate the passed program and pause if there is an error
IsElevated() { $WIN_ROOT/Windows/system32/whoami.exe /groups | grep 'BUILTIN\\Administrators' | grep "Enabled group" >& /dev/null; } # have the Windows Administrator token

# RunInDir FILE - run a windows program that must be started 
# Useful for programs that cannot be directly started from wsl even if they are in the path
RunInDir()
{
	local cmd; [[ "$1" == "--cmd" ]] && { cmd="cmd.exe /c"; shift; }
	local background; [[ "$1" == "--background" ]] && { background="true"; shift; }
	local file="$1" path result

	[[ ! $file ]] && { EchoErr "usage: RunInDir FILE"; return 1; }
	[[ ! -f "$file" ]] && file="$(FindInPath "$file")"
	[[ ! -f "$file" ]] && { EchoErr "Unable to find $file"; return 1; }

	path="$(GetFilePath "$(GetFullPath "$file")")"
	file="$(GetFileName "$file")"
	[[ ! $cmd ]] && file="./$file"

	pushd "$path" >& /dev/null
	if [[ $background ]]; then
		(nohup $cmd "$file" "${@:2}" >& /dev/null &)
	else
		$cmd "$file" "${@:2}"
	fi
	result=$?
	popd >& /dev/null; 

	return $result
}

# Window - Win [class] <title|class>, Au3Info.exe to get class

AutoItScript() 
{
	local script="${1/\.au3/}.au3"
	[[ ! -f "$script" ]] && script="$(FindInPath "$script")"
	[[ ! "$script" ]] && { echo "Could not find AutoIt script $1"; return 1; }
	RunInDir AutoIt.exe /ErrorStdOut "$(utw "$script")" "${@:2}"
}

WinActivate() { AutoItScript WinActivate "${@}"; }
WinClose() { AutoItScript WinClose "${@}"; }
WinList() { join -a 2 -e EMPTY -j 1 -t',' -o '2.1,1.2,2.2,2.3' <(ProcessListWin | sort -t, -k1) <(AutoItScript WinList | sort -t, -k1); } # causes error in Synology DSM
WinGetState() {	AutoItScript WinGetState "${@}"; }
WinGetTitle() {	AutoItScript WinGetTitle "${@}"; }
WinSetState() { AutoItScript WinSetState "${@}"; }

WinExists() { WinGetState "${@}"; (( $? & 1 )); }
WinVisible() { WinGetState "${@}"; (( $? & 2 )); }
WinEnabled() { WinGetState "${@}"; (( $? & 4 )); }
WinActive() { WinGetState "${@}"; (( $? & 8 )); }
WinMinimized() { WinGetState "${@}"; (( $? & 16 )); }
WinMaximized() { WinGetState "${@}"; (( $? & 32)); }


# sudo [command](mintty) - start a program as super user under cygwin
# sudo /cygdrive/c/Program\ Files/Sublime\ Text\ 3/sublime_text.exe
# sudo cmd "/c ls & pause"
# sudo "/cygdrive/c/Program Files/Sublime Text 3/sublime_text.exe" "a.txt"  b.txt
# sudo service listfile
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
