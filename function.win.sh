#
# Applications
#

mmc() {	( cmd.exe /c mmc.exe "$@" & ) >& /dev/null; }

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

		# use Windows Terminal if poassible
		local p; p="$(FindInPath "wt.exe")" || p="$P/Windows Terminal/wt.exe"
		[[ -f "$p" ]] && { start --elevate "$p" -d "$PWD"; return; }

		# use wsl.exe
		start --elevate "wsl.exe"; return;
	fi

	# Launch the specified program elevated
	start --elevate "$@"
}

#
# user
#

GetSid() { PsGetsid.exe -nobanner jjbutare | ${G}tail --lines=-2 | head | RemoveNewline | RemoveCarriageReturn; }

#
# winget
#

winget() { RunWin winget.exe "$@"; }
wingete(){ elevate winget.exe "$@"; } # winget elevated

PackageIsInstalledWin() { PackageListInstalledWin | qgrep "^${1}"; }
PackageVersionWin() { PackageListInstalledWin | grep "^${1}" | cut -d"," -f2; }
PackageWinCache() { export PACKAGE_WIN_CACHE="$(PackageListInstalledWin)"; }
PackageWinCacheClear() { unset PACKAGE_WIN_CACHE; }

PackageListInstalledWin()
{
	[[ $PACKAGE_WIN_CACHE ]] && { echo -n "$PACKAGE_WIN_CACHE"; return; }

	# find columns with name and version, winget ls returns variable number of columns
	# example: Windows Application Compatibility… MSIX\Microsoft.ApplicationCompatib… 1.2511.9.0
	local s; s="$(winget ls | RemoveCarriageReturn | tail -n +3)" || return
	local line="$(echo "$s" | grep "….*….*" | head -1)" # fine truncate lines, with two …
	local col1End="${line%%…*}"; col1End="${#col1End}"

	line="${line#*…}"
	local col2Start="${line%%…*}"; col2Start="${#col2Start}"; col2Start="$(( col1End + col2Start + 4 ))"
	# echo "col1End=$col1End col2Start=$col2Start"

	echo "$s" |\
		awk '{s1=substr($0,1,'$col1End'); s2=substr($0,'$col2Start'); sub(/[[:space:]]+$/,"",s1); print s1","s2}' |\
		awk -F',' '{split($2, a, " "); print $1 "," a[1]}'
}

#
# done
#

return 0
