OpenDisplaySettings()
{
  Run rundll32.exe shell32.dll`,Control_RunDLL desk.cpl`,`, 3
}

; Power down all monitors
; 0x112 is WM_SYSCOMMAND, 0xF170 is SC_MONITORPOWER.
; -1=On, 1=Low Power, 2=Off
PowerDownMonitor()
{
	Sleep, 1000
  SendMessage, 0x112, 0xF170, 2,, Program Manager   
}

StartScreenSaver()
{
  SendMessage, 0x112, 0xF140, 0,, Program Manager   ; 0x112 is WM_SYSCOMMAND, and 0xF140 is SC_SCREENSAVE.
}

Lock()
{
  SendInput #l
  Sleep, 1000
	PowerDownMonitor()
}