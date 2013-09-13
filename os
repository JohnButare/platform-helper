#!/bin/bash
. function.sh

usage()
{
	echot "\
usage: os <command>
	update|
	FindDirs [host](local)		find OS directories
	path [show|edit|editor|update|set [AllUsers]](editor)"
	exit $1
}

init() { :; }

args()
{
	unset var
	command='one'
	while [ "$1" != "" ]; do
		case "$1" in
			-h|--help) IsFunction "${command}Usage" && ${command}Usage 0 || usage 0;;
			FindDirs) command="FindDirs";; # case-insensitive aliases
			*) 
				IsFunction "${1,,}Command" && { command="${1,,}"; shift; continue; }
				[[ "$command" == @(FindDirs|path) ]] && break
				UnknownOption "$1"
		esac
		shift
	done
	[[ ! $command ]] && usage 1
	args=("$@")
}

run() {	init; args "$@"; ${command}Command "${args[@]}"; }

updateCommand()
{
	echo "Starting Windows Update..."
	start "wuapp.exe"

	echo "Starting Update Checker..."
	start "UpdateChecker.exe"
}

pathCommand()
{
	command="show"
	[[ $# > 0 ]] && ProperCase "$1" s; IsFunction Path${s}Command && { command="$s"; shift; }
	[[ $# != 0 ]] && UnknownOption "$1"
	Path${command}Command "$@"
}

PathEditorCommand() { sudo PathEditor.exe; }

FindDirsUsage()
{
	FindDirsInit	
	echot "\
usage: os FindDirs [<host>](local)
	Find OS directories for a local or remote host and user.  The variables below are set
	and can be read using \"ScriptEval os FindDirs\"

	<host>												host to use to find directories
	-s,--show											show the directories found
	-u,--user [<user>](current)		the user to find directories for

${vars[@]}"
	echo $1
}

# leverage cygpath -F? http://www.installmate.com/support/im9/using/symbols/functions/csidls.htm
FindDirsCommand()
{
	FindDirsInit
	FindDirsArgs "$@"

	if [[ ! $host ]]; then
		FindDirsWorker
		
	elif [[ "$host" == "butare.net" ]]; then # nas external
		_sys=""
		_data=""
		_PublicHome="//%host@ssl@5006/public"
		SetPublicDirs
		
		_UserHome="//$host@ssl@5006/home"
		_UserSysHome="$_UserHome"
		_UserDocuments="$_UserHome/documents"
		SetUserDirs
	
	elif [[ -d "//$host/c$" ]]; then # Windows hosts
		_sys="//$host/c$"
		_data="//$host/c$"
		[[ -d "//$host/d$/Users" ]] && _data="//$host/d$"
		FindDirsWorker

	elif [[ -d "//$host/public" ]]; then # nas internal
		_sys=""
		_data=""
		_PublicHome="//$host/public"
		SetPublicDirs
		
		if [[ -d "//$host/home" ]]; then
			_UserFound="$_user"
			_UserHome="//$host/home"
			_UserSysHome="$_UserHome"
			_UserDocuments="$_UserHome/Documents"
			SetUserDirs
		fi

	else
		EchoErr "Unable to find os directories on $host"
		FindDirsExit

	fi

	ScriptReturn $show "${vars[@]}"
}

FindDirsExit() { [[ ! $show ]] && echo "false"; exit 1; }

FindDirsWorker()
{
  _windows="$_sys/Windows"

  if [[ ! -d "$_windows" ]]; then
  	EchoErr "Unable to locate the windows folder on %_sys"
  	FindDirsExit
  fi;

	_programs32="$_sys/Program Files (x86)"
	_programs64="$_sys/Program Files"
	_programs="$_programs64"
 	_system32="$_windows/SysWow64"
	_system64="$_windows/system32"
	_system="$_system64"
	_ProgramData="$_sys/ProgramData"

	_LocalCode="$_sys/Projects"

	_users="$_data/Users"
	_PublicHome="$_users/Public"
	_UserHome="$_data/$(GetFilename "$_users")/$_user"
	_UserSysHome="$_sys/$(GetFilename "$_users")/$_user"
	_UserDocuments="$_UserHome/Documents"
	_ApplicationData="$_UserSysHome/AppData/Roaming"

	if [[ ! -d "$_UserHome" ]]; then
		EchoErr "Unable to locate user $_user$'s home folder on $_data"
	  FindDirsExit
	fi
	
	if [[ "$_user" == "Public" ]]; then
		_UserFolders=(Documents Downloads Music Pictures "Recorded TV" Videos)
	else
		_UserFolders=(Contacts Desktop Documents Downloads Favorites Links Music Pictures "Saved Games" Searches Videos
			Dropbox "Google Drive")
	fi

	SetPublicDirs
	SetUserDirs
}

SetPublicDirs()
{
	_PublicDocuments="$_PublicHome/documents"
	_PublicData="$_PublicDocuments/data"
	_PublicBin="$_PublicData/bin"
}

SetUserDirs()
{
	_CloudDocuments="$_UserHome/Dropbox"
	_CloudData="$_CloudDocuments/data"
	_UserData="$_UserDocuments/data"
	_UserBin="$_UserData/bin"
}

FindDirsArgs()
{
	unset host show
	while [ "$1" != "" ]; do
		case "$1" in
			-h|--help) FindDirsUsage 0;;
			-s|--show) show="--show";;
			-u|--user) shift; _user="${1-$USER}";;
			*) 
				if [[ ! $host ]]; then
					[[ -d "$1" ]] && { host="$1"; _sys="$1"; _data="$1"; shift; continue; }
					host available "$1" && { host="$1"; shift; continue; }
				fi
				EchoErr "Unknown argument $1"; usage 1;
		esac
		shift
	done
	[[ ! $command ]] && FindDirsUsage 1
	args=("$@")
}

FindDirsInit()
{
	vars=(_layout _sys _data _windows _users _system _system32 _system64 _programs _programs32 _programs64 _PublicHome _PublicDocuments _PublicData _PublicBin _user _UserHome _UserSysHome _UserDocuments _UserData _UserBin _CloudDocuments _CloudData _ProgramData _ApplicationData _LocalCode _UserFolders)
	for var in "${vars[@]}"; do unset $var; done

	_sys="$(wtu "$SYSTEMDRIVE")"
	[[ -d /cygdrive/d ]] && _data="d:" || _data="$_sys"
	_user="$USERNAME"
}

run "$@"
