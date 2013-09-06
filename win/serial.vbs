
Set comsys= GetObject ("WinMgmts:").InstancesOf("Win32_ComputerSystem")
Set bios = GetObject ("WinMgmts:").InstancesOf("Win32_BIOS")

For each obj in comsys
  WScript.echo "Name:   " & obj.Name
  WScript.echo "Model:  " & obj.Model
Next
For each obj in bios
  WScript.echo  "Serial: " & obj.SerialNumber
Next
