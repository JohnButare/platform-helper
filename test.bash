#!/usr/bin/env bash
. "${BASH_SOURCE[0]%/*}/function.sh" app color || exit

header "Test BASH Script"

#
# local variables
#

alias setVars='local vars=(var1 var2); local "${vars[@]}";'

testVars()
{
    setVars
    var1="value1" var2="value2"
    echo "testVars: var1=$var1 var2=$var2"
    testVars2
}

testVars2() { echo "testVars2: var1=$var1 var2=$var2"; }

testArguments()
{
	i=0
	for arg in "$@"; do
		printf 'arg%s=%s\n' "$i" "$arg"
		(( i++ ))
	done
}

# testArguments
testVars; echo "main: var1=$var1 var2=$var2"
