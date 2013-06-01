'Copyright 2002 by Realtime Soft

Const POS_WINDOWS = &H1
Const POS_ICONS = &H2
Const POS_DESKTOPITEMS = &H4
Const POS_ALL = &H7

Set sys = CreateObject("UltraMon.System")
Set mon = sys.Monitors("4") 'replace X with the number of the monitor you want to disable/enable

If mon.Enabled = True Then
	'disable monitor
	
	sys.SavePositions POS_ALL
	mon.Enabled = False
	sys.ApplyMonitorChanges
Else
	'enable monitor
	
	mon.Enabled = True
	sys.ApplyMonitorChanges
	sys.RestorePositions POS_ALL 'remove this line if UltraMon shouldn't restore window and icon positions
End If

