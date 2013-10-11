#!/bin/bash


:studio
:profiler

RunAs=
if "$1" == "AD"; then
  RunAs=true
  shift
fi

if "$1" == "express"; then
	arguments=/S./sqlexpress
	shift
elif "$1" == "local"; then
	arguments=/Slocalhost
	shift
fi

if defined RunAs; then
  runas /user:amr/ad_$UserName "$program" $arguments $$
else
  start /pgm "$program" $arguments $$
fi

return

:config
start /pgm "$configManager"
return

:rsConfig

if IsFile "$rsConfig"; then
	start /pgm "$rsConfig"
	return 0
fi

return 1

:log
cde "$programs/Microsoft SQL Server/MSSQL.1/MSSQL/LOG"
return

:CheckInstance [name]
return $@if[ IsDir "$data/Program Files/Microsoft SQL Server/MSSQL$dataVersionNum.$name/MSSQL/Data" ,0,1]

:ExecuteSql

if IsFile "$sqlStudio"; then
	start /pgm "$sqlStudio" $$
else

	if $# == 0 goto usage
	file=$1

	echo Executing SQL statements contained in $@FileName[$file]...
	
	type $@quote[$file] > clip:
	pause Use a SQL query tool to execute the contents of the clipboard; then press any key when ready...
	
fi

return

:backup

REM Arguments

if $@IsHelpArg[$@UnQuote[$1]] == 1 goto UsageDbBackup

if $# == 0 goto usage
database=$1
shift

BakFile=$database.bak
if $# gt 0 .and. $@IsHostAvailable[$1] == 0; then
	BakFile=$@UnQuote[$1]
	shift
fi

gosub CheckHost
if $_? != 0 return $_?

if $# != 0 goto usage

REM Validate

REM If BakFile refers to a directory add the default filename
if [[ -d "$BakFile"; then
	BakFile=$BakFile/$database.bak
fi

REM Add a bak extension if not present
if "$@ext["$BakFile"]" != "bak"; then
	BakFile=$BakFile.bak
fi

REM Check if the backup file already exists
if IsFile "$BakFile.7z"; then
	echo $BakFile.7z already exists.
	return 1
fi

gosub VerifysqlCmd
if $_? != 0 return $_?

gosub HostPrepare
if $_? != 0 return $_?

REM Initialize
result=
BakFileName=$@FileName[$BakFile]
BakFileHost=$hostTemp/$BakFileName
BakFileHostUnc=$hostTempUnc/$BakFileName


REM Backup
echo Backing up $database database...
"$sqlCmd" -b -S $host -Q "backup database $database to disk = '$BakFileHost'"
if $? != 0 return $?

REM Compress
echo.
echo Compressing $database database backup...
call RunRemote $host 7z a "$BakFileHost.7z" "$BakFileHost"
if $? != 0 || not IsFile "$BakFileHostUnc.7z" (gosub HostCleanup & return 1)

REM Move
echo.
echo Moving $database database backup...
move /g "$BakFileHostUnc.7z" "$BakFile.7z"

gosub HostCleanup

return 0

:HostPrepare

hostTemp="$(mktemp -u $TMP/SqlServer.XXXXXXXXXX)"	 
hostTempUnc="//$host/c$/temp/$(mktemp -u SqlServer.XXXXXXXXXX)"

REM Ensure backup files do not exist
gosub HostCleanup

call MakeDir "$hostTempUnc"
return $?

:HostCleanup
call DelDir.btm "$hostTempUnc"
return 

:restore

REM Arguments

if $@IsHelpArg[$@UnQuote[$1]] == 1 goto UsageDbRestore

if $# == 0 goto usage
BakFile=$@UnQuote[$1]
shift

gosub CheckHost
if $_? != 0 return $_?

RestoreSql=$@BatchDir[]/Database Restore.sql
if $# != 0; then
	RestoreSql=$@UnQuote[$1]
	shift
fi

if $# != 0 goto usage

REM Validate

if not IsFile "$BakFile"; then
	echo $@FileName[$BakFile] does not exist.
	return 1
fi

if not IsFile "$RestoreSql"; then
	echo $@FileName[$RestoreSql] does not exist.
	return 1
fi

REM Get the location of data files in DataDir
call SqlServer.btm GetDataDir $host
if $? != 0; then
	echo Unable to locate the SQL Server data file directory on $host.
	return 1
fi

REM Initialize
BakFileName=$@FileName[$BakFile]

gosub HostPrepare
if $_? != 0 return $_?

REM Copy the BakFile to the destination server
echo Copying $BakFileName...
copy /g "$BakFile" "$hostTempUnc"
if $? != 0 return $?

REM If the bak file is an archive uncompress it and get the first bak file in the archive
if $@IsArchive["$BakFileName"] == 1; then

	call RunRemote $host 7z e "$hostTemp/$BakFileName" -o"$hostTemp"
	if $? != 0 (gosub HostCleanup & return 1)

	BakFileName=$@FileName[$@FindFirst[$hostTempUnc/*.bak]] & echo $@FindClose[] >& nul:
	if not IsFile "$hostTempUnc/$BakFileName"; then
		EchoErr Unable to locate a database backup file in $@FileName[$BakFile]
		gosub HostCleanup
		return 1
	fi
	
fi	

REM Replace bak_file in the script with the specified file
type "$RestoreSql" |^
	sed -e 's/data_dir/$@replace[/,///,$DataDir]/' ^
			-e 's/bak_file/$@replace[/,///,$hostTemp/$BakFileName]/' ^
	> "$sqlTemp"

echo Restoring the Saba database...
call SqlServer.btm ExecuteSql "$sqlTemp" -S $host
pause

gosub HostCleanup

return

:VerifysqlCmd

if not IsFile "$sqlCmd"; then
	sqlCmd=$@search[sqlCmd]
fi

if "$sqlCmd" == ""; then
	echo sqlCmd could not be found.
	return 1
fi

return 0

:cmd

gosub VerifysqlCmd
if $_? != 0 return $_?

"$sqlCmd" $$

return

:ProfileExist
call profile.btm restore $1 exist
return $?