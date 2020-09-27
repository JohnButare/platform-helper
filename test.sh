#!/usr/bin/env bash
. function.sh || exit

IFS=$'\n' files=( $(drive list) )
for file in "${files[@]}"; do
	echo -"$file"-
done