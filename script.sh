# common functions for scripts
. function.sh

#
# Script Arguments
# 

# ScriptArgGet VAR [DESC](VAR) [--] VALUE - get an argument.  Sets var to value and increments shift.
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

# ScriptArgItems VAR ITEMS_VAR VALUE - get a comma delimited list of items in an argument.
# - sets var to an array of values, ${var}Arg to --$var==$value, and increments shift.  
# - ARRAY_VAR is a list of valid items.
ScriptArgItems()
{
	local var="$1" itemsVar="$2"; shift 2
	local -n varArg="${var}Arg"

	# get the item argument
	local value
	ScriptOptGet "value" "$var" "$@" || return
	varArg="--$var=$value"
	StringToArray "${value,,}" "," "$var"

	# check for valid items
	local i items; StringToArray "${value,,}" "," "items"
	for i in "${items[@]}"; do
		! IsInArray "$i" "$itemsVar" && { ScriptErr "'$i' is not a valid item for the '$var' option"; exit 1; }
	done

	return 0
}

#
# Script Callers - script and function call stacks
#

ScriptCallers()
{
	local scriptCallers=()
	IFS=$'\n' ArrayMake "$1" "$(pstree --show-parents --long --arguments $PPID -A | grep "$BIN" | head -n -3 | tac | awk -F'/' '{ print $NF; }' | cut -d" " -f1)"
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

# LogMessage MESSAGE - log a script message, not named log to avoid name conflict
# - output is sent to the standard error to avoid interference with commands whose output is consumed using a subshell, i.e. var="$(command)"
LogMessage() { EchoWrapErr "$(ScriptPrefix)$@"; }
LogPrint() { PrintErr "$(ScriptPrefix)$@"; }

# LogLevel LEVEL MESSAGE - log a message if the logging verbosity level is at least LEVEL
LogLevel() { level="$1"; shift; (( verboseLevel >= level )) && LogMessage "$@"; return 0; }

# logN MESSAGE - log a message if the logging verbosity level is a least N
log1() { LogLevel 1 "$@"; }; log2() { LogLevel 2 "$@"; }; log3() { LogLevel 3 "$@"; }; log4() { LogLevel 4 "$@"; }; log5() { LogLevel 5 "$@"; }

# LogFile - log a file
LogFile()
{
	local file="$1"
	header "$(ScriptPrefix)$(GetFileName "$file")" >& /dev/stderr
	cat "$file" >& /dev/stderr
	HeaderDone >& /dev/stderr
}

# LogFileLevel N FILE - log the contents of file if the logging verbosity level is at least LEVEL
LogFileLevel() { level="$1"; shift; (( verboseLevel >= level )) && LogFile "$1"; return 0; }

# logFileN FILE - log the contents of file if the logging verbosity level is at least N
LogFile1() { LogFileLevel 1 "$1"; }; LogFile2() { LogFileLevel 2 "$1"; }; LogFile3() { LogFileLevel 3 "$1"; }; LogFile4() { LogFileLevel 4 "$1"; }; LogFile5() { LogFileLevel 5 "$1"; }

# LogScript LEVEL SCRIPT - log a script we are going to run.  Indent it if it is on more than one line
LogScript()
{
	local level="$1"; shift
	[[ ! $verboseLevel || ! $level ]] || (( verboseLevel < level )) && return

	if [[ "$(echo "$@" | wc -l)" == "1" ]]; then
		LogMessage "running: $@"
	else
		LogMessage "running:"; echo "$@" | AddTab >& /dev/stderr; 
	fi
}

# RunFunction FUNCTION SUFFIX LEVEL MESSAGE FAIL -- [ARGS]- call a function with the specified suffix if it exists
# - level: the numeric logging level at which to log a message
# - message: contains a message to log, the $not variable is substituted for "$FAIL" if the function fails
RunFunctionLog()
{
	# arguments
	local f="$1" suffix="$2" level="$3" message="$4" fail="$5"; shift 4
	[[ "$1" == "--" ]] && shift

	# return if the run function does not exist
	! RunFunctionExists "$f" "$suffix" && return

	# run the function
	local return; RunFunction "$f" "$suffix" -- "$@"; return="$?"

	# log
	(( return == 0 )) && unset fail
	log$level "$(eval echo "$message")"
	return "$return"
}

# RunLog LEVEL COMMAND - log and run a command if the logging verbosist level is at least at the specified leave
RunLogLevel()
{
	local level="$1"; shift

	# log command and arguments
	if [[ $verbose ]] && (( verboseLevel >= level )); then
		local arg message

		for arg in "$@"; do
			local pattern=" |	" # assign pattern to variable to maintain Bash and ZSH compatibility
			[[ "$arg" =~  $pattern || ! $arg ]] && message+="\"$arg\" " || message+="$arg "
		done

		LogMessage "command: $message"
	fi

	[[ $test ]] && return

	"$@"
}

# logFileN COMMAND - log and run a command if the logging verbosity level is at least N
RunLog() { RunLog1 "$@"; }; RunLog1() { RunLogLevel 1 "$@"; }; RunLog2() { RunLogLevel 2 "$@"; }; RunLog3() { RunLogLevel 3 "$@"; }; RunLog4() { RunLogLevel 4 "$@"; }; RunLog5() { RunLogLevel 5 "$@"; }; 
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
	ScriptOptGlobal "$@" && return

	# unknown option
	UnknownOption "$1"
}

