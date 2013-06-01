
PhoneInit()

PhoneInit()
{
	global
	
	Phone = %programs32%\Cisco Systems\Cisco IP Communicator\CommunicatorK9.EXE
	PhoneTitle = Cisco IP Communicator

}

PhoneActivate()
{
	global
	WinActivate %PhoneTitle%
}

; PhoneSpeed(num) - Dial the speed dial number specified using the headset
PhoneSpeed(num)
{
	PhoneActivate()
	
	if PhoneInCall() 
		return
	
	; Activate the headset so it is used for the next call
	PhoneHeadsetActivate()

	SendInput ^{%num%}	
}

PhoneMute()
{
	PhoneActivate()
	
	if PhoneInCall() 
		SendInput ^t
}

PhoneHangup()
{
	PhoneActivate()
	
	if PhoneInCall() 
	{
		SendInput {escape}
		Sleep 500
	}
	
	; Activate the speakerphone so the headset sleeps
	PhoneSpeakerphoneActivate()
}

; Turn on the headset
PhoneHeadset()
{
	PhoneActivate()
	
	if PhoneHeadsetSelected()	
	{
		SendInput ^h
	}
	
	SendInput ^h
}

; Turn on the speakerphone
PhoneSpeakerphone()
{
	PhoneActivate()
	
	if PhoneInCall() 
		return
	
	SendInput ^p
}

; Activate speakerphone so it is used in the next call
PhoneSpeakerphoneActivate()
{
	PhoneActivate()
	
	if PhoneInCall() 
		return
	
	; Turn off the headset
	if PhoneHeadsetSelected()
	{
		SendInput ^h
		Sleep 500
	}
	
	SendInput ^p^p
}

; Activate headset so it is used in the next call
PhoneHeadsetActivate()
{
	PhoneActivate()
	
	if PhoneInCall()
		return
	
	if not PhoneHeadsetSelected()
	{
		SendInput ^h
		Sleep 500
		SendInput {escape}
	}

}

;
; Helper functions
;

; Return True if the headset indicator is selected (not grey)
PhoneHeadsetSelected()
{
	CoordMode Pixel, Relative
	PixelGetColor color, 285, 290
	HeadsetSelected := !(color == "0x7B7B7B" or color == "0x7B797B")
	;MsgBox HeadsetSelected=%HeadsetSelected% color=%color% 
	return %HeadsetSelected%
}

PhoneInCall()
{
	CoordMode Pixel, Relative
	PixelGetColor color, 100, 150
	InCall := (color == "0xAA8844" or color == "0xAD8A42")
	;MsgBox InCall=%InCall% color=%color%
	return %InCall%
}