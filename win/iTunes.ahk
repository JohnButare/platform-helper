
iTunesInit()

iTunesInit()
{
	global
	
	iTunes = %PROGRAMS32%\iTunes\iTunes.exe
	iTunesTitle = iTunes
}

; Activate, or start and play
RuniTunes()
{
	global 
	
  IfWinExist %iTunesTitle%
  {
    WinActivate %iTunesTitle%
    return
  }

  IfNotExist %iTunes%
  {
    return
  }

  run %iTunes%
}

iTunesPlay()
{
	iTunesCommand("play")
}

iTunesPlayPause()
{
	iTunesCommand("PlayPause")
}

iTunesIncreaseVolume()
{
  IfWinExist, iTunes
    ControlSend, ahk_parent, ^{Up}
}

iTunesDecreaseVolume()
{
  IfWinExist, iTunes
    ControlSend, ahk_parent, ^{Down}555
}

iTunesNextTrack()
{
  iTunesCommand("next")
}

iTunesPreviousTrack()
{
  iTunesCommand("previous")
}

iTunesPause()
{
  iTunesCommand("pause")
}

iTunesCommand(command)
{
	global

  IfWinExist, %iTunesTitle%
		run wscript "%PUBLIC%\documents\data\bin\win32\iTunes.js" %command%
}