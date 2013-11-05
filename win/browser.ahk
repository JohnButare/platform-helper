BrowserInit()
{
  global

  IfExist, %PROGRAMS32%\Google\Chrome\Application\chrome.exe
  {
    chrome=%PROGRAMS32%\Google\Chrome\Application\chrome.exe
  }
  else
  {
    EnvGet LocalAppData, LOCALAPPDATA 
    chrome=%LocalAppData%\Google\Chrome\Application\chrome.exe
  }
  ChromeClass=Chrome_WidgetWin_1
}

OpenFirefox()
{
  global
  run "%PROGRAMS32%\Mozilla Firefox\Firefox.exe"
}

NewChrome()
{
  global chrome

  run, "%chrome%", , Normal, pid
  ;WinWait, ahk_pid %pid%
  WinActivate, ahk_pid %pid%
}

OpenChrome()
{
  global ChromeClass
  
  ActivateChrome()

  IfWinExist ahk_class %ChromeClass%
    return    

  NewChrome()
}

ActivateChrome()
{
  global ChromeClass
  WinActivate ahk_class %ChromeClass%
}

