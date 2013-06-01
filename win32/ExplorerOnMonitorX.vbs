'customize the following 3 lines
Const CMD = "C:\WINDOWS\explorer.exe /E,,c:\program files" 'command line, c:\program files is the folder which gets opened initially
Const SHOWSTATE = 3 'normal: 2 maximized: 3 desktop-maximized: 4
Const MONITOR = 3 'monitor number

Set util = CreateObject("UltraMon.Utility")
If Util.Run(CMD, SHOWSTATE) = True Then
	util.Sleep 1000
	Set wnd = CreateObject("UltraMon.Window")
	For i = 1 To 20
		If wnd.GetForegroundWindow() = True Then
			If wnd.Class = "ExploreWClass" Then
				j = 0
				Do 
					wnd.Monitor = MONITOR
					wnd.ApplyChanges 2
					If wnd.Monitor = MONITOR Then Exit Do
					util.Sleep 1000
					j = j + 1
				Loop While j < 10
				Exit For
			End If
		End If
		util.Sleep 1000
	Next
End If
