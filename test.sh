#!/bin/bash
. function.sh
eval $(bkm SetVars)
printf "a=%s\nb=%s\n" "$a" "$b"
pause
exit $?
