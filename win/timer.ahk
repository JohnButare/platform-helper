SetTimer TimerCheckIdle, 10000

TimerCheckIdle:
TimerCheckIdle()
return

TimerInit()
{
	global
	
	IdleMinutes := 15
	LastIdleTime := 0

	PowerLogFile := PUBLIC . "documents\data\log\power.txt"
}

; IdleEvent - called when user session is idle, even if another user is active.
TimerCheckIdle()
{
	global IdleMinutes, POWER_LOG_FILE, LastIdleTime

	; Reset the last idle time 
	if (A_TimeIdlePhysical < LastIdleTime)
		LastIdleTime := 0	

	;PowerLog("The system has been idle for " . round(A_TimeIdlePhysical / 1000 / 60) . "m" . round(A_TimeIdlePhysical / 1000) "s.")	
	; PowerLog((A_TimeIdlePhysical - LastIdleTime) "," . (1000 * 60 * IdleMinutes) . "," . A_TimeIdlePhysical . "," . LastIdleTime . "," . IdleMinutes)	

	; Return if we have not reached the idle timeout period
	if (A_TimeIdlePhysical - LastIdleTime) < (1000 * 60 * IdleMinutes)
		return
	
	; Record the time of the idle event
	LastIdleTime := A_TimeIdlePhysical
	
	; Log the idle event
	Powerlog("The system has been idle for " . IdleMinutes . " minutes.  Calling the idle event.")
	
	; Call user supplied IdleEvent
	IdleEvent()
}

PowerLog(text)
{
	global PowerLogFile
	FormatTime t,,MM/dd/yy HH:mm:ss
	FileAppend [%t%] %text%`n, %PowerLogFile%
}
