# common functions for scripts
. function.sh

#
# Script Arguments
# 

# ScriptArgGet [--integer] [--required] VAR [DESC](VAR) [--] VALUE - get an argument.  Sets var to value and increments shift.
ScriptArgGet()
{
	# arguments
	local integer; [[ "$1" == "--integer" ]] && { integer="true"; shift; }
	local required; [[ "$1" == "--required" ]] && { required="true"; shift; }
	local scriptVar="$1"; shift
	local scriptDesc="$scriptVar"; [[ "$1" != "--" ]] && { scriptDesc="$1"; shift; }
	[[ "$1" == "--" ]] && shift
	(( $# == 0 )) && MissingOperand "$scriptDesc"
	[[ $required && ! $1 ]] && MissingOperand "$scriptDesc"

	# check data type
	[[ $integer ]] && ! IsInteger "$1" && { ScriptErr "$scriptDesc must be an integer"; ScriptExit; }

	# set the variable
	SetVariable "$scriptVar" "$1"; ((++shift))

	return 0
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
# - log output is sent to the standard error to avoid interference with commands whose output is consumed using a subshell, i.e. var="$(command)"

# LogPrint MESSAGE - print a message
LogPrint() { [[ $@ ]] && EchoResetErr; PrintErr "$@"; }

# LogLevel LEVEL MESSAGE - log a message if the logging verbosity level is at least LEVEL
LogLevel() { level="$1"; shift; (( verboseLevel < level )) && return; ScriptMessage "$@"; }
LogPrintLevel() { level="$1"; shift; (( verboseLevel < level )) && return; PrintErr "$@"; }

# logN MESSAGE - log a message if the logging verbosity level is a least N
log1() { LogLevel 1 "$@"; }; log2() { LogLevel 2 "$@"; }; log3() { LogLevel 3 "$@"; }; log4() { LogLevel 4 "$@"; }; log5() { LogLevel 5 "$@"; }
logp1() { LogPrintLevel 1 "$@"; }; logp2() { LogPrintLevel 2 "$@"; }; logp3() { LogPrintLevel 3 "$@"; }; logp4() { LogPrintLevel 4 "$@"; }; logp5() { LogPrintLevel 5 "$@"; }

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
		ScriptMessage "running: $@"
	else
		ScriptMessage "running:"; echo "$@" | AddTab >& /dev/stderr; 
	fi
}

# RunErr CMD - run a command.   Discard stderr unless the command fails, in which case it is re-run
RunErr()
{
	local output; output="$("$@" 2> /dev/null)" || { "$@"; return; }
	echo "$output"
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

# RunLog LEVEL COMMAND - run a command if not testing, log it if the logging verbosisty level is at least at the specified leave
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

		ScriptMessage "command: $message"
	fi

	[[ $test ]] && return

	"$@" # must be in quotes to preserve arguments, test with wiggin sync lb -H=pi2 -v
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
		--force|-f|-ff|-fff) ScriptOptForce "$1";;
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
		MissingOperand "$scriptDesc" || return

	else
		return 1

	fi

	# check data type
	[[ $integer && $scriptOptValue ]] && ! IsInteger "$scriptOptValue" && { ScriptErr "$scriptDesc must be an integer"; ScriptExit; }

	# set variable
	SetVariable "$scriptVar" "$scriptOptValue"
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

# ForAllHosts COMMAND [ARGS...] - run a command for all hosts
# -b, --brief 				- display a brief header by prefixing the command with the host name
# -e, --errors				- keep processing if a command fails, return the total number of errors
# -h, --header HEADER - if set and there is more than one host display it as a header
# -ng, --no-get 			- do not get hosts
# -sr, --show-result	- if the command does not output anything, show the result of running the command (success or failure)
ForAllHosts()
{
	local brief command=() errors errorCount=0 header noGet showResult

	# options
	while (( $# != 0 )); do
		case "$1" in
			--brief|-b) brief="--brief";;
			--errors|-e) errors="--errors";;
			--header|--header=*|-h|-h=*) local shift=0; ScriptOptGet "header" "$@" || return; shift $shift;;
			--no-get|-ng) noGet="--no-get";;
			--show-result|-sr) showResult="--show-result";;
			--) shift; command+=("$@"); break;;
			*) command+=("$1");;
		esac
		shift
	done

	# initialize
	local host; [[ ! $noGet ]] && { GetHosts || return; }
	local multiple; (( ${#hosts[@]} > 1 )) && multiple="true"

	# run command for all hosts
	for host in "${hosts[@]}"; do
		
		# header		
		if [[ $multiple ]]; then
			local hostShort="$(RemoveDnsSuffix "$host")"
			[[ $header || $verbose ]] && header "$header ($hostShort)"
			[[ $brief && ! $verbose ]] && printf "$hostShort: "
		fi

		# run command - if it fails, return if we are not tracking errors
		local result resultDesc="success"; RunLog "${command[@]}" "$host"; result="$?"
		(( result != 0 )) && { [[ ! $errors ]] && return $result; resultDesc="failure"; ((++errorCount)); }

		# for brief output, if the command does not output anything show the result otherwise go to the next line
		if [[ $brief ]]; then
			if [[ $multiple && $showResult ]] && (( $(CurrentColumn) != 0 )); then echo "$resultDesc"
			elif (( $(CurrentColumn) != 0 )); then echo
			fi
		fi

		# logging
		[[ $errors ]] && log1 "errors=$errorCount"
	done

	# return
	[[ $errors ]] && return $errorCount || return 0
}

ScriptOptHostUsage()
{
	EchoWrap "	-H, --host [HOSTS](all)		comma separated list of hosts"
	[[ ! $verbose ]] && return
	EchoWrap "\
		hosts: cam|camera|down|important
			down=important hosts that are down
			important=important hosts
		servers: all|hashi-ENV|locked|unlock|reboot|restart|web|SERVICE|unused
			all=active servers
			hashi-ENV=Hashi servers for the specified environment (i.e. dev, test)
			locked|unlock=hosts with locked credential manager
			reboot=servers requiring a reboot
			restart=servers which have processes requiring a restart
			SERVICE=servers with an active Consul service, i.e. apache-web (web), file
			unused=servers with no Nomad allocations"
}
# ScriptOptHost - sets hostArg hostOpt
ScriptOptHost() 
{
	case "$1" in
		-H|--host|-H=*|--host=*) ScriptOptGet hostArg host "$@"; hostOpt=(--host="$hostArg");;
		*) return 1
	esac
}

