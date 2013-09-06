'*****************************************
' New INI file functions
' Allan Robson 4 august 1998
' have fun
'****************************************

Set WinIniObj = WScript.CreateObject("wshadmin.Ini")


'****** write to INI usage: section,item,value,filename
xx = WinIniObj.XWritePrivateProfileString("Desktop","Wallpaper","c:\windows\test.bmp","c:\windows\win.ini")


'****** read INI file usage: section,item,defaultvalue,buffer,buffersize,filename
xx = WinIniObj.XGetPrivateProfileString("Desktop","Wallpaper","(None)",space(50),50,"c:\windows\win.ini")

'wscript.echo "The Return Value = " & xx