
set WshShell = WScript.CreateObject("WScript.Shell")

if wscript.arguments.count > 0 then
	name=wscript.arguments(0)
	description = "Creating restore point """ & name & """..."
else
	name = "Created by " & WshShell.ExpandEnvironmentStrings("%UserName%")
	description = "Creating restore point..."
end if

WScript.StdOut.Write description
GetObject("winmgmts:\\.\root\default:Systemrestore").CreateRestorePoint name, 12, 100
WScript.echo "done."
