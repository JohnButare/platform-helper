##include <Process.au3>

Local $var = WinList()

For $i = 1 To $var[0][0]
	Local $title = $var[$i][0]
	Local $hwnd = $var[$i][1]
  Local $state = WinGetState($hwnd)
  If $var[$i][0] And $state <> 1 Then
  		Local $pid = WinGetProcess($hwnd)
  		Local $stateText = WinStateText($state)
  		#Local $process = _ProcessGetName($pid)
      #ConsoleWrite( $title & "," & $state & "," & $hwnd & "," & $pid & "," & $process & @CRLF)
      ConsoleWrite( $pid & "," & $title & "," & $stateText & @CRLF)
  EndIf
Next

Func WinStateText($state)
	Local $s = ""

  If BitAND($state, 1) Then
      $s = $s & "exists "
  EndIf

  If BitAND($state, 2) Then
      $s = $s & "visible "
  EndIf

  If BitAND($state, 4) Then
      $s = $s & "enabled "
  EndIf

  If BitAND($state, 8) Then
      $s = $s & "active "
  EndIf

  If BitAND($state, 16) Then
      $s = $s & "minimized "
  EndIf

  If BitAND($state, 32) Then
      $s = $s & "maximized "
  EndIf

  return $s
EndFunc