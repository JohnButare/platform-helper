# mac does not return the correct exit code
ProcessIdExists() {	! kill -0 $1 |& grep "No such process" >& /dev/null; }
RestartFinder() { killAll Finder; }
RestartDock() { killall Dock; }