
OfficeInit()
{
  global
  
  if (Office = "") return
     
  IfExist, %PROGRAMS64%\Microsoft Office 15\root\office15\WinWord.EXE
  {
    Office = %PROGRAMS64%\Microsoft Office 15\root\office15
  }
  else IfExist, %PROGRAMS32%\Microsoft Office 15\root\office15\WinWord.EXE
  {
    Office = %PROGRAMS32%\Microsoft Office 15\root\office15
  }    
  else IfExist, %PROGRAMS64%\Microsoft Office\Office15\WinWord.EXE
  {
    Office = %PROGRAMS64%\Microsoft Office\Office15
  }
  else IfExist, %PROGRAMS32%\Microsoft Office\Office15\WinWord.EXE
  {
    Office = %PROGRAMS32%\Microsoft Office\Office15
  }
  else IfExist, %PROGRAMS64%\Microsoft Office\Office14\WinWord.EXE
  {
    Office = %PROGRAMS64%\Microsoft Office\Office14
  }
  else IfExist, %PROGRAMS32%\Microsoft Office\Office14\WinWord.EXE
  {
    Office = %PROGRAMS32%\Microsoft Office\Office14
  }
	  
  word = %Office%\WinWord.exe
  outlook = %Office%\Outlook.exe
	OneNote = %Office%\OneNote.exe
  
	Lync = %PROGRAMS32%\Microsoft Lync\communicator.exe
	IfNotExist, %Lync%
		Lync = %Office%\lync.exe
}  
  
NewWord()
{
  global
  run "%word%"
}

; Create a new word document in the active folder or opens a blank word document
; Requires that the only item in the right context new menu that starts with W is Word
NewWordDocument()
{
	if IsExplorerActive()
		send +{F10}{up}{up}{right}W{enter}
	else
		NewWord()
}

RunOneNote()
{
	global
	
	IfWinExist .* OneNote
	{
		WinActivate .* OneNote
	}
	else
	{
		run "%OneNote%"
	}
}

RunOutlook()
{
  global
	
	IfWinExist .* Outlook
	{
		WinActivate .* Outlook
	}
	else
	{
		run "%outlook%" /recycle
	}

}

OpenIm()
{
	global

  IfWinExist, Microsoft Lync*
  {
    WinActivate, Microsoft Lync*
  }
  else
  {
    Process, Exist, communicator
    if ErrorLevel
      run wscript "C:\Documents and Settings\All Users\Documents\data\bin\communicator.js" show
    else
      run "%lync%"
  }
  	
}
