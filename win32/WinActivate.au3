Opt("WinTitleMatchMode", 3)
If $CmdLine[0] == 2 Then
	exit NOT WinActivate("[REGEXPCLASS:\A" & $CmdLine[2] & "\z]")
ElseIf $CmdLine[0] == 1 Then
	exit NOT WinActivate("[REGEXPTITLE:\A" & $CmdLine[1] & "\z]")
Else
	ConsoleWriteError("usage: WinActivate [class] <title|class>" & @CRLF)
	exit 1
EndIf