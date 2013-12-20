Opt("WinTitleMatchMode", 3)

$result = 1

If $CmdLine[0] == 3 Then
	$result = WinActivate("[REGEXPCLASS:\A" & $CmdLine[2] & "\z]")
	$keys = $CmdLine[3]
ElseIf $CmdLine[0] == 2 Then
	$result = WinActivate("[REGEXPTITLE:\A" & $CmdLine[1] & "\z]")
	$keys = $CmdLine[2]
ElseIf $CmdLine[0] == 1 Then
	$keys = $CmdLine[1]
Else
	ConsoleWriteError("usage: SendKeys [TITLE|class CLASS] KEYS" & @CRLF)
	exit 1
EndIf

If $result == 0 Then
	exit 1
EndIf

Send($keys)
exit 0
