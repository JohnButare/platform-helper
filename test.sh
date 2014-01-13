#!/usr/bin/env bash

foo()
{
	return $1
}

bar()
{
	foo $1; local result=$?; echo $? 
}

bar "$@"