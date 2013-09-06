Const WNDCHANGE_RESIZE_TO_FIT = 1
Const WNDCHANGE_CLIP_TO_WORKSPACE = 2 

If WScript.Arguments.Count <> 1 Then
	MsgBox "Usage: DisableMonitor.vbs <monId>"
	WScript.Quit
End If


Set sys = CreateObject("UltraMon.System")
Set mon = sys.Monitors(CStr(WScript.Arguments(0)))

mon.Enabled = True
sys.ApplyMonitorChanges
