' Uses PBT_APMRESUMECRITICAL message from Win32_PowerManagementEvent WMI class 
' (http://msdn.microsoft.com/library/en-us/wmisdk/wmi/win32_powermanagementevent.asp).  cscript uses
' more memory than Hibernate Trigger.

Set oShell = CreateObject("WScript.Shell")

Set colMonitoredEvents = GetObject("winmgmts:")._
        ExecNotificationQuery("Select * from Win32_PowerManagementEvent")

Do
   Set objLatestEvent = colMonitoredEvents.NextEvent

   Select Case objLatestEvent.EventType

     Case 4
         oShell.Run "Calc.exe", 1, False
         MsgBox "Entering suspend, Calc started", _
                 vbInformation + vbSystemModal, "Suspend"

     Case 7
         oShell.Run "Notepad.exe", 1, False
         MsgBox "Resuming from suspend, notepad started", _
                 vbInformation + vbSystemModal, "Suspend"

     Case 11
         MsgBox "OEM Event happened, OEMEventCode = " _
                & strLatestEvent.OEMEventCode

     Case 18
         MsgBox "Resume Automatic happened"

   End Select
Loop