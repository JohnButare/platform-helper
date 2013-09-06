# common functions for application scripts
. function.sh

BatchDir() { echo "$(GetPath "$(FindInPath "$0")")"; }
FunctionExists() { grep -q "$2"'()' "$1"; } # FunctionExists <function> <file> - function exists in file
CommandExists() { FunctionExists "$1" "${2}Command" ; } # CommandExists <command> <app> - application supports command
