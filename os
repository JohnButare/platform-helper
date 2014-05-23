#!/usr/bin/env bash
. function.sh

usage()
{
	echot "\
usage: os <command>
	FindInfo|FindDirs [HOST|DIR](local)		find OS information or directories
	index: index [options|start|stop|demand](options)
	path [show|edit|editor|update|set [AllUsers]](editor)
	other: ComputerManagement|DeviceManager|MobilityCenter|SystemProperties|update|store
		lock"
	exit $1
}

init() { :; }

args()
{
	command='one'
	while [ "$1" != "" ]; do
		case "$1" in
			-h|--help) IsFunction "${command}Usage" && ${command}Usage 0 || usage 0;;
			ComputerManagement) command="ComputerManagement";; DeviceManager) command="DeviceManager";; FindInfo) command="FindInfo";; FindDirs) command="FindDirs";; MobilityCenter) command="MobilityCenter";; SystemProperties) command="SystemProperties";;
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
	case "$PLATFORM" in
		win)
			echo "Starting Windows Update..."
			if intel IsIntelHost; then intel update; else start "wuapp.exe"; fi

			echo "Starting Update Checker..."
			start "UpdateChecker.exe"

			echo "Starting Cygwin update..."
			cygwin download || return; pause
			cygwin install || return

			;;
		mac)
			brew update || return
			brew upgrade || return
			sudo softwareupdate --install --all || return
			;;
		esac
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
	dirVars=(_platform _root _DataDrive _data _windows _users _etc \
	 _pub _PublicStartMenu _ApplicationData _code \
	 _user _UserFolders _home _SysHome _udata _ubin _UserStartMenu _cloud )

	for var in "${dirVars[@]}"; do unset $var; done
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
						host="$1"; _root="$1"; _DataDrive="$1"; shift; continue;
					fi
					host="$1"; shift; continue;
				fi
				UnknownOption "$1"
		esac
		shift
	done
	if [[ $host && ! "$host" =~ / && ! $noHostCheck ]]; then	
		! HostUtil available "$host" && { EchoErr "Host $host is not available"; return 1; }
	fi
	args=("$@")
}

GetDirs()
{	
	FindDirsInit || return
	
	_user="$USER" _platform="win"

	if [[ ! $host ]]; then # local
		_platform="$PLATFORM" _data="$DATA"
		if [[ "$_platform" == "win" ]]; then
			_root="$(wtu "$SYSTEMDRIVE")"	
			[[ -d /cygdrive/d/users ]] && _DataDrive="/cygdrive/d" || _DataDrive="$_root"
		fi
		FindDirsWorker || return
		
	elif [[ "$host" == @(nas|nas.hagerman.butare.net) ]]; then # nas
		_pub="//$host/public" _home="//$host/home" _SysHome="$_home"; SetCommonUserDirs

	elif [[ "$host" == @(butare.net) ]]; then # nas
		_pub="//$host@ssl@5006/DavWWWRoot/public" _home="//$host@ssl@5006/DavWWWRoot/home"
		_SysHome="$_home"; SetCommonUserDirs

	elif [[ "$host" == @(dfs) ]]; then
		_pub="//amr.corp.intel.com/corpsvcs/CS-PROD/installdev/public"

	elif [[ "$host" == @(cr) ]]; then 
		_pub="//VMSPFSFSCR02.cr.intel.com/CsisInstall/public"

	elif [[ -d "//$host/c$" ]]; then # host with Administrator access
		_root="//$host/c$"; _DataDrive="//$host/c$"
		[[ -d "//$host/d$/Users" ]] && _DataDrive="//$host/d$" || 
			{ [[ -d "$_DataDrive/Users" ]] || { EchoErr "os: unable to locate the Users folder on $host"; return 1; }; }
		FindDirsWorker || return
		_data="$_pub/Documents/data"

	elif [[ -d "//$host/public" ]]; then  # hosts with public share
		_pub="//$host/public"
		_data="$_pub/Documents/data"
		
	else
		EchoErr "Unable to find os directories on $host"
		return 1

	fi
}

FindDirsWorker()
{
	_code="$_root/Projects"
	_users="$_DataDrive/Users"
	_pub="$_users/Shared"
	_etc="$_root/etc"
	_home="$_DataDrive/Users/$_user"
	_SysHome="$_root/Users/$_user"

	case "$_platform" in
		mac)
			_ApplicationData="$_home/Library/Application Support"
			_UserFolders=( Desktop Documents Downloads Dropbox Movies Music Pictures Public sync );;
		win)
			_ApplicationData="$_SysHome/AppData/Roaming"
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
	_ubin="$_udata/bin"
}

FindInfoCommand()
{
	GetInfo || return
	ScriptReturn $show "${dirVars[@]}" "${infoVars[@]}"
}

GetInfo()
{
	infoVars=( pd psm pp ao ud udoc uhome usm up architecture bits product version client server )

	GetDirs || return

	pd="$_pub/Desktop"
	psm="$_PublicStartMenu"
	pp="$_PublicStartMenu/Programs"
	ao="$pp/Applications/Other"

	ud="$_home/Desktop"
	udoc="$_home/Documents"
	uhome="$_home"
	usm="$_UserStartMenu"
	up="$_UserStartMenu/Programs"

	architecture="x64" bits=64 
	client="true"

	if [[ "$_platform" == "win" ]]; then
		local r="/proc/registry/HKEY_LOCAL_MACHINE/Software/Microsoft/Windows NT/CurrentVersion"
		architecture=$(OsArchitecture)
		[[ "$architecture" == "x86" ]] && bits=32;
		product=$(<"$r/ProductName")
		version=$(<"$r/CurrentVersion")
		client=; [[ -f "$r/InstallationType" && $(<"$r/InstallationType") == "client" ]] && client="true"
	fi

	server=; [[ ! $client ]] && server="true"
	return 0
}

SystemPropertiesCommand()
{
	local tab=; [[ $1 ]] && tab=",,$1"; 
	start rundll32.exe /d shell32.dll,Control_RunDLL SYSDM.CPL$tab
}

lockCommand()
{
	case "$PLATFORM" in
		mac) "/System/Library/CoreServices/Menu Extras/User.menu/Contents/Resources/CGSession" -suspend
	esac
}

ComputerManagementCommand() { start CompMgmt.msc; }
DeviceManagerCommand() { start DevMgmt.msc; }
StoreCommand() { start "" "ms-windows-store:"; }

run "$@"
