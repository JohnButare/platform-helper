IsVirtualMachine()
{
	global PROGRAMS32
	
  IfExist %PROGRAMS32%\VMware\VMware Tools\VMip.exe
    return 1
  else
    return 0
}

OpenVmWare()
{
	global PROGRAMS32

	IfWinExist .*Workstation.*
	{
		WinRestore .*Workstation.*
		WinActivate .*Workstation.*
	}
	else
	{
		run %PROGRAMS32%\VMware\VMware Workstation\vmware.exe, , Max
	}
	
	; Guest get LWin up, so release it on the host 
	SendInput {LWin Up}
	
	InitTitleMatchMode()
}