ScriptOptHostVerify() { [[ $hostArg ]] && return; MissingOperand "host"; }

# GetHosts [HOSTS] - set hosts array from --host argument, the passed list, or all clients
# getHostsOther - if this array variable set, add these other hosts if all was specified
GetHosts()
{
	# return if hosts is already specified
	[[ $hosts ]] && return

	local resolve="DnsResolveBatch $quiet"
	local resolveMac="DnsResolveMacBatch --full $errors $quiet"
	local sort="sort --ignore-case --version-sort"

	# use hostArg, then passed list
	local h="${hostArg:-$1}"
	local hLower="$(LowerCase "$h")"

	# status
	local showStatus; [[ ! $quiet && "${hostArg,,}" == @(down|important|locked|reboot|restart|unlock) ]] && showStatus="true"
	[[ $showStatus ]] && PrintErr "hosts..."

	# aliases
	local aliasUsed="true";
	case "$hLower" in
		cam|camera) hostArg="" GetHostsConfigNetwork "camera"; IFS=$'\n' ArrayMake hosts "$(ArrayDelimit hosts $'\n' | $resolve | $resolve | $sort)" || return;;
		down) IFS=$'\n' ArrayMake hosts "$(DomotzHelper down | cut -d"," -f2 | $resolveMac | $sort)" || return;;
		hashi-*) IFS=$'\n' ArrayMake hosts "$(hashi config hosts --config-prefix="$(RemoveFront "$hLower" "hashi-")" | $resolve | $sort)" || return;;
		important) IFS=$'\n' ArrayMake hosts "$(DomotzHelper important | $resolveMac | $sort)" || return;;
		locked|unlocked) IFS=$'\n' ArrayMake hosts "$(os info -w=credential all --status | tgrep "(locked)" | cut -d" " -f1 | $resolve | $sort)" || return;;
		reboot) IFS=$'\n' ArrayMake hosts "$(os info -w=reboot all --status ${globalArgs[@]} | tgrep " yes" | cut -d" " -f1 | $resolve | $sort)" || return;;
		restart) IFS=$'\n' ArrayMake hosts "$(os info -w=restart all --status ${globalArgs[@]} | tgrep " yes" | cut -d" " -f1 | $resolve | $sort)" || return;;
		unused) IFS=$'\n' ArrayMake hosts "$(hashi nomad node allocs --numeric | RemoveSpace | grep ":0$" | cut -d":" -f1 | $resolve | $sort)" || return;;

		off)
			local allServers onServers
			StringToArray "$(ConfigGet servers | sort --version-sort)" "," allServers
			IFS=$'\n' ArrayMake onServers "$(GetAllServers | cut -d"." -f1 | $sort)" || return
			IFS=$'\n' ArrayMake hosts "$(ArrayIntersection onServers allServers | $sort)"		
			;;

		*) unset aliasUsed;
	esac

	# status
	[[ $showStatus ]] && EchoErrEnd "done"

	# return if an alias was used
	[[ $aliasUsed ]] && return

	# service name
	if [[ ! "$h" =~ , ]] && { [[ "$hLower" == @(|active|all|web) ]] || IsService "$h"; }; then
		local service="$h"; 

		# aliases
		case "$hLower" in
			""|active|all) service="nomad-client";;
			web) service="apache-web";;
		esac

		IFS=$'\n' ArrayMake hosts "$(GetServers "$service" | $sort)"

		# other hosts
		[[ $getHostsOther && "$service" == "nomad-client" ]] && hosts=("${getHostsOther[@]}" "${hosts[@]}")
		unset getHostsOther

	# comma separated list of hosts
	else
		StringToArray "$hLower" "," hosts

	fi
}

