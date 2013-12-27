#!/usr/bin/env bash
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
	dirVars=(_platform _data _windows _users _etc \
	 _pub _PublicStartMenu _ApplicationData _code \
	 _user _UserFolders _home _UserSysHome _udata _UserStartMenu _cloud )

	for var in "${dirVars[@]}"; do unset $var; done

	_platform="$PLATFORM" _root="" _data="" _user="$USER"
	if [[ "$_platform" == "win" ]]; then
		_root="$(wtu "$SYSTEMDRIVE")"	
		[[ -d /cygdrive/d/users ]] && _data="/cygdrive/d" || _data="$_root"
	fi
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
						host="$1"; _root="$1"; _data="$1"; shift; continue;
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
		
	elif [[ "$host" == @(nas|nas.hagerman.butare.net) ]]; then # nas
		_root="" _data="" _pub="//$host/public" _home="//$host/home" 
		_UserSysHome="$_home"; SetCommonUserDirs || return

	elif [[ "$host" == @(butare.net) ]]; then # nas
		_root="" _data="" _pub="//$host@ssl@5006/DavWWWRoot/public" _home="//$host@ssl@5006/DavWWWRoot/home"
		_UserSysHome="$_home"; SetCommonUserDirs || return

	elif [[ "$host" == @(dfs) ]]; then
		_root""; _data=""; _pub="//amr.corp.intel.com/corpsvcs/CS-PROD/installdev/public"

	elif [[ "$host" == @(cr) ]]; then 
		_root""; _data=""; _pub"//VMSPFSFSCR02.cr.intel.com/CsisInstall/public"

	elif [[ -d "//$host/c$" ]]; then # host with Administrator access
		_root="//$host/c$"; _data="//$host/c$"
		[[ -d "//$host/d$/Users" ]] && _data="//$host/d$" || 
			{ [[ -d "$_data/Users" ]] || { EchoErr "os: unable to locate the Users folder on $host"; return 1; }; }
		FindDirsWorker || return

	elif [[ -d "//$host/public" ]]; then  # hosts with public share
		_root=""; _data=""; _pub="//$host/public"
		
	else
		EchoErr "Unable to find os directories on $host"
		return 1

	fi
}

FindDirsWorker()
{
	_code="$_root/Projects"
	_users="$_data/Users"
	_pub="$_users/Shared"
	_etc="$_root/etc"
	_home="$_data/Users/$_user"
	_UserSysHome="$_root/Users/$_user"

	case "$_platform" in
		mac)
			_ApplicationData="$_home/Library/Application Support"
			_UserFolders=( Desktop Documents Downloads Dropbox Movies Music Pictures Public sync );;
		win)
			_ApplicationData="$_UserSysHome/AppData/Roaming"
			_etc="$_root/Windows/system32/drivers/etc"
			_pub="$_users/Public"
			_PublicStartMenu="$_root/ProgramData/Microsoft/Windows/Start Menu"
			_UserFolders=( Desktop Documents Downloads Music Pictures Videos )
			[[ "$_user" != "Public" ]] && _UserFolders+=( Contacts Dropbox Favorites "Google Drive" Links "Saved Games" Searches )
		 	_windows="$_root/Windows";;
	esac

	SetCommonUserDirs
	_UserStartMenu="$_ApplicationData/Microsoft/Windows/Start Menu"
}

SetCommonUserDirs()
{
	_cloud="$_home/Dropbox"
	_udata="$_home/Documents/data"
}

FindInfoCommand()
{
	GetInfo || return
	ScriptReturn $show "${dirVars[@]}" "${infoVars[@]}"
}

GetInfo()
{
	infoVars=( code data pd psm pp ao ud udata udoc uhome usm up architecture bits product version client server )

	GetDirs || return

	code="$_code"
	data="$_data"

	pd="$_pub/Desktop"
	psm="$_PublicStartMenu"
	pp="$_PublicStartMenu/Programs"
	ao="$pp/Applications/Other"

	ud="$_home/Desktop"
	udata="$_udata"
	udoc="$_home/Documents"
	uhome="$_home"
	usm="$_UserStartMenu"
	up="$_UserStartMenu/Programs"

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
