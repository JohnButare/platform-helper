
' If wscript.arguments.count < 1 Or WScript.Arguments.Count > 2 Then
'	MsgBox "Usage: MoveActiveWnd.vbs <monId> [/r]" & vbNewline & "/r: resize to fit. Default is resize proportionally"
'	WScript.Quit
'End If

set system=CreateObject("UltraMon.System")

monitor=wscript.arguments(0)

system.monitors(cstr(monitor)).width=wscript.arguments(1)
system.monitors(cstr(monitor)).height=wscript.arguments(2)

if wscript.arguments.count > 3 then
	system.monitors(cstr(monitor)).ColorDepth=wscript.arguments(3)
end if

if wscript.arguments.count > 4 then
	system.monitors(cstr(monitor)).RefreshRate=wscript.arguments(4)
end if

system.ApplyMonitorChanges()