# GetHostsApp APP [all|active|available](available) - set hosts set hosts array from --host argument or the servers hosting the specified application
GetHostsApp()
{
	# arguments
	local app="$1" type="${2:-available}"; type="$(LowerCase "$type")"
	[[ ! $app ]] && { MissingOperand "app" "GetHostsApp"; return; }
	[[ "$type" != @(all|active|available) ]] && { ExtraOperand "$2" "GetHostsApp"; return; }

	# if the hostArg is all get all specified servers for the app
	[[ "$(LowerCase "$hostArg")" == "all" ]] && hostArg=""

	# use hostArg
	[[ $hostArg ]] && { StringToArray "$(LowerCase "$hostArg")" "," hosts; return; }

	# get hosts
	hosts=(); IFS=$'\n' ArrayMakeC hosts hashi app server "$type" "$app"

	# validate
	[[ $hosts ]] && return
	local desc=" $(LowerCase "$type")"; [[ "$type" == "available" ]] && type=
	ScriptErrQuiet "there are no$desc '$app' servers" "GetHostsApp"; return 1
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

# GetHostsConfigNetwork CONFIG - set hosts array from --host argument (hostArg) or from the specified configuration entry for the current network
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
	
	# initialize
	RunFunction "init" -- "$@" || return

	# commands - format command1Command2Command
	local args=() c shift="1"
	local command commandNames=() commands=() globalArgs=() globalArgsLess=() globalArgsLessForce=() globalArgsLessVerbose=() originalArgs=("$@") otherArgs=() # public

	while (( $# )); do
		local firstCommand="true"; [[ $command ]] && unset firstCommand

		# -- indicates end of arguments
		[[ "$1" == "--" ]] && { shift; otherArgs+=("$@"); break; }

		# continue with next argument if not a valid command name
		! IsValidCommandName "$1" && { args+=("$1"); shift; continue; }

		# first command is lower case (i.e. dhcp), second command is upper case (i.e. dhcpStatus)
		[[ $firstCommand ]] && c="$(LowerCase "$1")" || c="$(ProperCase "$1")"

		# commands that start with 'is' are proper cased after is, i.e. isAvailable

		if [[ "$(LowerCase "$c")}" =~ ^is..* ]]; then
			local prefix="${c:0:2}" suffix="${c#??}"
			[[ $firstCommand ]] && prefix="${prefix,,}" || prefix="$(ProperCase "$prefix")"
			local check="${prefix}$(ProperCase "${suffix}")" # i.e. isAvailble
			IsFunction "${command}${check}Command" && c="$check"
		fi

		# the argument is a command if there is a function for it
		c="${command}${c}Command"	
		if IsFunction "$c"; then
			command="${c%Command}" commands+=("$command") commandNames+=("$(LowerCase "$1")")			
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
	unset -v force forceLess forceLevel noPrompt quiet test showVersion verbose verboseLess verboseLevel wait
	quietOutput="/dev/stdout"

	set -- "${args[@]}"; args=()
	while (( $# )); do
		! IsOption "$1" && { args+=("$1"); shift; continue; }
		ScriptOpt "$@" || return; shift "$shift"		
	done

	# set global options
	globalArgs=($force $noPrompt $quiet $verbose)
	(( forceLevel > 1 )) && forceLess="-$(StringRepeat "f" "$(( forceLevel - 1 ))")"
	(( verboseLevel > 1 )) && verboseLess="-$(StringRepeat "v" "$(( verboseLevel - 1 ))")"
	globalArgsLess=($forceLess $noPrompt $quiet $verboseLess)
	globalArgsLessForce=($forceLess $noPrompt $quiet $verbose)
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
	-f, --force				force the operation, multiple -f increase force (max 3)
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
		EchoWrap "$@"
	fi
}

#
# other
#

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
