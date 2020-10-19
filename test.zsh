#!/usr/bin/env zsh
. function.sh || exit
. $ZPLUG_REPOS/mafredri/zsh-async/async.zsh

async_init

# Initialize a new worker (with notify option)
async_start_worker my_worker -n

# Create a callback function to process results
COMPLETED=0
completed_callback() {
	COMPLETED=$(( COMPLETED + 1 ))
	print $@
}

# Register callback function for the workers completed jobs
async_register_callback my_worker completed_callback

# Give the worker some tasks to perform
async_job my_worker print hello
async_job my_worker sleep 0.3

# Wait for the two tasks to be completed
while (( COMPLETED < 2 )); do
	print "Waiting..."
	sleep 0.1
done

print "Completed $COMPLETED tasks!"

# Output:
#	Waiting...
#	print 0 hello 0.001583099365234375
#	Waiting...
#	Waiting...
#	sleep 0 0.30631208419799805
#	Completed 2 tasks!