OpenChrome()
{
	global
  IfExist, %PROGRAMS32%\Google\Chrome\Application\chrome.exe
  {
		run "%PROGRAMS32%\Google\Chrome\Application\chrome.exe"
  }
  else
  {
    EnvGet LocalAppData, LOCALAPPDATA 
    run "%LocalAppData%\Google\Chrome\Application\chrome.exe"
  }
}

OpenFirefox()
{
  global
  run "%PROGRAMS32%\Mozilla Firefox\Firefox.exe"
}
