
#Include iTunes.ahk
#Include sonos.ahk
#Include WindowsMediaPlayer.ahk

FindMusicPlayer()
{
	global

	IfWinExist %SonosTitle% 
		return "Sonos"
	else IfWinExist %iTunesTitle%
		return "iTunes"
	else
		return "WindowsMediaPlayer"
}

MusicPlayPause()
{
	MusicPlayer := FindMusicPlayer()
	%MusicPlayer%PlayPause()
}

MusicNextTrack()
{
	MusicPlayer := FindMusicPlayer()
	%MusicPlayer%NextTrack()
}

MusicPreviousTrack()
{
	MusicPlayer := FindMusicPlayer()
	%MusicPlayer%PreviousTrack()
}

MusicEqualizer()
{
	MusicPlayer := FindMusicPlayer()
	%MusicPlayer%Equalizer()
}

MusicPause()
{
	MusicPlayer := FindMusicPlayer()
	%MusicPlayer%Pause()
}

MusicOther()
{
	MusicPlayer := FindMusicPlayer()
	%MusicPlayer%Other()
}
