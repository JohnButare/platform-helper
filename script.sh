# common functions for scripts
. function.sh

#
# arguments
# 

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

# GetArgs - get the non-options script arguments for the commands
ScriptArgs()
{
	local c finalShift=0; shift=0
	for c in "${commands[@]}"; do
		IsFunction "${c}Args" && "${c}Args" "$@" && return
		shift "$shift"; ((finalShift+=shift))
	done
	shift="$finalShift"
}

# ScriptCommand - get a command by looking for function in the format command1Command2Command
#   Sets args, command, and commands
ScriptCommand()
{
	local arg c test
	args=() command="" commandNames=() commands=() help="" otherArgs=() shift="1"

	for arg in "$@"; do

		# option
		IsOption "$arg" && { args+=("$arg"); continue; }

		# if we do not have a command assume it is lower case, i.e. dhcp
		# if we already have a command assume the next portion of the command starts with an upper case, i.e. dhcpStatus
		[[ $command ]] && ProperCase "$arg" c || LowerCase "$arg" c;

		# add the existing command to the next argument with the best guess at casing
		c="${command}${c}Command"

		# find the exact command or look for a case-insensitive match
		if IsFunction "$c" || c="$(FindFunction "$c")"; then
			command="${c%Command}" commands+=("$command") commandNames+=("${arg,,}")
			IsFunction "${command}Init" && { "${command}Init" || return; }
			continue
		fi

		# not a command
		args+=("$arg")		

	done

	[[ $command ]] && return || usage
}

# ScriptGetArg VAR [DESC](VAR) VALUE - get an argument.  Sets var to value and increments shift
ScriptGetArg()
{
	local varArg="$1"
	local -n var="$varArg"
	local desc="$varArg"; (( $# > 2 )) && { desc="$2"; shift; }
	local value="$2"; [[ ! $value ]] && MissingOperand "$desc"
	var="$value"; ((++shift))
}

ScriptCheckPath()
{
	local checkFile; [[ "$1" == "--file" ]] && { checkFile="true"; shift; }
	local checkDir; [[ "$1" == "--dir" ]] && { checkDir="true"; shift; }

	[[ ! -e "$1" ]] && { ScriptErr "cannot access \`$1\`: No such file or directory"; ScriptExit; }
	[[ $checkFile && -d "$1" ]] && { ScriptErr "$1: Is a directory"; ScriptExit; }
	[[ $checkDir && -f "$1" ]] && { ScriptErr "$1: Is a file"; ScriptExit; }
	
	return 0
}

ScriptCheckFile() { ScriptCheckPath --file "$1"; }
ScriptCheckDir() { ScriptCheckPath --dir "$1"; }

# ScriptOption OPTION - get an option for the commands
ScriptOption()
{
	# not an option, add it to args
	! IsOption "$1" && { args+=("$1"); return; }

	# see if a commmand takes the option
	local c
	for c in $(ReverseArray commands); do
		IsFunction "${c}Option" && "${c}Option" "$@" && return
	done

	# not a valid option
	UnknownOption "$1"
}

# ScriptUsage RESULT USAGE_TEXT
ScriptUsage()
{
	local c
	for c in $(ReverseArray commands); do
		IsFunction "${c}Usage" && "${c}Usage" "$@" && exit "${1:-1}"
	done

	echot "$2"
	exit "${1:-1}"
}

#
# callers
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
