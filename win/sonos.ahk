
SonosInit()

SonosInit()
{
	global
	
	sonos = %PROGRAMS32%\Sonos\Sonos.exe
	SonosTitle = Sonos
}

; Activate, or start and play
RunSonos()
{
	global 

  IfWinExist %SonosTitle%
  {
    WinRestore, %SonosTitle%
		WinActivate, %SonosTitle%
    return
  }

  IfNotExist %sonos%
  {
    return
  }

  ; Start Sonos Player
  run %sonos%  
}

RunSonosWait()
{
	RunSonos()
	WinWaitActive %SonosTitle%, , 5
}

SonosPlayPause()
{
	global
	WinActivate, %SonosTitle%
	ControlSend, , ^p, %SonosTitle%
}

SonosNextTrack()
{
	global
	WinActivate, %SonosTitle%
	ControlSend, , ^{right}, %SonosTitle%
}

SonosPreviousTrack()
{
 	global
	WinActivate, %SonosTitle%
	ControlSend, , ^{left}, %SonosTitle%

}

SonosOther()
{
}