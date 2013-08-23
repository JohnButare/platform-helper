Opt("WinTitleMatchMode", 3)

If $CmdLine[0] == 3 Then
	$result = WinActivate("[REGEXPCLASS:\A" & $CmdLine[2] & "\z]")
	$keys = $CmdLine[3]
ElseIf $CmdLine[0] == 2 Then
	$result = WinActivate("[REGEXPTITLE:\A" & $CmdLine[1] & "\z]")
	$keys = $CmdLine[2]
Else
	ConsoleWriteError("usage: SendKeys [class] <title|class> <keys>" & @CRLF)
	Exit 1
EndIf

If $result == 0 Then
	Exit 1
EndIf

Send($keys)
exit 0
