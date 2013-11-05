
; Do not detect hidden windows.  Otherwise, hidden tcc windows used by Take Command will be detected.
DetectHiddenWindows, Off

BashInit()
{
	global

	EnvGet SHELL,SHELL
	EnvGet TMP,TMP

	bash = mintty.exe

	; if AutoHotkey was not started from a bash process, start it as a login shell
	;MsgBox SHELL=%SHELL%
	if (SHELL == "/bin/bash")
		BashArgs=
	else
		BashArgs=-

	BashClass=mintty
}

NewBash()
{
	global bash, BashArgs
	run "%bash%" %BashArgs%, , Normal, pid
	WinWait, ahk_pid %pid%
	WinActivate, ahk_pid %pid%
}

NewElevatedBash()
{
	global bash, BashArgs
	run hstart.exe /elevated ""%bash%" %BashArgs%", , Min
}

OpenBash()
{
	global BashClass
	
	ActivateBash()

	IfWinExist ahk_class %BashClass%
		return		

	NewBash()
}

ActivateBash()
{
	global BashClass
	WinActivate ahk_class %BashClass%
}

