# common functions for scripts
. function.sh

#
# Script Arguments
# 

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

# ScriptOpt OPTION - process an option
# - sets shift variable to number of arguments processed
ScriptOpt()
{
	shift=0; ! IsOption "$1" && return; shift=1
	
	# command option - start with the last command
	for c in $(ArrayReverse commands); do
		IsFunction "${c}Opt" && "${c}Opt" "$@" && return
	done

	# script option
	IsFunction "opt" && { opt "$@" && return; }

	# global option
	case "$1" in
		-f|--force) force="--force";;
		-h|--help) usage 0;;
		-q|--quiet) quiet="--quiet";;
		-t|--test) test="--test"; testEcho="echo";;
		-v|--verbose) verbose="-v"; verboseLevel=1;;
		-vv) verbose="-vv"; verboseLevel=2;;
		-vvv) verbose="-vvv"; verboseLevel=3;;
		*) UnknownOption "$1";;
	esac
}

# ScriptOptGet [--check]] VAR [DESC] OPTION VALUE
#
# Set option VAR from OPTION and VALUE
# - DESC defaults to VAR and is used in the missing option error message
#	- if --check is specified the option is not required.
# - OPTION VALUE format is one of: -o|--option[=| ]VAL
# - sets var to value and increments shift if needed.  
ScriptOptGet()
{
	local require="true"; [[ "$1" == "--check" ]] && { shift; unset require; }
	local scriptVar="$1"; shift
	local scriptDesc="$scriptVar"; ! IsOption "$1" && { scriptDesc="$1"; shift; }
	local opt="$1"; shift

	# format: -o=VAL --option=VAL
	if [[ "$opt" =~ = ]]; then
		value="$(GetAfter "$opt" =)"

	# format: -o VAL --option VAL
	elif (( $# > 0 )) && ! IsOption "$1"; then
		value="$1"; ((++shift))
		
	elif [[ $require ]]; then
		MissingOperand "$scriptDesc"

	else
		return 1

	fi

	local -n var="$scriptVar"
	var="$value"
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

# ScriptRun [defaultCommand]: init->opt->args->initFinal->command->cleanup
ScriptRun()
{
	local defaultCommand defaultCommandUsed; RunFunction "init" || return
	
	# commands - format command1Command2Command
	local args=() c shift="1"
	local command commandNames=() commands=() otherArgs=() # public

	while (( $# )); do

		# -- indicates end of arguments
		[[ "$1" == "--" ]] && { shift; otherArgs+=( "$@" ); break; }

		# continue with next argument if not a valid command name
		! IsValidCommandName "$1" && { args+=("$1"); shift; continue; }

		# first command is lower case (i.e. dhcp), second command is upper case (i.e. dhcpStatus)
		[[ $command ]] && ProperCase "$1" c || LowerCase "$1" c;

		# commands that start with is are proper cased after is, i.e. isAvailable
		[[ "$c" =~ ^is..* ]] && c="is$(ProperCase "${c#is}")"

		# the argument is a command if there is a function for it
		c="${command}${c}Command"
		if IsFunction "$c"; then
			command="${c%Command}" commands+=("$command") commandNames+=("${1,,}")			
		else
			args+=("$1")		
		fi

		shift
	done	

	# default command
	[[ ! $command ]] && { defaultCommandUsed="true" command="$defaultCommand" commands=("$command") commandNames=("$command"); }

	# arg start
	RunFunction "argStart" || return
	for c in "${commands[@]}"; do
		RunFunction "${c}ArgStart" || return
	done

	# options
	unset -v force quiet test testEcho verbose verboseLevel
	set -- "${args[@]}"; args=()
	while (( $# )); do
		! IsOption "$1" && { args+=("$1"); shift; continue; }
		ScriptOpt "$@" || return; shift "$shift"
	done

	# operands
	set -- "${args[@]}"
	shift=0; RunFunction "args" -- "$@" || return; shift "$shift"
	for c in "${commands[@]}"; do
		shift=0; RunFunction "${c}Args" -- "$@" || return; shift "$shift"
	done
	(( $# != 0 )) && { ExtraOperand "$@"; return 1; }

	# arg end
	for c in "${commands[@]}"; do
		RunFunction "${c}ArgEnd" || return
	done
	RunFunction "argEnd" || return

	# cleanup
	unset args c shift
	
	# run command
	[[ ! $command ]] && usage
	local result; "${command}Command"; result="$?"

	# cleanup
	RunFunction cleanup || return

	return "$result"
}

# ScriptUsage RESULT USAGE_TEXT
ScriptUsage()
{
	local foundUsage

	if [[ ! $defaultCommandUsed ]]; then
		local c
		for c in $(ArrayReverse commands); do
			IsFunction "${c}Usage" && "${c}Usage" "$@" && { foundUsage="true"; break; }
		done
	fi
	
	[[ ! $foundUsage ]] && echot "$2"
	
	[[ $verbose ]] && echot "\nGlobal options:
	-f, --force			force the operation
	-h, --help			display command usage
	-q, --quiet 		minimize informational messages
	-t, --test			test mode, do not make changes
	-v, --verbose		verbose mode, multiple -vv or -vvv for additional logging
	--     					signal the end of arguments"

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

# IsValidCommandName NAME - NAME is valid name for script commands
IsValidCommandName() { [[ $1 && ! "$1" =~ [\ \'\"] ]] && ! IsOption "$1"; }	