ScriptOptGlobal()
{
	case "$1" in
		--force|-f) force="--force";;
		--help|-h) ScriptOptVerbose "$@"; usage 0;;
		--no-prompt|-np) noPrompt="--no-prompt";;
		--quiet|-q) quiet="--quiet" quietOutput="/dev/null";;
		--test|-t) test="--test";;
		--verbose|-v|-vv|-vvv|-vvv|-vvvv|-vvvvv) ScriptOptVerbose "$1";;
		--version) IsFunction versionCommand || return; showVersion="true";;
		--wait|-w) wait="--wait";;
		*) return 1;;
	esac
}

# ScriptOptGet [--check|--integer] VAR [DESC] --OPTION VALUE
#
# Set option VAR from OPTION and VALUE.  Increments shift if needed.  
#	- --optional - if specified, the value is optional
# - DESC defaults to VAR and is used in the missing option error message
# - OPTION VALUE format is one of: -o|--option[=| ]VAL
ScriptOptGet()
{
	local require="true"; [[ "$1" == "--optional" ]] && { unset require; shift; }
	local integer; [[ "$1" == "--integer" ]] && { integer="true"; shift; }
	local scriptVar="$1"; shift
	local scriptDesc="$scriptVar"; ! IsOption "$1" && { scriptDesc="$1"; shift; }
	local opt="$1"; shift
	local scriptOptValue

	# format: -o=VAL --option=VAL
	if [[ "$opt" =~ = ]]; then
		scriptOptValue="$(GetAfter "$opt" =)"

	# format: -o VAL --option VAL
	elif (( $# > 0 )) && ! IsOption "$1" && { [[ ! $integer ]] || IsInteger "$1"; }; then
		scriptOptValue="$1"; ((++shift))
		
	elif [[ $require ]]; then
		MissingOperand "$scriptDesc"

	else
		return 1

	fi

	# check data type
	[[ $integer && $scriptOptValue ]] && ! IsInteger "$scriptOptValue" && { ScriptErr "$scriptDesc must be an integer"; ScriptExit; }

	# set variable
	local -n var="$scriptVar"
	var="$scriptOptValue"
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
# Script Host Option
#

# ForAllHosts COMMAND [ARGS...] - run a command for all hosts.  If forAllHeader is set and there is more than one host display it as a header.
ForAllHosts()
{
	local host; GetHosts || return
	for host in "${hosts[@]}"; do
		[[ $forAllHeader ]] && (( ${#hosts[@]} > 1 )) && header "$forAllHeader ($(RemoveDnsSuffix "$host"))"
		"$@" "$host" || return
	done
}

ScriptOptHost() 
{
	case "$1" in
		-H|--host|-H=*|--host=*) ScriptOptGet hostArg host "$@"; hostOpt=(--host="$hostArg");;
		*) return 1
	esac
}

ScriptOptHostVerify() { [[ $hostArg ]] && return; MissingOperand "host"; }

# GetHosts [HOSTS] - set hosts array from --host argument, the passed list, or all Nomad clients.
GetHosts()
{
	# return if hosts is already specified
	[[ $hosts ]] && return

	# use hostArg, then passed list
	local h="${hostArg:-$1}"

	# comma separate list of hosts
	[[ "$h" != @(|all|web) ]] && { StringToArray "${h,,}" "," hosts; return; }

	# service name
	[[ "$h" == @(|all) ]] && hostArg="nomad-client"
	IFS=$'\n' ArrayMakeC hosts GetServers "$hostArg"
}

# GetHostsService SERVICE - set hosts array from --host argument or from the available hosts for the service.
GetHostsService()
{
	local service="$1"; [[ ! $service ]] && MissingOperand "service", "GetHostsService"

	# use hostArg, then passed list
	local h="$hostArg"

	# comma separate list of hosts
	[[ $h ]] && { StringToArray "$(LowerCase "$h")" "," hosts; return; }

	# service name	
	IFS=$'\n' ArrayMakeC hosts hashi app server available "$service"
}

# GetHostsConfig CONFIG - set hosts array from --host argument or from the specified configuration entry.
GetHostsConfig() 
{
	local config="$1" h="$(LowerCase "$hostArg")"
	[[ "$h" == @(|all) ]] && h="$(ConfigGet "${config}Servers")"
	StringToArray "" "," h; [[ $hosts ]] && return

	# usage
	[[ ! $config ]] && MissingOperand "config" "GetHostsConfig"
	ScriptErr "the current network does not have any '$config' hosts" "GetHostsConfig"; return 1
}

# GetHostsConfigNetwork CONFIG - set hosts array from --host argument (hostArg) or from the specified configuration entry for the current network.
GetHostsConfigNetwork() 
{
	local config="$1" h="$(LowerCase "$hostArg")"
	[[ "$h" == @(|all) ]] && h="$(network current servers "$config")"
	StringToArray "$h" "," hosts; [[ $hosts ]] && return

	# usage
	[[ ! $config ]] && MissingOperand "config" "GetHostsConfigNetwork"
	ScriptErr "the current network does not have any '$config' hosts" "GetHostsConfigNetwork"; return 1
}

#
# Script Run
#

# ScriptRun [defaultCommand]: init->opt->args->initFinal->command->cleanup
ScriptRun()
{
	# variables	
	local defaultCommand defaultCommandUsed
	local hostUsage="	-H,  --host [HOSTS](all)		comma separated list of hosts, or all|web"

	# initialize
	RunFunction "init" -- "$@" || return

	# commands - format command1Command2Command
	local args=() c shift="1"
	local command commandNames=() commands=() globalArgs=() globalArgsLessVerbose=() originalArgs=("$@") otherArgs=() # public

	while (( $# )); do
		local firstCommand="true"; [[ $command ]] && unset firstCommand

		# -- indicates end of arguments
		[[ "$1" == "--" ]] && { shift; otherArgs+=("$@"); break; }

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
	unset -v force noPrompt quiet test showVersion verbose verboseLevel verboseLess wait
	quietOutput="/dev/stdout"

	set -- "${args[@]}"; args=()
	while (( $# )); do
		! IsOption "$1" && { args+=("$1"); shift; continue; }
		ScriptOpt "$@" || return; shift "$shift"		
	done

	# set global options
	globalArgs=($force $noPrompt $quiet $verbose)
	(( verboseLevel > 1 )) && verboseLess="-$(StringRepeat "v" "$(( verboseLevel - 1 ))")"
	globalArgsLessVerbose=($force $noPrompt $quiet $verboseLess)

	# operands
	set -- "${args[@]}"
	shift=0; RunFunction "args" -- "$@" || return; shift "$shift"
	for c in "${commands[@]}"; do
		shift=0; RunFunction "${c}Args" -- "$@" || return; shift "$shift"
	done

	# extra operand
	(( $# != 0 )) && { ExtraOperand "$1"; return 1; }

	# arg end
	for c in "${commands[@]}"; do
		RunFunction "${c}ArgEnd" || return
	done
	RunFunction "argEnd" || return

	# cleanup
	unset args c shift
	
	# run command
	[[ $showVersion ]] && command="version"
	[[ ! $command ]] && usage
	local result; "${command}Command"; result="$?"

	# cleanup
	RunFunction cleanup || return

	return "$result"
}

#
# ScriptUsage
#

# ScriptUsage RESULT USAGE_TEXT
ScriptUsage()
{
	local foundUsage

	# find usage for the command 
	if [[ ! $defaultCommandUsed ]]; then
		local c
		for c in $(ArrayReverse commands); do
			IsFunction "${c}Usage" && "${c}Usage" "$@" && { foundUsage="true"; break; }
		done
	fi

	# show passed usage
	[[ ! $foundUsage ]] && ScriptUsageEcho "$2"
	
	# global option usage
	local version; IsFunction versionCommand && version="\n	    --version			output version information and exit"
	[[ $verbose ]] && ScriptUsageEcho "\nGlobal options:
	-f, --force				force the operation
	-h, --help				display this help and exit
	-np, --no-prompt  suppress interactive prompts
	-q, --quiet 			minimize informational messages
	-t, --test				test mode, do not make changes
	-v, --verbose			verbose mode, multiple -v increase verbosity (max 5)$version
	-w, --wait				wait for the operation to complete"

	# end of argument (--) usage
	if (( verboseLevel == 1 )); then
		ScriptUsageEcho "	--     						signal the end of arguments"
	elif (( verboseLevel > 1 )); then
		ScriptUsageEcho "\
	--     						signal the end of arguments.  This is useful to allow further arguments to
					 					the script program itself to start with a  “-”.  This provides consistency 
					 					with the argument parsing convention used by most other POSIX programs."
	fi

	# verbose usage
	if [[ $verbose ]]; then
		[[ $c && ! $defaultCommandUsed ]] && RunFunction "${c}UsageVerbose" || RunFunction "usageVerbose"
	fi

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
# other
#

ScriptEchoQuiet() { log1 "$1"; [[ $quiet ]] && return; EchoWrap "$1"; }
ScriptErrQuiet() { log1 "$1"; [[ $quiet ]] && return; ScriptErr "$1"; }
ScriptOnlyWin() { IsPlatform win && return; ScriptErr "command can only run on Windows"; return 1; }

#
# helper
#

IsDriveLetter()
{
	local driveLetters=( c d e f g h i j k l m n o p q r s t u v w x y z )
	IsInArray "$1" driveLetters
}

# IsValidCommandName NAME - NAME is valid name for script commands (not empty, no spaces, single quotes, or double quotes, not an option)
IsValidCommandName() { [[ $1 && ! "$1" =~ [\ \'\"] ]] && ! IsOption "$1"; }	
