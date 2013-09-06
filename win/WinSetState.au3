Opt("WinTitleMatchMode", 3)
If $CmdLine[0] == 3 Then
	exit NOT WinSetState("[REGEXPCLASS:\A" & $CmdLine[2] & "\z]", "", GetFlag($CmdLine[3]))
ElseIf $CmdLine[0] == 2 Then
	exit NOT WinSetState("[REGEXPTITLE:\A" & $CmdLine[1] & "\z]", "", GetFlag($CmdLine[2]))
Else
	usage()
EndIf

Func usage()
	ConsoleWriteError("usage: WinSetState [class] <title|class> <flag>" & @CRLF)
	ConsoleWriteError("  hide = Hide window" & @CRLF)
	ConsoleWriteError("  show = Shows a previously hidden window" & @CRLF)
	ConsoleWriteError("  minimize = Minimize window" & @CRLF)
	ConsoleWriteError("  maximize = Maximize window" & @CRLF)
	ConsoleWriteError("  restore = Undoes a window minimization or maximization" & @CRLF)
	ConsoleWriteError("  disable = Disables the window" & @CRLF)
	ConsoleWriteError("  enable = Enables the window" & @CRLF)
	exit 1
EndFunc

Func GetFlag($val)
	Switch $val
		Case "hide"
			return @SW_HIDE
		Case "show"
			return @SW_SHOW
		Case "minimize"
			return @SW_MINIMIZE
		Case "maximize"
			return @SW_MAXIMIZE
		Case "restore"
			return @SW_RESTORE
		Case "disdable"
			return @SW_DISABLE
		Case "enable"
			return @SW_ENABLE
		Case Else
			usage()
		EndSwitch
EndFunc