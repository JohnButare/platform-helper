#!/usr/bin/env bash
. function.sh

usage()
{
	echot "\
usage: os <command>
	FindInfo|FindDirs [HOST|DIR](local)		find OS information or directories
	index: index [options|start|stop|demand](options)
	path [show|edit|editor|update|set [AllUsers]](editor)
	other: ComputerManagement|DeviceManager|environment|EventViewer|MobilityCenter|SystemProperties|update|store
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
			ComputerManagement) command="ComputerManagement";; DeviceManager) command="DeviceManager";;
			FindInfo) command="FindInfo";; FindDirs) command="FindDirs";; MobilityCenter) command="MobilityCenter";;
	 		SystemProperties) command="SystemProperties";; CredentialManagement) command="CredentialManagement";;
			EventViewer) command="EventViewer";; RenameComputer) command="RenameComputer";;
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

run() {	init; args "$@"; ${command}Command "${args[@]}"; }
MobilityCenterCommand() { start mblctr.exe; }
EventViewerCommand() { start eventvwr.msc; }

updateCommand()
{
	if [[ $# == 1 ]]; then
		cmd="$(GetFunction ${1}Update)"
		[[ ! $cmd ]] && usage
		$cmd; return
	fi

	[[ $# != 0 ]] && usage;

	HostUtil available nas1 && ask "Bin directories update" && { BinUpdate || return; }
	ask "Syncronize local files" && { FilesUpdate || return; }

	case "$PLATFORM" in
		
		win)
			intel IsIntelHost && { intel update || return; }
			! intel IsIntelHost && ask "Windows update" && { WindowsUpdate || return; }
			
			[[ -f "$P32/Secunia/PSI/psi.exe" ]] && ask "Software update" && { CheckerUpdate || return; }
			ask "Cygwin update" && { CygwinUpdate || return; }

			;;

		mac)
			ask "Brew update" && { BrewUpdate || return; }
			ask "App Store update" && sudo softwareupdate --install --all
			;;

	esac

	which gem >& /dev/null && ask "Ruby update" && { RubyUpdate || return; }
	
	[[ "$PLATFORM" != "mac" ]] &&  # OS X causes issues with pip
		which pip >& /dev/null && ask "Python update" && { PythonUpdate || return; }

	[[ "$PLATFORM" != "mac" ]] && ask "Cleanup windows" && { inst --no-run CleanupWin || return; }
}

CheckerUpdate() { start "$P32/Secunia/PSI/psi.exe"; }
CygwinUpdate() { cygwin new; }
WindowsUpdate() 
{
	FindInPath "wuapp.exe" > /dev/null && start "wuapp.exe" || cmd /c start ms-settings:windowsupdate
}

FilesUpdate()
{
	HostUtil available nas1 && { SyncLocalFiles nas1 || return; }
	
	if intel OnIntelNetwork; then
		ask 'Synchronize CsisBuild local files' && { SyncLocalFiles CsisBuild.intel.com || return; }
		ask 'Synchronize CsisBuild-dr local files' && { SyncLocalFiles CsisBuild-dr.intel.com || return; }
	fi

	return 0
}

BrewUpdate()
{
	brew update || return
	brew upgrade || return
}

RubyUpdate()
{	
	local sudo nodoc

	[[ "$PLATFORM" == "mac" ]] && { sudo=sudo; export PATH="/usr/local/opt/ruby/bin:$PATH"; }

	# for Windows do not generate documentation, faster and --system fails with documentation update on Cygwin
	[[ "$PLATFORM" == "win" ]] && nodoc=--no-document

	intel IsIntelHost && ScriptEval intel SetProxy
	
	$sudo gem update --system $nodoc
	$sudo gem update $nodoc
	return 0
}

PythonUpdate()
{
	intel IsIntelHost && ScriptEval intel SetProxy
	
	pip list --outdated --format=columns
	for pkg in $( pip list --outdated --format=columns | cut -d' ' -f 1 | tail --lines=+3 );	do
    pip install $ignoreInstalled -U $pkg || return
	done

	return 0
}

BinUpdate()
{
	GitHelper changes "$BIN" && { GitHelper commitg "$BIN" && pause; }
	cd "$BIN" && git pull
	GitHelper changes "$UBIN" && { GitHelper commitg "$UBIN" && pause; }
	cd "$UBIN" && git pull
	return 0
}

indexCommand()
{
	command="options"
	[[ $# > 0 ]] && ProperCase "$1" s; IsFunction Index${s}Command && { command="$s"; shift; }
	[[ $command != @(editor) && $# != 0 ]] && UnknownOption "$1"
	Index${command}Command "$@"
}

IndexOptionsCommand() { start rundll32.exe shell32.dll,Control_RunDLL srchadmin.dll,Indexing Options; }

RenameComputerCommand()
{
	local newName
	read -p "Enter computer name: " newName; echo
	[[ $newName ]] && "$WINDIR/system32/wbem/wmic" computersystem where caption=\"$COMPUTERNAME\" rename \"$newName\"
	return 0
}

pathCommand()
{
	command="show"
	[[ $# > 0 ]] && ProperCase "$1" s; IsFunction Path${s}Command && { command="$s"; shift; }
	[[ $command != @(editor) && $# != 0 ]] && UnknownOption "$1"
	Path${command}Command "$@"
}

environmentCommand() { SystemPropertiesCommand 3; }
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
			[[ -d "/cygdrive/d/Program Files" ]] && _DataDrive="/cygdrive/d" || _DataDrive="$_root"
		fi
		FindDirsWorker || return
		
	elif [[ "$host" == @(nas) ]]; then # nas
		_pub="//$host/public" _home="//$host/home" _SysHome="$_home"; SetCommonUserDirs
		_data="$_pub/Documents/data"

	elif [[ "$host" == @(nas1|nas2) ]]; then # nas
		_pub="//$host/public" _home="//$host/home" _SysHome="$_home"; SetCommonUserDirs
		_data="$_pub/Documents/data"

	elif [[ "$host" == @(butare.net) ]]; then # nas
		_pub="//$host@ssl@5006/DavWWWRoot/public" _home="//$host@ssl@5006/DavWWWRoot/home"
		_SysHome="$_home"; SetCommonUserDirs

	elif [[ "$host" == @(dfs) ]]; then
		_pub="//amr.corp.intel.com/corpsvcs/CS-PROD/installdev/public"

	elif [[ "$host" == @(cr) ]]; then 
		_pub="//VMSPFSFSCR02.cr.intel.com/CsisInstall/public"

	elif [[ -d "//$host/c$" ]]; then # host with Administrator access
		_root="//$host/c$"; _DataDrive="//$host/c$"
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
	_users="$_root/Users"
	_pub="$_users/Shared"
	_etc="$_root/etc"
	_home="$_root/Users/$_user"
	_SysHome="$_root/Users/$_user"

	case "$_platform" in
		mac)
			_ApplicationData="$_home/Library/Application Support"
			_UserFolders=( Desktop Documents Downloads Dropbox Movies Music Pictures Public sync )
			;;
		win)
			_ApplicationData="$_SysHome/AppData/Roaming"
			_etc="$_root/Windows/system32/drivers/etc"
			_pub="$_users/Public"
			_PublicStartMenu="$_root/ProgramData/Microsoft/Windows/Start Menu"
			_UserFolders=( Desktop Documents Downloads Music Pictures Videos )
			[[ "$_user" != "Public" ]] && _UserFolders+=( Contacts Dropbox Favorites "Google Drive" Links "Saved Games" Searches )
		 	_windows="$_root/Windows"
		 	;;
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
	GetDirs || return

	infoVars=( pd ud udoc uhome )
	pd="$_pub/Desktop"
	ud="$_home/Desktop"
	udoc="$_home/Documents"
	uhome="$_home"

	if [[ "$_platform" == "win" ]]; then
		infoVars+=( psm pp ao usm up )
		psm="$_PublicStartMenu"
		pp="$_PublicStartMenu/Programs"
		ao="$pp/Applications/Other"
		usm="$_UserStartMenu"
		up="$_UserStartMenu/Programs"
	fi

	if [[ "$_platform" == "mac" ]]; then
		infoVars+=( si la ula )
		si="/Library/StartupItems"
		la="/Library/LaunchAgents"
		ula="$HOME/Library/LaunchAgents"
	fi

	infoVars+=( architecture bits product version client server )
	architecture="x64" bits=64 client="true"
	if [[ "$_platform" == "win" ]]; then
		local r="/proc/registry/HKEY_LOCAL_MACHINE/Software/Microsoft/Windows NT/CurrentVersion"
		architecture=$(OsArchitecture)
		[[ "$architecture" == "x86" ]] && bits=32;
		product=$(tr -d '\000' < "$r/ProductName")
		version="10.0"; [[ "$product" != Windows\ 10* ]] && version=$(tr -d '\000' < "$r/CurrentVersion"); 
		client=; [[ -f "$r/InstallationType" && $(tr -d '\000' < "$r/InstallationType") == "client" ]] && client="true"
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

cmCommand() { ComputerManagementCommand; }; ComputerManagementCommand() { start CompMgmt.msc; }
dmCommand() { DeviceManagerCommand; };  DeviceManagerCommand() { start DevMgmt.msc; }
credmCommand() { CredentialManagementCommand; }; CredentialManagementCommand() { start control /name Microsoft.CredentialManager; } # rundll32.exe keymgr.dll, KRShowKeyMgr
StoreCommand() { start "" "ms-windows-store:"; }

run "$@"
