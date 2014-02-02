#!/usr/bin/env bash
#-x (debug) -v (verbose)
. function.sh || exit

usage()
{
	echot "\
usage: unc [explorer|mount](explore) UNC
	Manipulate UNC shares"
	exit $1
}

args()
{
	unset -v unc
	while (( $# != 0 )); do
		case "$1" in
			--help) help="--help";;
			*)
				IsUncPath "$1" && [[ ! $unc ]] && { unc="$1"; shift; continue; }
				UnknownOption "$1"
		esac
		shift
	done
	[[ $help ]] && { IsFunction "${command}Usage" && ${command}Usage 0 || usage 0; }
	[[ ! $command ]] && { command="explore"; }
	[[ ! $unc ]] && MissingOperand "unc"
	args=("$@")
}

init() { :; }
run() {	args "$@" || return; init || return; ${command}Command "${args[@]}"; }

mountCommand()
{
	local dir=$(MountUnc "$unc") || return	
}

exploreCommand()
{
	local dir=$(MountUnc "$unc") || return
	explore "$dir" || return
}

run "$@"
