Dim $title

Opt("WinTitleMatchMode", 3)
If $CmdLine[0] == 0 Then
	Local $title = WinGettitle("[active]")
ElseIf $CmdLine[0] == 1 Then
	$title=WinGetTitle("[REGEXPTITLE:\A" & $CmdLine[1] & "\z]")
ElseIf $CmdLine[0] == 2 Then
	$title=WinGetTitle("[REGEXPCLASS:\A" & $CmdLine[2] & "\z]")
Else
	ConsoleWriteError("usage: WinGetTitle [class] [<title|class>]" & @CRLF)
	exit 1
EndIf

If $title == 0 Then
	exit 1
EndIf

ConsoleWrite($title & @CRLF)
exit 0