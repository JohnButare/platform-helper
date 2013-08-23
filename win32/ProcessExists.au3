If $CmdLine[0] == 1 Then
	exit NOT ProcessExists($CmdLine[1])
Else
	ConsoleWriteError("usage: ProcessExists <name|pid>" & @CRLF)
	exit 1
EndIf