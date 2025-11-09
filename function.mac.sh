# ProcessIdExists() {	! kill -0 $1 |& grep "No such process" >& /dev/null; } # mac does not return the correct exit code
RestartFinder() { killAll Finder; }
RestartDock() { killall Dock; }

# OpenWaitExists APP - open an application waiting 5 seconds for it to exists
StartWaitExists()
{
	local app="$1" timeoutSeconds=5

	# wait
	[[ ! $quiet ]] && printf "Starting'$app'..."
	for (( i=1; i<=$timeoutSeconds; ++i )); do
		MacAppStart "$app">& /dev/null && return
		ReadChars 1 1 && { echo "cancelled after $i seconds"; return 1; }
		printf "."
	done

	echo "not found"; return 1
}
