# common functions for scripts
. function.sh

#
# Script Arguments
# 

# GetArgs - get the non-option script arguments for the commands
ScriptArgs()
{
	local c finalShift=0

	for c in "${commands[@]}"; do
		shift=0
		RunFunction "${c}GetArgs" -- "$@" || return
		RunFunction "${c}Args" -- "$@" || return # legacy
		shift "$shift"; ((finalShift+=shift))
	done
	shift="$finalShift"

	for c in "${commands[@]}"; do
		RunFunction "${c}ArgEnd" -- "$@" || return
		RunFunction "${c}CheckArgs" -- "$@" || return # legacy
	done
}

# ScriptGetArg VAR [DESC](VAR) VALUE - get an argument.  Sets var to value and increments shift
ScriptGetArg()
{
	local varArg="$1"
	local -n var="$varArg"
	local scriptDesc="$varArg"; (( $# > 2 )) && { scriptDesc="$2"; shift; }
	local scriptValue="$2"; (( $# < 2 )) && MissingOperand "$scriptDesc"
	var="$scriptValue"; ((++shift))
}

ScriptGetDriveLetterArg()
{
	ScriptGetArg "letter" "$1"

	# change drive letters to a single lower case letter, i.e. C:\ -> c
	letter="${letter,,}"
	[[ "$letter" =~ ^.?:$ ]] && letter="${letter:0:1}"

	! IsDriveLetter "$letter" && { ScriptErr "$letter is not a drive letter"; return 1; }

	return 0
}

#
# Script Callers - script and function call stacks
#

ScriptCallers()
{
	local scriptCallers=()
	IFS=$'\n' scriptCallers=( $(pstree --show-parents --long --arguments $PPID -A | grep "$BIN" | head -n -3 | tac | awk -F'/' '{ print $NF; }' | cut -d" " -f1; ) )
	CopyArray scriptCallers "$1"
}

ScriptCaller()
{
	ps --no-headers -o command $PPID | cut -d' ' -f2 | GetFileName
	# ScriptCallers
	# (( ${#callers[@]} > 0 )) && echo "${callers[0]}"
}

#
# Script Checks
#

ScriptCheckFile() { ScriptCheckPath --file "$1"; }
ScriptCheckDir() { ScriptCheckPath --dir "$1"; }

ScriptCheckPath()
{
	local checkFile; [[ "$1" == "--file" ]] && { checkFile="true"; shift; }
	local checkDir; [[ "$1" == "--dir" ]] && { checkDir="true"; shift; }

	[[ ! -e "$1" ]] && { ScriptErr "cannot access \`$1\`: No such file or directory"; ScriptExit; }
	[[ $checkFile && -d "$1" ]] && { ScriptErr "$1: Is a directory"; ScriptExit; }
	[[ $checkDir && -f "$1" ]] && { ScriptErr "$1: Is a file"; ScriptExit; }
	
	return 0
}

#
# Script Options
# 

# ScriptOption OPTION - get an option for the commands
ScriptOption()
{
	# not an option, add it to args
	! IsOption "$1" && { args+=("$1"); return; }

	# see if a commmand takes the option
	local c
	for c in $(ArrayReverse commands); do
		IsFunction "${c}GetOption" && "${c}GetOption" "$@" && return
		IsFunction "${c}Option" && "${c}Option" "$@" && return # legacy
	done

	# not a valid option
	UnknownOption "$1"
}

# ScriptArg VAR [DESC] OPTION VALUE - get an option argument.  Sets var to value and increments shift if needed.
#   -o|--option -oVAL -o VAL -o=VAL --option=VAL --option VAL
ScriptArg()
{
	local -n var="$1"
	local desc="$1"; ! IsOption "$2" && { desc="$2"; shift; }
	local opt="$2" value="$3"
	local longOpt; [[ "$opt" =~ ^-- ]] && longOpt="true"

	# -o=VAL --option=VAL
	if [[ "$opt" =~ = ]]; then
		[[ $longOpt ]] && value="$(GetWord "$opt" 2 "=")" || value="${opt:3}"

	# -oVAL
	elif [[ ! $longOpt ]] && (( ${#opt} > 2 )); then
		value="${opt:2}"

	# -o VAL --option VAL
	elif [[ $value ]] && ! IsOption "$value"; then
		((++shift))
		
	else
		MissingOperand "$desc"; return 1

	fi

	var="$value"
}

# ScriptGetNetworkProtocol - sets protocol and protocolArg
ScriptGetNetworkProtocol()
{
	ScriptArg "protocol" "$@"; 
	protocol="${protocol,,}"
	CheckNetworkProtocol "$protocol" || { ScriptErr "\`$protocol\` is not a valid network protocol"; ScriptExit; }
	unset protocolArg; [[ $protocol ]] && protocolArg="--protocol=$protocol"
	return 0
}

ScriptNetworkProtocolUsage() { echo "use the specified protocol for file sharing (NFS|SMB|SSH|SSH_PORT)"; }

#
# Script Other
#

# ScriptCommand - get a command by looking for function in the format command1Command2Command
#   Sets args, command, and commands
ScriptCommand()
{
	local defaultCommand; [[ "$1" =~ .*Command ]] && 	{ defaultCommand="${1%%Command}"; shift; }
	local arg c test
	unset -v command defaultCommandUsed help
	args=() commandNames=() commands=() otherArgs=() shift="1" 

	while [[ $1 ]]; do

		# done with arguments
		[[ "$1" == "--" ]] && break

		# save argument
		arg="$1"; shift

		# option
		IsOption "$arg" && { args+=("$arg"); continue; }

		# if we do not have a command assume it is lower case, i.e. dhcp
		# if we already have a command assume the next portion of the command starts with an upper case, i.e. dhcpStatus
		local is; [[ $command ]] && is="Is"
		[[ $command ]] && ProperCase "$arg" c || LowerCase "$arg" c;


		# add the existing command to the next command (c) with the best guess at casing
		[[ "$c" =~ ^is..* ]] && c="is$(ProperCase "${c#is}")" # i.e. isAvailable
		c="${command}${c}Command"

		# find the exact command match - a case-insensitive match is slow
		if IsFunction "$c"; then
			command="${c%Command}" commands+=("$command") commandNames+=("${arg,,}")
			IsFunction "${command}ArgStart" && { "${command}ArgStart" || return; }
			IsFunction "${command}Vars" && { "${command}Vars" || return; } # legacy
			continue
		fi

		# not a command
		args+=("$arg")		

	done

	args+=( "$@" )

	[[ ! $command ]] && { defaultCommandUsed="true" command="$defaultCommand" commands=("$command") commandNames=("$command"); }
	[[ $command ]] && return || usage
}

# ScriptUsage RESULT USAGE_TEXT
ScriptUsage()
{
	if [[ ! $defaultCommandUsed ]]; then
		local c
		for c in $(ArrayReverse commands); do
			IsFunction "${c}Usage" && "${c}Usage" "$@" && exit "${1:-1}"
		done
	fi
	
	echot "$2"
	exit "${1:-1}"
}

#
# Helper Functions
#

IsDriveLetter()
{
	local driveLetters=( c d e f g h i j k l m n o p q r s t u v w x y z )
	IsInArray "$1" driveLetters
}
