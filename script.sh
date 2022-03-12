# common functions for scripts
. function.sh

#
# Script Arguments
# 

# ScriptArgGet VAR [DESC](VAR) -- VALUE - get an argument.  Sets var to value and increments shift
ScriptArgGet()
{
	# arguments
	local integer; [[ "$1" == "--integer" ]] && { integer="true"; shift; }
	local scriptVar="$1"; shift
	local scriptDesc="$scriptVar"; [[ "$1" != "--" ]] && { scriptDesc="$1"; shift; }
	[[ "$1" == "--" ]] && shift
	(( $# == 0 )) && MissingOperand "$scriptDesc"

	# check data type
	[[ $integer ]] && ! IsInteger "$1" && { ScriptErr "$scriptDesc must be an integer"; ScriptExit; }

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

ScriptCheckDir() { ScriptCheckPath --dir "$1"; }
ScriptCheckFile() { ScriptCheckPath --file "$1"; }
ScriptCheckUnc() {	IsUncPath "$1" && return; ScripdtErr "'$1' is not a UNC"; ScriptExit; }

ScriptCheckPath()
{
	local checkFile; [[ "$1" == "--file" ]] && { checkFile="true"; shift; }
	local checkDir; [[ "$1" == "--dir" ]] && { checkDir="true"; shift; }

	[[ ! -e "$1" ]] && { [[ ! $quiet ]] && ScriptErr "cannot access '$1': No such file or directory"; ScriptExit; }
	[[ $checkFile && -d "$1" ]] && { ScriptErr "'$1' is a directory, not a file"; ScriptExit; }
	[[ $checkDir && -f "$1" ]] && { ScriptErr "'$1' is a file, not a directory"; ScriptExit; }
	
	return 0
}

#
# Script Logging
#

ScriptErrQuiet() { [[ $quiet ]] && return; ScriptErr "$@"; }

# logN - log an error message only at the specified verbosity level or higher.  Output is sent to the standard error
# to avoid interference with commands whose output is consumed, such as to set a variable.
log1() { ! (( verboseLevel >= 1 )) && return; EchoWrapErr "$(ScriptPrefix)$@"; return 0; }
log2() { ! (( verboseLevel >= 2 )) && return; EchoWrapErr "$(ScriptPrefix)$@"; return 0; }
log3() { ! (( verboseLevel >= 3 )) && return; EchoWrapErr "$(ScriptPrefix)$@"; return 0; }
LogFile1() { ! (( verboseLevel >= 1 )) && return; LogFile "$1"; return 0; }
LogFile2() { ! (( verboseLevel >= 2 )) && return; LogFile "$1"; return 0; }
LogFile3() { ! (( verboseLevel >= 3 )) && return; LogFile "$1"; return 0; }

# LogFile - log a file
LogFile()
{
	local file="$1"
	header "$(ScriptPrefix)$(GetFileName "$file")" >& /dev/stderr
	cat "$file" >& /dev/stderr
	HeaderDone >& /dev/stderr
}

# RunLog - log a command if verbose logging is specified, then run it if not testing
RunLog()
{
	if [[ $verbose ]]; then
		local arg message

		for arg in "$@"; do
			local pattern=" |	" # assign pattern to variable to maintain Bash and ZSH compatibility
			[[ "$arg" =~  $pattern || ! $arg ]] && message+="\"$arg\" " || message+="$arg "
		done

		log1 "command: $message"
	fi

	[[ $test ]] && return

	"$@"
}

RunLogQuiet() { RunLog RunQuiet "$@"; }
RunLogSilent() { RunLog RunSilent "$@"; }

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
		-h|--help) ScriptOptVerbose "$@"; usage 0;;
		-np|--no-prompt) noPrompt="--no-prompt";;
		-q|--quiet) quiet="--quiet";;
		-t|--test) test="--test";;
		-v|--verbose|-vv|-vvv|-vvv) ScriptOptVerbose "$1";;
		-w|--wait) wait="--wait";;
		*) UnknownOption "$1";;
	esac
}

