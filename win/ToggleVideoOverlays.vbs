'Copyright 2002 by Realtime Soft

Set sys = CreateObject("UltraMon.System")
enabled = sys.DirectDrawAcceleration

msg = "Video overlays are "
If enabled = True Then
	msg = msg & "enabled"
Else
	msg = msg & "disabled"
End If
msg = msg & ". Do you want to "
If enabled = True Then
	msg = msg & "disable"
Else
	msg = msg & "enable"
End If
msg = msg & " video overlays?"

ret = MsgBox(msg, vbYesNo Or vbQuestion, "Toggle Video Overlays")
If ret = vbYes Then
	sys.DirectDrawAcceleration = Not enabled
End If