Opt("WinTitleMatchMode", 3)
If $CmdLine[0] == 2 Then
	exit WinGetState("[REGEXPCLASS:\A" & $CmdLine[2] & "\z]")
ElseIf $CmdLine[0] == 1 Then
	exit WinGetState("[REGEXPTITLE:\A" & $CmdLine[1] & "\z]")
Else
	ConsoleWriteError("usage: WinGetState [class] <title|class>" & @CRLF)
	exit 0
EndIf