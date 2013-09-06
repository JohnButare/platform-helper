
PersonalBridge()
{
  global
  run "%tcc%" /c lync.btm PersonalBridge,,min
}

ClipBridge()
{
  global

  clipboard = ; Empty the clipboard
  Send, ^c
  ClipWait, 2
  if ErrorLevel
  {
      MsgBox, A brdige is not selected
      return
  }

  run "%tcc%" /c lync.btm ParseBridge "%clipboard%",,min
}

Bridge()
{
  global
  run "%tcc%" /c lync.btm bridge,,min
}

PhoneDefaultSpeakers()
{
  run nircmd setdefaultsounddevice Speakers
}

PhoneDefaultPhone()
{
  run nircmd setdefaultsounddevice Phone
}