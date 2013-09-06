Const PROFILE = "Laptop" 'the name of the display profile which should be applied
Const WINTBAR_MONITOR = 2 'the number of the monitor to which the Windows taskbar should get moved

Const ULTRAMON_DIR = "%ProgramFiles%\UltraMon"
Const PROFILE_DIR = "%UserProfile%\My Documents\Data\UltraMon\Profiles"
Const DELAY = 2000 'delay before moving Windows taskbar in milliseconds

Set sh = CreateObject("WScript.Shell")
Set sys = CreateObject("UltraMon.System")

sh.Run """" & ULTRAMON_DIR & "\UltraMonShortcuts.exe"" /l " & PROFILE_DIR & "\" & PROFILE & ".umprofile",, True
WScript.Sleep DELAY
Set winTbar = sys.DockedAppBars("Windows Taskbar")
winTbar.Move WINTBAR_MONITOR, winTbar.Edge
