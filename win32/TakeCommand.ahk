
; Do not detect hidden windows.  Otherwise, hidden tcc windows used by Take Command will be detected.
DetectHiddenWindows, Off

TakeCommandInit()
{
  global
  
  if (tcmd = "") return

	TccTitle=tc
	TccTitleRunning=tc - *

	IfExist, %PROGRAMS64%\JPSoft\TCMD13x64\tcmd.exe
	{
    tcmd = %PROGRAMS64%\JPSoft\TCMD13x64\tcmd.exe
		tcc = %PROGRAMS64%\JPSoft\TCMD13X64\tcc.exe
		TcmdTitle = TC 13*
	}
	else IfExist, %PROGRAMS64%\JPSoft\TCMD12x64\tcmd.exe
	{
    tcmd = %PROGRAMS64%\JPSoft\TCMD12x64\tcmd.exe
		tcc = %PROGRAMS64%\JPSoft\TCMD12x64\tcc.exe
		TcmdTitle = TC 12.11 - *
	}
	else IfExist, %PROGRAMS64%\JPSoft\TCMD12\tcmd.exe
	{
    tcmd = %PROGRAMS64%\JPSoft\TCMD12\tcmd.exe
		tcc = %PROGRAMS64%\JPSoft\TCMD12\tcc.exe
		TcmdTitle = TC 11 - *
	}  
	else IfExist, %PROGRAMS64%\JPSoft\TCMD11x64\tcmd.exe
	{
    tcmd = %PROGRAMS64%\JPSoft\TCMD11x64\tcmd.exe
		tcc = %PROGRAMS64%\JPSoft\TCMD11x64\tcc.exe
		TcmdTitle = TC 11 - *
	}
	else IfExist, %PROGRAMS32%\JPSoft\TCMD11\tcmd.exe
	{
    tcmd = %PROGRAMS32%\JPSoft\TCMD11\tcmd.exe
		tcc = %PROGRAMS32%\JPSoft\TCMD11\tcc.exe
		TcmdTitle = TC 11 - *
	}
  else
  {
    tcmd = tcmd.exe
		tcc = tcc.exe
  }  

}

;
; Take Command
;

NewTakeCommand()
{
	global

	; Virtual machines use take command console as take command performs poorly
	if (IsVirtualMachine() == 1)
	{
		NewTakeCommandConsole()	
		return
	}
	
	run "%tcmd%" /t "%tcc%"
}

ActivateTakeCommand()
{
	global TcmdTitle
	
	if (IsVirtualMachine() == 1)
	{
		ActivateTakeCommandConsole()	
		return
	}

  WinActivate, %TcmdTitle%
}

; Start Take Command if it is not already started.  Return 1 if Take Command was not already running and was started.
OpenTakeCommand()
{
	global TcmdTitle
	
	if (IsVirtualMachine() == 1)
	{
		OpenTakeCommandConsole()
		return
	}
	
	; It Take Command is hidden, it must be shown to discover if it is running
	ActivateTakeCommand()

  IfWinNotExist %TcmdTitle%
	{
		NewTakeCommand()
	}
}

;
; Take Command Console
;

NewTakeCommandConsole()
{
	global tcc
  run "%tcc%"
}

;run elevate.exe "%ComSpec%", , Min

NewElevatedTakeCommandConsole()
{
	global tcc
	run hstart.exe /elevated ""%tcc%" %BashArgs%", , Min
}

ActivateTakeCommandConsole()
{
	global TccTitle, TccTitleRunning
	
	IfWinExist ^%TccTitle%$
	{
		WinRestore, ^%TccTitle%$
		WinActivate, ^%TccTitle%$
	}
	else
	{
		WinRestore, ^%TccTitleRunning%
		WinActivate, ^%TccTitleRunning%
	}
}

OpenTakeCommandConsole()
{
	global TccTitle
	
	ActivateTakeCommandConsole()

  IfWinExist ^%TccTitle%$
		return	

	NewTakeCommandConsole()
}

;
; PowerShell
;

ActivatePowerShell()
{
  WinActivate, *PowerShell.exe
}

NewPowerShell()
{
  run PowerShell
}

; Start a PowerShell inside Take Command
NewTakeCommandPowerShell()
{
	global
	ActivateTakeCommand()
  run "%tcmd%" /c PowerShell
}