# ScriptOptGet [--check|--integer] VAR [DESC] --OPTION VALUE
#
# Set option VAR from OPTION and VALUE
# - DESC defaults to VAR and is used in the missing option error message
#	- if --check is specified the option is not required.
# - OPTION VALUE format is one of: -o|--option[=| ]VAL
# - sets var to value and increments shift if needed.  
ScriptOptGet()
{
	local require="true"; [[ "$1" == "--check" ]] && { unset require; shift; }
	local integer; [[ "$1" == "--integer" ]] && { integer="true"; shift; }
	local scriptVar="$1"; shift
	local scriptDesc="$scriptVar"; ! IsOption "$1" && { scriptDesc="$1"; shift; }
	local opt="$1"; shift
	local value

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

	# check data type
	[[ $integer ]] && ! IsInteger "$value" && { ScriptErr "$scriptDesc must be an integer"; ScriptExit; }

	# set variable
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
# Script Run
#

# ScriptRun [defaultCommand]: init->opt->args->initFinal->command->cleanup
ScriptRun()
{
	local defaultCommand defaultCommandUsed; RunFunction "init" -- "$@" || return
		
	# commands - format command1Command2Command
	local args=() c shift="1"
	local command commandNames=() commands=() globalArgs=() originalArgs=("$@") otherArgs=() # public

	while (( $# )); do
		local firstCommand="true"; [[ $command ]] && unset firstCommand

		# -- indicates end of arguments
		[[ "$1" == "--" ]] && { shift; otherArgs+=( "$@" ); break; }

		# continue with next argument if not a valid command name
		! IsValidCommandName "$1" && { args+=("$1"); shift; continue; }

		# first command is lower case (i.e. dhcp), second command is upper case (i.e. dhcpStatus)
		[[ $firstCommand ]] && c="${1,,}" || c="$(ProperCase "$1")"

		# commands that start with 'is' are proper cased after is, i.e. isAvailable
		if [[ "${c,,}" =~ ^is..* ]]; then
			local prefix="${c:0:2}" suffix="${c#??}"
			[[ $firstCommand ]] && prefix="${prefix,,}" || prefix="$(ProperCase "$prefix")"
			c="${prefix}$(ProperCase "${suffix}")"
		fi

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
	unset -v force noPrompt quiet test verbose verboseLevel wait
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

	# extra operand
	(( $# != 0 )) && { ExtraOperand "$1"; return 1; }

	# set global arguments
	globalArgs=($force $noPrompt $quiet $verbose)

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

#
# Script Usage
#

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

	[[ ! $foundUsage ]] && ScriptUsageEcho "$2"
	
	[[ $verbose ]] && ScriptUsageEcho "\nGlobal options:
	-f, --force				force the operation
	-h, --help				display command usage
	-np, --no-prompt  suppress interactive prompts
	-q, --quiet 			minimize informational messages
	-t, --test				test mode, do not make changes
	-v, --verbose			verbose mode, multiple -vv or -vvv for additional logging
	-w, --wait				wait for the operation to complete
	--     						signal the end of arguments"

	[[ $verbose ]] && IsFunction usageVerbose && usageVerbose

	exit "${1:-1}"
}

# ScriptUsageEcho MESSAGE - show usage message with tabs
ScriptUsageEcho()
{
	# output to standard error if we are being called from ScriptEval (which sets SCRIPT_EVAL), otherwise
	# the help text will be evaluated.
	if [[ $SCRIPT_EVAL ]]; then
		echote "$@"
	else
		echot "$@"
	fi
}

#
# Helper Functions
#

IsDriveLetter()
{
	local driveLetters=( c d e f g h i j k l m n o p q r s t u v w x y z )
	IsInArray "$1" driveLetters
}

# IsValidCommandName NAME - NAME is valid name for script commands (not empty, no spaces, single quotes, or double quotes, not an option)
IsValidCommandName() { [[ $1 && ! "$1" =~ [\ \'\"] ]] && ! IsOption "$1"; }	
