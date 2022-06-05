#!/usr/bin/env bash
. function.sh

i=1 lastSignal=
trap "{ (( i+=1 )); signal=SIGINT; }" SIGINT
trap "{ signal=SIGTERM; }" SIGTERM
trap "echo done" EXIT
echo "pid is $$"

echo -n "waiting..."
while [[ "$(service state ssh)" == "RUNNING" ]]; do
	echo -n .
	[[ ! $signal ]] && sleep 1 &
	wait; result="$?" # return > 128 if interrupted by a signal
	[[ "$signal" == "SIGTERM" ]] && break
	[[ "$signal" == "SIGINT" ]] && { echo -n "signal=$signal i=$i"; unset signal; }
done