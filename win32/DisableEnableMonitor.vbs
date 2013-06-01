'copyright 2001 by Realtime Soft - www.realtimesoft.com

Const POS_ALL = &H7
Const msgTitle = "Disable or enable monitor"

monId = InputBox("Please enter the number of the monitor you want to disable or enable:", msgTitle)
If monId <> "" Then
	monNum = 0
	If IsNumeric(monId) = True Then monNum = CLng(monId)
	Set sys = CreateObject("UltraMon.System")
	If monNum < 0 Or monNum > sys.Monitors.Count Then monNum = 0
	
	If monNum = 0 Then
		MsgBox "Please enter a valid monitor number.", vbOKOnly, msgTitle
	Else
		Set mon = sys.Monitors(CStr(monId))
		If mon.Primary = True Then
			MsgBox "Can't disable or enable the primary monitor.", vbOKOnly, msgTitle
		Else
			If mon.Enabled = False Then
				mon.Enabled = True
				sys.ApplyMonitorChanges
				sys.RestorePositions POS_ALL
			Else
				mon.Enabled = False
				sys.SavePositions POS_ALL
				sys.ApplyMonitorChanges
			End If
		End If
	End If
End If