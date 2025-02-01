-- Requires SQLCMD mode: Query, check SQLCMD mode

-- Initialize
:SetVar NewDatabaseName ""
:SetVar BakLogicPrefix ""
:SetVar BakFileNumber "1"
:SetVar BakFile "bak_file"
:SetVar DataDir "data_dir"

-- Validate BakFileNumber and BakLogicalPrefix
restore headeronly from disk = '$(BakFile)'
restore FileListOnly from disk = '$(BakFile)' with file = $(BakFileNumber)

-- Validate or Cleanup
/*
use master
drop database MyLearning
drop login tp2
drop login saba_report
*/

-- Restore and rename 
print 'Restoring $(BakFile) to $(NewDatabaseName)...'
restore database $(NewDatabaseName)
   from disk = '$(BakFile)'
   with file = $(BakFileNumber),
		move '$(BakLogicPrefix)_data' to '$(DataDir)\$(NewDatabaseName).mdf',
		move '$(BakLogicPrefix)_log' TO '$(DataDir)\$(NewDatabaseName)_log.ldf'
		-- add other files as needed
go
