Const WNDCHANGE_RESIZE_TO_FIT = 1
Const WNDCHANGE_CLIP_TO_WORKSPACE = 2 

REM Arguments
If WScript.Arguments.Count <> 1 Then
	usage()
End If

if not (WScript.Arguments(0) = "true" or WScript.Arguments(0) = "false") then
	usage()
end if

show = (WScript.Arguments(0) = "true")

REM Initialize
Set sys = CreateObject("UltraMon.System")
Set winTbar = sys.DockedAppBars("Windows Taskbar")

'wscript.echo "show=" & show
'wscript.echo "winTbar.AutoHidden=" & winTbar.AutoHidden 
'wscript.echo "process=" & (winTbar.AutoHidden = show)

if winTbar.AutoHidden = show then
	Set shell = Wscript.CreateObject("Wscript.shell")
	shell.run "ToggleWindowsTaskbar.vbs"
	Set shell = nothing
end if

sub usage()
	wscript.echo "Usage: ShowWindowsTaskbar true|false"
	WScript.Quit
end sub
