#!/bin/bash
. function.sh

usage()
{
	echot "\
usage: os <command>
	FindInfo|FindDirs [HOST|DIR](local)		find OS information or directories
	index: index [options|start|stop|demand](options)
	path [show|edit|editor|update|set [AllUsers]](editor)
	other: ComputerManagement|MobilityCenter|SystemProperties|update"
	exit $1
}

init() { :; }

args()
{
	command='one'
	while [ "$1" != "" ]; do
		case "$1" in
			-h|--help) IsFunction "${command}Usage" && ${command}Usage 0 || usage 0;;
			ComputerManagement) command="ComputerManagement";; FindInfo) command="FindInfo";; FindDirs) command="FindDirs";; MobilityCenter) command="MobilityCenter";; SystemProperties) command="SystemProperties";;
			*) 
				IsFunction "${1,,}Command" && { command="${1,,}"; shift; continue; }
				[[ "$command" == @(FindDirs|index|path) ]] && break
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

indexCommand()
{
	command="options"
	[[ $# > 0 ]] && ProperCase "$1" s; IsFunction Index${s}Command && { command="$s"; shift; }
	[[ $command != @(editor) && $# != 0 ]] && UnknownOption "$1"
	Index${command}Command "$@"
}

IndexOptionsCommand() { start rundll32.exe shell32.dll,Control_RunDLL srchadmin.dll,Indexing Options; }

pathCommand()
{
	command="show"
	[[ $# > 0 ]] && ProperCase "$1" s; IsFunction Path${s}Command && { command="$s"; shift; }
	[[ $command != @(editor) && $# != 0 ]] && UnknownOption "$1"
	Path${command}Command "$@"
}

PathEditCommand() { SystemPropertiesCommand 3; }
PathEditorCommand() { sudo "$@" PathEditor.exe; }

FindDirsCommand()
{
	FindDirsArgs "$@" || return
	GetDirs || return
	ScriptReturn $show "${dirVars[@]}"
}

FindDirsInit()
{
	dirVars=(_sys _data _windows _users _system _system32 _system64 _programs \_programs32 _programs64 \
	 _PublicHome _PublicDocuments _PublicData _PublicBin _PublicDesktop _PublicStartMenu _PuplicPrograms\
	 _user _UserFolders _UserHome _UserSysHome _UserDocuments _UserData _UserBin _UserDesktop _UserStartMenu _UserPrograms
	 _CloudDocuments _CloudData 
	 _ProgramData _ApplicationData _Code )

	for var in "${dirVars[@]}"; do unset $var; done

	_sys="$(wtu "$SYSTEMDRIVE")"
	[[ -d /cygdrive/d/users ]] && _data="/cygdrive/d" || _data="$_sys"
	_user="$USERNAME"
}

FindDirsUsage()
{
	FindDirsInit	
	echot "\
usage: os FindDirs [HOST|DIR]
	Find OS directories for a local or remote host and user.  The variables below are set
	and can be read using \"ScriptEval os FindDirs\"

	HOST|DIR							host or directory to find directories on

	    --no-host-check 	do not check if the host is available				
	-u, --user USER				the user to find directories for
	-s, --show						show the directories found

${dirVars[@]}"
	exit $1
}

FindDirsArgs()
{
	unset host noHostCheck show
	while [ "$1" != "" ]; do
		case "$1" in
			-h|--help) FindDirsUsage 0;;
			   --no-host-check) noHostCheck="true";;
			-s|--show) show="--show";;
			-u|--user) shift; _user="${1-$USER}";;
			*) 
				if [[ ! $host ]]; then
					if [[ "$1" =~ / ]]; then
						[[ ! -d "$1" ]] && { EchoErr "Directory $1 does not exist"; return 1; }
						host="$1"; _sys="$1"; _data="$1"; shift; continue;
					fi
					host="$1"; shift; continue;
				fi
				UnknownOption "$1"
		esac
		shift
	done
	if [[ $host && ! "$host" =~ / && ! $noHostCheck ]]; then	
		! host available "$host" && { EchoErr "Host $host is not available"; return 1; }
	fi
	args=("$@")
}

GetDirs()
{	
	# Alternatively use leverage cygpath -F, see http://www.installmate.com/support/im9/using/symbols/functions/csidls.htm

	FindDirsInit || return

	if [[ ! $host ]]; then # local
		FindDirsWorker || return
		
	elif [[ "$host" == @(nas|nas.hagerman.butare.net|butare.net) ]]; then # nas
		_sys=""; _data=""; 
		[[ "$host" == @(nas|nas.hagerman.butare.net) ]] && _PublicHome="//$host/public" || _PublicHome="//$host@ssl@5006/DavWWWRoot/public"
		SetCommonPublicDirs || return
		
		[[ "$host" == @(nas|nas.hagerman.butare.net) ]] && _UserHome="//$host/home" || _UserHome="//$host@ssl@5006/DavWWWRoot/home"
		_UserFound="$_user"; _UserSysHome="$_UserHome"; _UserDocuments="$_UserHome/documents"
		SetCommonUserDirs || return

	elif [[ "$host" == @(dfs) ]]; then # dfs
		_sys=""; _data=""; 	_PublicHome="//amr.corp.intel.com/corpsvcs/CS-PROD/installdev/public"
		SetCommonPublicDirs || return	

	elif [[ -d "//$host/c$" ]]; then # host with Administrator access
		_sys="//$host/c$"; _data="//$host/c$"
		[[ -d "//$host/d$/Users" ]] && _data="//$host/d$" || 
			{ [[ -d "$_data/Users" ]] || { EchoErr "os: unable to locate the Users folder on $host"; return 1; }; }
		FindDirsWorker || return

	elif [[ -d "//$host/public" ]]; then  # hosts with public share
		_sys=""; _data=""; _PublicHome="//$host/public"
		SetCommonPublicDirs || return
		
	else
		EchoErr "Unable to find os directories on $host"
		return 1

	fi
}

FindDirsWorker()
{
  _windows="$_sys/Windows"
 
	_programs32="$_sys/Program Files (x86)"
	_programs64="$_sys/Program Files"
	_programs="$_programs64"
 	_system32="$_windows/SysWow64"
	_system64="$_windows/system32"
	_system="$_system64"
	_ProgramData="$_sys/ProgramData"

	_Code="$_sys/Projects"

	_users="$_data/Users"

	# public
	_PublicHome="$_users/Public"
	SetCommonPublicDirs
	_PublicStartMenu="$_ProgramData/Microsoft/Windows/Start Menu"
	_PublicPrograms="$_PublicStartMenu/Programs"
	_PublicDesktop="$_PublicHome/Desktop"

	# user	
	_UserHome="$_data/$(GetFileName "$_users")/$_user"
	_UserSysHome="$_sys/$(GetFileName "$_users")/$_user"
	_UserDocuments="$_UserHome/Documents"
	_ApplicationData="$_UserSysHome/AppData/Roaming"

	if [[ "$_user" == "Public" ]]; then
		_UserFolders=(Documents Downloads Music Pictures "Recorded TV" Videos)
	else
		_UserFolders=(Contacts Desktop Documents Downloads Favorites Links Music Pictures "Saved Games" Searches Videos
			Dropbox "Google Drive")
	fi

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

FindInfoCommand()
{
	GetInfo || return
	ScriptReturn $show "${dirVars[@]}" "${infoVars[@]}"
}

GetInfo()
{
	infoVars=( code ao pd pdata pdoc pp pp psm ud udata udoc uhome usm up architecture bits product version client server )

	GetDirs || return

	code="$_Code"

	ao="$_PublicPrograms/Applications/Other"
	pd="$_PublicDesktop"
	pdata="$_PublicData"
	pdoc="$_PublicDocuments"
	pp="$_PublicPrograms"
	psm="$_PublicStartMenu"

	ud="$_UserDesktop"
	udata="$_UserData"
	udoc="$_UserDocuments"
	uhome="$_UserHome"
	usm="$_UserStartMenu"
	up="$_UserPrograms"

	local r="/proc/registry/HKEY_LOCAL_MACHINE/Software/Microsoft/Windows NT/CurrentVersion"
	architecture=$(OsArchitecture)
	bits=64; [[ "$architecture" == "x86" ]] && bits=32;
	product=$(<"$r/ProductName")
	version=$(<"$r/CurrentVersion")
	client=; [[ -f "$r/InstallationType" && $(<"$r/InstallationType") == "client" ]] && client="true"
	server=; [[ ! $client ]] && server="true"

	return 0
}

SystemPropertiesCommand()
{
	local tab=; [[ $1 ]] && tab=",,$1"; 
	start rundll32.exe /d shell32.dll,Control_RunDLL SYSDM.CPL$tab
}

ComputerManagementCommand() { start CompMgmt.msc; }

run "$@"
