
if (WScript.arguments.length != 1)
{
  usage();
}

var sys = WScript.CreateObject("UltraMon.System");

switch (WScript.arguments(0))
{
  case "SaveWindowPositions":
    sys.SavePositions(1);
		WScript.Echo("Window positions have been saved.");
    break;

  case "RestoreWindowPositions":
    sys.RestorePositions(1);
		WScript.Echo("Window positions have been restored.");
    break;
     		
	case "test":
		test();
		break;

	case "info":
		info();
		break;
		
  default:
    usage();
    break;
    
}

function usage()
{
  WScript.Echo("usage: info|test|SaveWindowPositions|RestoreWindowPositions");
  WScript.Quit(1);
}

function test()
{
	var MainMonitor = "1";
	var OtherMonitor = "2";

	MonitorInfo(sys.Monitors(MainMonitor));

	//m = sys.Monitors("1");
	//MonitorInfo(m);
	
	//util = WScript.CreateObject("UltraMon.Utility");
	//util.Sleep(2000);
	
	// Make the main monitor primary
	if (sys.Monitors(MainMonitor).Primary == false)
	{
		//sys.Monitors(MainMonitor).Primary = true;
		//sys.ApplyMonitorChanges();
	}

	// Make the other monitor primary
	m = sys.Monitors(OtherMonitor);
	if (m.Enabled == false || m.Primary == false) 
	{
		//m.Enabled = true;
		//sys.ApplyMonitorChanges();
		//m.Primary = true;
		//sys.ApplyMonitorChanges();
	}
	
}

function info()
{
	for (e = new Enumerator(sys.Monitors), i = 1 ; !e.atEnd() ; e.moveNext() , ++i)
	{
		m = e.item();
		MonitorInfo(m);
	}

}

function MonitorInfo(m)
{
	primaryDescription = "";
	if (m.Primary) primaryDescription = " (primary)";

	WScript.Echo("Monitor " + m.ID + " " + m.Name + primaryDescription);
	WScript.Echo("  DeviceName=" + m.DeviceName);
	WScript.Echo("  Enabled=" + m.Enabled);
	WScript.Echo("  RefreshRate=" + m.RefreshRate);
	//WScript.Echo("  Monitor Handle=" + m.HMonitor);
	//WScript.Echo("  WindowsID=" + m.WindowsID);
	//WScript.Echo("  Detached=" + m.Detached);
	//WScript.Echo("  HwAccel=" + m.HwAccel);
	//WScript.Echo("  Removable=" + m.Removable);
	//WScript.Echo("  AdapterName=" + m.AdapterName);
}
