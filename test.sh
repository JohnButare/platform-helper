#!/bin/bash

a()
{
	local -A foo
	foo[one]="two"
	echo ${foo[one]}
}

a
echo ${foo[one]}