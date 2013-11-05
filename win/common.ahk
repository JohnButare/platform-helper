#NoEnv

CommonInit()
{
  global
  
	InitTitleMatchMode()
	
	; Set the working directory to c:\, otherwise programs are run from win32 directory 
	; even if they are in win64 directory on x64.
	SetWorkingDir c:\
	
	IfExist d:\Users\Public
		PUBLIC=d:\Users\Public
	else
		PUBLIC=c:\Users\Public
	
	PROGRAMS64=c:\Program Files

	IfExist c:\Program Files (x86)
		PROGRAMS32=c:\Program Files (x86)
	else
		PROGRAMS32=c:\Program Files

	; Text editor
	IfExist %PROGRAMS64%\Sublime Text 2\sublime_text.exe
	{
		TextEdit = %PROGRAMS64%\Sublime Text 2\sublime_text.exe
		TextEditTitle = .* - Sublime Text 2
	}
	Else IfExist %PROGRAMS32%\Notepad++\notepad++.exe
	{
		TextEdit = %PROGRAMS32%\Notepad++\notepad++.exe
	   TextEditTitle = .* - Notepad++
	}
	else
	{
		TextEdit = NotePad
	}		
}

InitTitleMatchMode()
{
	SetTitleMatchMode RegEx
	SetTitleMatchMode fast
}

IsExplorerActive()
{
	; Is explorer active? - Window Spy shows ExploreWClass for Windows XP and CabinetWClass for Vista/Win7
  if WinActive("ahk_class CabinetWClass") or WinActive("ahk_class ExploreWClass")
		return 1
	return 0
}

; Requires that the only item in the right context new menu that starts with F is Folder
NewFolder()
{
  if IsExplorerActive()
		send +{F10}{up}{up}{right}{enter}
}

OpenExplorer()
{
	OpenExplorer64()
}

; Open 32-bit Explorer at My Computer in a separate process, regardless of the OS architecture (x86 or x64).
OpenExplorer32()
{

	; Specify the program to load in a variable (otherwise AutoHotKey does not pass the comma in the arguments), quotes
	; around the program also interfere.
	
	IfExist %A_WinDir%\SysWow64\explorer.exe
	{
		; /separate forces a separate procerss which allows the x86 explorer to beloaded
		program = %A_WinDir%\SysWow64\explorer.exe /separate, ::{20D04FE0-3AEA-1069-A2D8-08002B30309D}
		run %program%
	}
	else
	{
		run explorer ::{20D04FE0-3AEA-1069-A2D8-08002B30309D}
	}
}

; Open Explorer at My Computer.  64-bit Explorer is loaded is possible (when running an x64 OS).
OpenExplorer64()
{
	run  explorer ::{20D04FE0-3AEA-1069-A2D8-08002B30309D}
}

OpenTextEditor()
{
	IfWinExist %TextEditTitle%
	{
		WinActivate %TextEditTitle%
	}
	else
	{
		global TextEdit
		run "%TextEdit%"
	}
}

NewTextEditor()
{
	global TextEdit
	run "%TextEdit%" -n
}

OpenEverNote()
{
	global PROGRAMS32

	IfWinExist, .* - Evernote$
		WinActivate
	else
		run "%PROGRAMS32%\Evernote\Evernote\Evernote.exe"
}

RunProcessExplorer()
{
	run "procexp.exe"
}


OpenRecycleBin()
{
	run explorer ::{645FF040-5081-101B-9F08-00AA002F954E}
}
