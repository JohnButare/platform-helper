Dim Argcomputer, IISObject, ArgPath

select case WScript.Arguments.Count
case 0:
	ArgComputer = "localHost"
case 1:
	ArgComputer = WScript.Arguments(0)
case else:
	WScript.Echo "USAGE: cscript IisAccountInfo.vbs [ComputerName]"
	WScript.Echo "   Returns <anonymous account> <wam account>"
	WScript.Echo ""
	WScript.Quit(1)
end select

ArgPath = "/W3SVC/1/Root"

on error resume next
FullPath = "IIS://" & ArgComputer & "/W3SVC"
Set o = getObject(FullPath)
' WScript.Echo o.AnonymousUserName & " " & o.AnonymousUserPass & " " & o.WAMUserName & " " & o.WAMuserPass & " " & o.LogOdbcUserName & " " & o.LogOdbcPassword
WScript.Echo o.AnonymousUserName & " " & o.WAMUserName
