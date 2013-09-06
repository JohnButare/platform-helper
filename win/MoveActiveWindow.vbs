Const WNDCHANGE_RESIZE_TO_FIT = 1
Const WNDCHANGE_CLIP_TO_WORKSPACE = 2 

If WScript.Arguments.Count < 1 Or WScript.Arguments.Count > 2 Then
	MsgBox "Usage: MoveActiveWnd.vbs <monId> [/r]" & vbNewline & "/r: resize to fit. Default is resize proportionally"
	WScript.Quit
End If

Set wnd = CreateObject("UltraMon.Window")
If wnd.GetForegroundWindow() = True Then
	wnd.Monitor = CLng(WScript.Arguments(0))
	flags = WNDCHANGE_CLIP_TO_WORKSPACE
	If WScript.Arguments.Count = 2 Then
		If CStr(WScript.Arguments(1)) = "/r" Then flags = flags + WNDCHANGE_RESIZE_TO_FIT
	End If
	wnd.ApplyChanges flags
End If