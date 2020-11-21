# common functions for scripts
. function.sh

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

# GetArgs - get arguments for a command
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

		# get the possible command, i.e. dhcpCommand or dhcpStatusCommand
		[[ $command ]] && ProperCase "$arg" c || LowerCase "$arg" c;
		c="${command}${c}"

		# find the exact command or look for a case-insensitive match
		if IsFunction "${c}Command" || s="$(FindFunction "${c}Command")"; then
			command="$c" commands+=("$c") commandNames+=("${arg,,}")
			IsFunction "${c}Init" && { "${c}Init" || return; }
			continue
		fi

		# not a command
		args+=("$arg")		

	done

	[[ $command ]] && return || usage
}

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
