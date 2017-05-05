#!/usr/bin/env bash
. function.sh
# allow multiple commands, i.e. "sudo run.sh 'ls; pause'", where can't use bash -c
declare multiple; [[ $1 == @(--multiple|-m) ]] && { multiple="true"; shift; }
[[ $multiple ]] && eval "$@" || "$@"

