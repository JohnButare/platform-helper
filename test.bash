#!/usr/bin/env bash
. "${BASH_SOURCE[0]%/*}/function.sh" app color || exit

header "Test BASH Script"
echo BASH_VERSION=$BASH_VERSION

i=0
for arg in "$@"; do
	printf 'arg%s=%s\n' "$i" "$arg"
	(( i++ ))
done

seconds=0
while true; do
	sleep 1
	echo "the service has been running for $seconds seconds"
	(( seconds+=1 ))
done
