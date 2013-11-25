#!/bin/bash

a()
{
	foo=( [a]=1 [b]=2 )
}

b()
{
	bar=12
	local -A foo
	a
	echo A${foo[a]}
}

b
echo ${foo[a]}
echo $bar