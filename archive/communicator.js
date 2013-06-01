// Reference http://msdn.microsoft.com/en-us/library/bb758820.aspx
if (WScript.arguments.length != 1)
{
  usage();
}

switch (WScript.arguments(0))
{
  case "close":
    close();
    break;
     	
  case "login":
    login();
    break;

	case "show":
    show();
    break;

  default:
    usage();
    break;
    
}

function show()
{
  var app = WScript.CreateObject("Communicator.UIAutomation");
  w = app.Window;
	w.Show();
	app = null;
}

function close()
{
}

function login()
{
  var app = WScript.CreateObject("Communicator.UIAutomation");
  app.AutoSignin();
  app = null;
}

function usage()
{
  WScript.Echo("usage: close|login|show");
  WScript.Quit(1);
}
