#!/usr/bin/env zsh
. "${ZSH_SCRIPT%/*}/function.sh" app script color || exit
SourceIfExists "$ZPLUG_REPOS/mafredri/zsh-async/async.zsh" || exit

echo "test ZSH script"

if [[ $ZSH_NAME ]]; then
	alias help="run-help"
fi

ReadChars() # ReadChars N [SECONDS] [MESSAGE] - silently read N characters into the response variable optionally waiting SECONDS
{ 
	local result n="${1:-1}" t m="$3"; [[ $2 ]] && t=( -t $2 ) # must be an array in zsh

	[[ $m ]] && printf "$m"

	if [[ $ZSH_NAME ]]; then # single line statement fails in zsh
		read -s -k $n ${t[@]} "response"
	else
		read -n $n -s ${t[@]} response
	fi
	result="$?"

	[[ ! $ZSH_NAME && $m ]] && echo

	return "$result"
}

pause() { local response m="${@:-Press any key when ready...}"; ReadChars "" "" "$m"; }

SleepStatus() # SleepStatus SECONDS
{
	printf "Waiting for $1 seconds..."
	for (( i=1; i<=$1; ++i )); do
 		ReadChars 1 1 && { echo "cancelled after $i seconds"; return 1; }
		printf "."
	done

	echo "done"
}
