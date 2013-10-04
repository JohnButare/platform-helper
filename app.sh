# common functions for application scripts
. function.sh

FunctionExists() { grep -q "$1"'()' "$2"; } # FunctionExists FUNCTION FILE - function exists in file
CommandExists() { FunctionExists "${1}Command" "$2" ; } # CommandExists COMMAND APP - application supports command

AppStart() { AppCommand start "$1"; }
AppClose() { AppCommand close "$1"; }
	
AppCommand() # AppCommand COMMAND APP - execute COMMAND on APP if exists
{
	local command="$1" app="$2" appPath
	appPath="$(FindInPath "$app")" || return
	CommandExists "$command" "$appPath" && { "$app" "$command" || return; }
	return 0
}
