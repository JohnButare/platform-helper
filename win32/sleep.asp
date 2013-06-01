<%

set shell= Server.CreateObject("WScript.Shell")
shell.Exec("tcc /c call power sleep force")
set shell = nothing

set network = CreateObject("Wscript.Network") 
response.write "<h1>" + network.ComputerName  + " has been asked to sleep.</h1>"
set network = nothing

%>