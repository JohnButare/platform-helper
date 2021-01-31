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
		RunFunction "${c}Args" -- "$@" || return
		shift "$shift"; ((finalShift+=shift))
	done
	shift="$finalShift"

	for c in "${commands[@]}"; do
		RunFunction "${c}ArgEnd" -- "$@" || return
	done
}

# ScriptArgGet VAR [DESC](VAR) -- VALUE - get an argument.  Sets var to value and increments shift
ScriptArgGet()
{
	# arguments
	local scriptVar="$1"; shift
	local scriptDesc="$scriptVar"; [[ "$1" != "--" ]] && { scriptDesc="$1"; shift; }
	[[ "$1" == "--" ]] && shift
	(( $# == 0 )) && MissingOperand "$scriptDesc"

	# set the variable
	local -n var="$scriptVar"; var="$1"; ((++shift))
}

ScriptArgDriveLetter()
{
	ScriptArgGet "letter" -- "$@"

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

	[[ ! -e "$1" ]] && { ScriptErr "cannot access '$1': No such file or directory"; ScriptExit; }
	[[ $checkFile && -d "$1" ]] && { ScriptErr "$1: Is a directory"; ScriptExit; }
	[[ $checkDir && -f "$1" ]] && { ScriptErr "$1: Is a file"; ScriptExit; }
	
	return 0
}

#
# Script Options
# 

# ScriptOpt OPTION - get an option for the commands
ScriptOpt()
{
	# not an option, add it to args
	! IsOption "$1" && { args+=("$1"); return; }

	# global options
	ScriptOptGlobal "$@" && return

	# see if a commmand takes the option
	local c
	for c in $(ArrayReverse commands); do
		IsFunction "${c}Opt" && "${c}Opt" "$@" && return
	done

	# not a valid option
	UnknownOption "$1"
}

# ScriptOptGet [--check]] VAR [DESC] OPTION VALUE - get an option argument.  
#   Sets var to value and increments shift if needed.  Format: -o|--option[=| ]VAL
#		If --check is specified the option is not required.
ScriptOptGet()
{
	local require="true"; [[ "$1" == "--check" ]] && { shift; unset require; }
	local scriptVar="$1"; shift
	local scriptDesc="$scriptVar"; ! IsOption "$1" && { scriptDesc="$1"; shift; }
	local opt="$1"; shift

	# -o=VAL --option=VAL
	if [[ "$opt" =~ = ]]; then
		value="$(GetAfter "$opt" =)"

	# -o VAL --option VAL
	elif (( $# > 0 )) && ! IsOption "$1"; then
		value="$1"; ((++shift))
		
	else
		[[ $require ]] && MissingOperand "$scriptDesc"
		return 1

	fi

	local -n var="$scriptVar"
	var="$value"
}

ScriptOptGlobal()
{
	case "$1" in
		-f|--force) force="--force";;
		-h|--help) usage 0;;
		-q|--quiet) quiet="--quiet";;
		-t|--test) test="--test"; testEcho="echo";;
		-v|--verbose) verbose="-v"; verboseLevel=1;;
		-vv) verbose="-vv"; verboseLevel=2;;
		-vvv) verbose="-vvv"; verboseLevel=3;;
		--) shift; otherArgs+=("$@"); set --; break;;
		*) return 1
	esac
}

# ScriptOptNetworkProtocol - sets protocol and protocolArg
ScriptOptNetworkProtocol()
{
	ScriptOptGet "protocol" "$@"; 
	protocol="${protocol,,}"
	CheckNetworkProtocol "$protocol" || { ScriptErr "'$protocol' is not a valid network protocol"; ScriptExit; }
	unset protocolArg; [[ $protocol ]] && protocolArg=( "--protocol=$protocol" )
	return 0
}

ScriptOptNetworkProtocolUsage() { echo "use the specified protocol for file sharing (NFS|SMB|SSH|SSH_PORT)"; }

#
# Script Other
#

# ScriptCommand - get a command by looking for function in the format command1Command2Command
#   Sets args, command, and commands
ScriptCommand()
{
	local defaultCommand; [[ "$1" =~ .*Command ]] && 	{ defaultCommand="${1%%Command}"; shift; }
	local arg c test
	
	# variables
	unset -v command defaultCommandUsed 
	unset -v force quiet set test testEcho verbose verboseLevel

	args=() commandNames=() commands=() otherArgs=() shift="1" 
	
	globalOptionUsage="Global options:
	-f,  --force			force the operation
	-t,  --test				test mode, do not make changes
	-q, --quiet 			minimize informational messages
	-v,  --verbose		verbose mode, multiple -vv or -vvv for additional logging"

	# find commands
	while (( $# )); do

		# done with argument processing
		[[ "$1" == "--" ]] && break

		# save argument
		arg="$1"; shift

		# option
		{ [[ ! $arg ]] || IsOption "$arg"; } && { args+=("$arg"); continue; }

		# if we do not have a command assume it is lower case, i.e. dhcp
		# if we already have a command assume the next portion of the command starts with an upper case, i.e. dhcpStatus
		[[ $command ]] && ProperCase "$arg" c || LowerCase "$arg" c;

		# add the existing command to the next command (c) with the best guess at casing
		[[ "$c" =~ ^is..* ]] && c="is$(ProperCase "${c#is}")" # i.e. isAvailable
		c="${command}${c}Command"

		# find the exact command match - a case-insensitive match is too slow
		if IsFunction "$c"; then
			command="${c%Command}" commands+=("$command") commandNames+=("${arg,,}")
			IsFunction "${command}ArgStart" && { "${command}ArgStart" || return; }
			continue
		fi

		# not a command
		args+=("$arg")		

	done

	args+=( "$@" )

	[[ ! $command ]] && { defaultCommandUsed="true" command="$defaultCommand" commands=("$command") commandNames=("$command"); }
	[[ ! $command ]] && usage

	return 0
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
