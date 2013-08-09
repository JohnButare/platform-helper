IsInteractive() { [[ "$-" == *i* ]]; }
IsFunction() { type $1 >& /dev/null; }
pause() { read -n 1 -p "${*-Press any key when ready...}"; }
ShowInteractive() { echo "interactive=$(IsInteractive && echo 'yes' || echo 'no')"; }
clipw() { printf "$1" > /dev/clipboard; }
clipr() { cat /dev/clipboard; }

#
# display
#

[[ "$TABS" == "" ]] && TABS=2

echot() { echo -e "$*" | expand -t $TABS; } 	# EchoTab
catt() { cat $* | expand -t $TABS; } 							# CatTab
lesst() { less -x $TABS $*; } 										# LessTab

clear()
{
	local clear=''

	type -p clear >/dev/null && \
		clear=$(exec clear)
	[[ -z $clear ]] && type -p tput >/dev/null && \
		clear=$(exec tput clear)
	[[ -z $clear ]] && \
		clear=$'\e[H\e[2J'

	echo -en "$clear"

	eval "function clear { echo -en '$clear'; }"
}

#
# path
#

wtu() { cygpath -u "$*"; }
utw() { cygpath -w "$(realpath "$*")"; } # realpath to get full Windows path
FindInPath() { IFS=':'; find $PATH -maxdepth 1 -name "$1" -type f -print; unset IFS; }

#
# Process
#

start() { cygstart "$(utw $1)" "${@:2}"; }
starto() { cygstart $1 "$(utw $2)" "${@:3}"; } # starto <option> <program>, i.e. startto --showmaximized notepad
tc() { tcc.exe /c $*; }
sr() { ShellRun.exe "$(utw $*)"; }
IsElevated() { IsElevated.exe > /dev/null; }
ParentProcessName() {  cat /proc/$PPID/status | head -1 | cut -f2; }
RemoteServer() { who am i | cut -f2  -d\( | cut -f1 -d\); }
IsSsh() { [ -n "$SSH_TTY" ] || [ "$(RemoteServer)" != "" ]; }
ShowSsh() { IsSsh && echo "Logged in from $(RemoteServer)" || echo "Not using ssh";}

TextEdit()
{
	local files=""
	local program="$P64/Sublime Text 2/sublime_text.exe"
	#local program="$P32/Notepad++/notepad++.exe" # requires --show to not resize if using half screen with win-L or win-R

	for file in "$@"
	do
		for file in $(eval echo $file)
		do
			file=$(utw $file)
			if [[ -f "$file" ]]
			then
				files="$files \"$file\""
			else
				echo $(basename "$file") does not exist
			fi
		done
	done
	[[ "$files" != "" ]] && start "$program" $files
}

#
# file management
#

CdEcho()
{
	local dir=~
	[ -n "$*" ] && dir=$*
	
	echo Changing to $dir
	cd $dir
}
