Opt("WinTitleMatchMode", 3)
If $CmdLine[0] == 2 Then
	exit NOT WinClose("[REGEXPCLASS:\A" & $CmdLine[2] & "\z]")
ElseIf $CmdLine[0] == 1 Then
	exit NOT WinClose("[REGEXPTITLE:\A" & $CmdLine[1] & "\z]")
Else
	ConsoleWriteError("usage: WinClose [class] <title|class>" & @CRLF)
	exit 1
EndIf