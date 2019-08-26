#!/usr/bin/env bash
. function.sh

usage()
{
	echot "\
usage: os <command>[environment|FindInfo|lock|store|SystemProperties]
	index: index [options|start|stop|demand](options)
	path [show|edit|editor|set [AllUsers]](editor)"
	exit $1
}

args()
{
	command=""
	
	while [ "$1" != "" ]; do
		case "$1" in
			-h|--help) IsFunction "${command}Usage" && ${command}Usage 0 || usage 0;;		
	 		SystemProperties) command="SystemProperties";;
			RenameComputer) command="RenameComputer";;
			*) 
				IsFunction "${1,,}Command" && { command="${1,,}"; shift; continue; }
				[[ "$command" == @(FindDirs|index|path|update) ]] && break
				UnknownOption "$1"
		esac
		shift
	done
	[[ ! $command ]] && usage 1
	args=("$@")
}

run() {	args "$@"; ${command}Command "${args[@]}"; }

indexCommand()
{
	command="options"
	[[ $# > 0 ]] && ProperCase "$1" s; IsFunction Index${s}Command && { command="$s"; shift; }
	[[ $command != @(editor) && $# != 0 ]] && UnknownOption "$1"
	Index${command}Command "$@"
}

IndexOptionsCommand() { start rundll32.exe shell32.dll,Control_RunDLL srchadmin.dll,Indexing Options; }

lockCommand()
{
	case "$PLATFORM" in
		mac) "/System/Library/CoreServices/Menu Extras/User.menu/Contents/Resources/CGSession" -suspend
	esac
}

pathCommand()
{
	command="show"
	[[ $# > 0 ]] && ProperCase "$1" s; IsFunction Path${s}Command && { command="$s"; shift; }
	[[ $command != @(editor) && $# != 0 ]] && UnknownOption "$1"
	Path${command}Command "$@"
}

RenameComputerCommand()
{
	local newName
	read -p "Enter computer name: " newName; echo
	[[ $newName ]] && elevate run --pause-error powershell.exe Rename-Computer -NewName "$newName"
	return 0
}

SystemPropertiesCommand()
{
	local tab=; [[ $1 ]] && tab=",,$1"; 
	start rundll32.exe /d shell32.dll,Control_RunDLL SYSDM.CPL$tab
}

environmentCommand() { SystemPropertiesCommand 3; }
PathEditCommand() { SystemPropertiesCommand 3; }
PathEditorCommand() { start --elevate PathEditor; }
StoreCommand() { start "" "ms-windows-store:"; }

run "$@"
