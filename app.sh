# common functions for application scripts
. function.sh

shopt -s nocasematch

BatchDir() { echo "$(GetPath "$0")"; }
FunctionExists() { grep -q "$2"'()' "$1"; }
CommandExists() { FunctionExists "$1" "${2}Command" ; }

MissingOperand()
{
	echoerr "$(basename $0): missing $1 operand"
	exit 1
}
