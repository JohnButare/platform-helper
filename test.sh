#!/bin/bash
. function.sh

foo()
{
	local foo=$foo
	echo $foo
	foo=bar
	echo $foo
}

foo=12
foo
echo $foo