#!/usr/bin/env bash
. "${BASH_SOURCE[0]%/*}/function.sh" app color || exit

echo "test BASH script"

i=0
for arg in "$@"; do
	printf 'arg%s=%s\n' "$i" "$arg"
	(( i++ ))
done	