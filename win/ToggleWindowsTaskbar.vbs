Option Explicit

Dim WshShell, oShell

' Create WshShell Object
Set WshShell = Wscript.CreateObject("Wscript.shell")
Set oShell = CreateObject("Shell.Application")

oShell.TrayProperties

'Was 200
Wscript.Sleep 400
WshShell.SendKeys "%u" ' Alt+u = Auto-hide the taskbar

' Was 50
Wscript.Sleep 100
WshShell.SendKeys "{ENTER}" ' Enter to Close Properties

Set oShell = Nothing

WScript.Quit
