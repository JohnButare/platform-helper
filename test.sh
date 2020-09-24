#!/usr/bin/env bash
. function.sh || exit

IFS=$'\n' files=( $(drive mounts) )
for file in "${files[@]}"; do
	echo -"$file"-
done