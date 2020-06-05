#!/usr/bin/env bash
. function.sh || exit

a()
{
	local {a,b,c}=13
	echo $a-$b-$c
}

a