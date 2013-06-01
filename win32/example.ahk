
#IfWinActive TCI:
#IfWinExist Max
LShift::
sAnd sAsss
gosub FixShift
return
RShift::gosub FixShif
#IfWinExist

FixShift:
IfWinExist MaxiVista Viewer
SetKeyDelay,25
Send {Blind}A{Left}{Delete}{Shift}
SetKeyDelay -1
return

a1:
IfWinExist MaxiVista Viewer
{
  SetKeyDelay,25
  Send {Blind}A{Left}{Delete}{Shift DownTemp}
}
else
  SendInput {Shift}
return

a2:
LShift Up::
SetKeyDelay,-1
SendInput {Blind}{Shift Up}
return



;
; AirClick
;
; OnMessage is called twice for each message the .NET AirClick app posts.  If the post is the same, the LastTickCount (clock ticks since the post)
; will be the same, so ignore it.  InputMsg is run in a thread so it must use a global environment variable to be preserved between call.s
;EnvSet, LastTickCount, 0
;OnMessage(0x00FF, "AirClick")

;This function is called, when an WM_INPUT-msg from a device is received
AirClick(wParam, lParam, msg, hwnd)
{
  ;MsgBox %wParam% %lParam% %msg% %HWND%
 
  TickCount = %A_EventInfo%
  if TickCount != %LastTickCount%
  {
    key = %wParam%
    if (key == 1) 
      iTunesPlay()
    if (key == 2)
      iTunesIncreaseVolume()
    if (key == 4)
      iTunesDecreaseVolume()
    if (key == 8)
      iTunesNextTrack()
    if (key == 16)
      iTunesPreviousTrack()
  }
  EnvSet, LastTickCount, %A_EventInfo%
}
return

; Control-Escape - activate ObjectBar

;^Esc::
;Send !^+/
;return

;
; Escape
;

/* 
$Esc::

; Close ObjectBar
IfWinActive, ahk_class ObjectBar Toolbar
{
  if (A_ThisHotkey != "^Esc")
  {
    ; Move the mouse on and off of the ObjectBar to hide it
    MouseMove, 10,10,0
    CoordMode, Mouse, Screen
    MouseMove, 0,0,0

    ; Set focus to the last active window
    Send, !{Tab}
  }
}

; Send escape key for other windows with no special handling 
else
{
  Send, {Esc}
}
return
*/


; T40

; Right Control
;*SC11D::Send {LWin Down}
;*SC11D up::Send {LWin Up}

; Function (T40) - Does not work same as when use this with Backward.  Seem to be longer 
; delay for Down
;*SC163::Send Down
;*SC163 Up::Send Up

;
; Remapping Keys and Buttons
;
;
;MButton::Shift
RAlt::Shift