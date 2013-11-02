#!/bin/bash
. function.sh
eval "$@" # allow multiple commands, i.e. "sudo RunMultiple.sh 'ls; pause'"
exit $?
