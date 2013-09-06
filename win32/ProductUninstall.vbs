
If WScript.Arguments.Count < 1 Or WScript.Arguments.Count > 2 Then
	wsh.echo "usage: ProductUninstall <product code>"
	wscript.Quit 1
End If

REM http://msdn.microsoft.com/en-us/library/windows/desktop/aa369387(v=vs.85).aspx
REM "{432DB9E4-6388-432F-9ADB-61E8782F4593}" 
Const msiUILevelNone = 2
myProductCode = WScript.Arguments(0)
Const msiInstallStateAbsent = 2

Set objInstaller = CreateObject("WindowsInstaller.Installer")
objInstaller.UILevel = msiUILevelNone
objInstaller.ConfigureProduct myProductCode , 0 , msiInstallStateAbsent
Set objInstaller = Nothing