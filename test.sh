#!/usr/bin/env bash
. function.sh || exit
echo $1
if [[ $1 == 1 ]]; then ls /dfhg
elif [[ $1 == 2 ]]; then echo good
fi

echo $?