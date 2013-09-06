#!/bin/bash
. function.sh


a()
{
	local field
	field=2
	echo "field=\"$field\""
}

field=12
a
echo $field
