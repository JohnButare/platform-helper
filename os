#!/bin/bash
. function.sh

usage()
{
	echot "\
usage: os <command>
	FindInfo|FindDirs [HOST|DIR](local)		find OS information or directories
	path [show|edit|editor|update|set [AllUsers]](editor)"
	other: MobilityCenter|SystemProperties|update
	exit $1
}

init() { :; }

args()
{
	command='one'
	while [ "$1" != "" ]; do
		case "$1" in
			-h|--help) IsFunction "${command}Usage" && ${command}Usage 0 || usage 0;;
			FindInfo) command="FindInfo";; FindDirs) command="FindDirs";; MobilityCenter) command="MobilityCenter";; # case-insensitive aliases
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
MobilityCenterCommand() { start mblctr.exe; }

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
	[[ $command != @(editor) && $# != 0 ]] && UnknownOption "$1"
	Path${command}Command "$@"
}

PathEditCommand() { SystemPropertiesCommand 3; }
PathEditorCommand() { sudo "$@" PathEditor.exe; }

FindDirsUsage()
{
	FindDirsInit	
	echot "\
usage: os FindDirs [HOST|DIR](local)
	Find OS directories for a local or remote host and user.  The variables below are set
	and can be read using \"ScriptEval os FindDirs\"

	<host>												host to use to find directories
	-s,--show											show the directories found
	-u,--user [<user>](current)		the user to find directories for

${dirVars[@]}"
	echo $1
}

FindDirsCommand()
{
	FindDirsArgs "$@" || return
	GetDirs || return
	ScriptReturn $show "${dirVars[@]}"
}

# TODO: leverage cygpath -F? http://www.installmate.com/support/im9/using/symbols/functions/csidls.htm
GetDirs()
{	
	FindDirsInit || return

	if [[ ! $host ]]; then
		FindDirsWorker || return
		
	elif [[ "$host" == "butare.net" ]]; then # nas external
		_sys=""
		_data=""
		_PublicHome="//%host@ssl@5006/public"
		SetCommonPublicDirs
		
		_UserHome="//$host@ssl@5006/home"
		_UserSysHome="$_UserHome"
		_UserDocuments="$_UserHome/documents"
		SetCommonUserDirs
	
	elif [[ -d "//$host/c$" ]]; then # Windows hosts
		_sys="//$host/c$"
		_data="//$host/c$"
		[[ -d "//$host/d$/Users" ]] && _data="//$host/d$"
		FindDirsWorker || return

	elif [[ -d "//$host/public" ]]; then # nas internal
		_sys=""
		_data=""
		_PublicHome="//$host/public"
		SetCommonPublicDirs
		
		if [[ -d "//$host/home" ]]; then
			_UserFound="$_user"
			_UserHome="//$host/home"
			_UserSysHome="$_UserHome"
			_UserDocuments="$_UserHome/Documents"
			SetCommonUserDirs
		fi

	else
		EchoErr "Unable to find os directories on $host"
		return 1

	fi
}

FindDirsWorker()
{
  _windows="$_sys/Windows"

  if [[ ! -d "$_windows" ]]; then
  	EchoErr "Unable to locate the windows folder on %_sys"
  	return 1
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
	  return 1
	fi
	
	if [[ "$_user" == "Public" ]]; then
		_UserFolders=(Documents Downloads Music Pictures "Recorded TV" Videos)
	else
		_UserFolders=(Contacts Desktop Documents Downloads Favorites Links Music Pictures "Saved Games" Searches Videos
			Dropbox "Google Drive")
	fi

	SetCommonPublicDirs
	_PublicStartMenu="$_ProgramData/Microsoft/Windows/Start Menu"
	_PublicPrograms="$_PublicStartMenu/Programs"
	_PublicDesktop="$_PublicHome/Desktop"
	
	SetCommonUserDirs
	_UserDesktop="$_UserHome/Desktop"
	_UserStartMenu="$_ApplicationData/Microsoft/Windows/Start Menu"
	_UserPrograms="$_UserStartMenu/Programs"
}

SetCommonPublicDirs()
{
	_PublicDocuments="$_PublicHome/documents"
	_PublicData="$_PublicDocuments/data"
	_PublicBin="$_PublicData/bin"
}

SetCommonUserDirs()
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
					if [[ "$1" =~ / ]]; then
						[[ ! -d "$1" ]] && { EchoErr "Directory $1 does not exist"; return 1; }
						host="$1"; _sys="$1"; _data="$1"; shift; continue;
					fi
					! host available "$1" && { EchoErr "Host $1 is not available"; return 1; }
					host="$1"; shift; continue;
				fi
				EchoErr "Unknown argument $1"; FindDirsUsage 1;
		esac
		shift
	done
	[[ ! $command ]] && FindDirsUsage 1
	args=("$@")
}

FindDirsInit()
{
	dirVars=(_sys _data _windows _users _system _system32 _system64 _programs \_programs32 _programs64 \
	 _PublicHome _PublicDocuments _PublicData _PublicBin _PublicDesktop _PublicStartMenu _PuplicPrograms\
	 _user _UserFolders _UserHome _UserSysHome _UserDocuments _UserData _UserBin _UserDesktop _UserStartMenu _UserPrograms
	 _CloudDocuments _CloudData 
	 _ProgramData _ApplicationData _LocalCode )

	for var in "${dirVars[@]}"; do unset $var; done

	_sys="$(wtu "$SYSTEMDRIVE")"
	[[ -d /cygdrive/d/users ]] && _data="/cygdrive/d" || _data="$_sys"
	_user="$USERNAME"
}

FindInfoCommand()
{
	GetInfo || return
	ScriptReturn $show "${dirVars[@]}" "${infoVars[@]}"
}

GetInfo()
{
	infoVars=( psm pp pd ao usm up ud architecture product version client server mobile vm)

	GetDirs || return

	psm="$_PublicStartMenu"
	pp="$_PublicPrograms"
	pd="$_PublicDesktop"
	ao="$_PublicPrograms/Applications/Other"

	usm="$_UserStartMenu"
	up="$_UserPrograms"
	ud="$_UserDesktop"

	local r="/proc/registry/HKEY_LOCAL_MACHINE/Software/Microsoft/Windows NT/CurrentVersion"
	architecture=$(OsArchitecture)
	product=$(<"$r/ProductName")
	version=$(<"$r/CurrentVersion")
	client=; [[ $(<"$r/InstallationType") == "client" ]] && client="true"
	server=; [[ ! $client ]] && server="true"
	mobile=; [[ "$(host info "$COMPUTERNAME" mobile)" == "yes" ]] && mobile="true"
	vm=; ! vmchk > /dev/null && vm="true"

	return 0
}

SystemPropertiesCommand()
{
	local tab=; [[ $1 ]] && tab=",,$1"; 
	start rundll32.exe /d shell32.dll,Control_RunDLL SYSDM.CPL$tab
}

run "$@"
