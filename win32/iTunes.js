
if (WScript.arguments.length != 1)
{
  usage();
}

switch (WScript.arguments(0))
{
  case "alarm":
    alarm();
    break;

  case "close":
    close();
    break;
     
  case "play":
    play();
    break;

	case "PlayPause":
		PlayPause();
		break;

  case "pause":
    pause();
    break;

  case "next":
    next();
    break;

  case "previous":
    previous();
    break;

  case "ListDeadTracks":
    DeadTracks(false);
    break;

  case "DeleteDeadTracks":
    DeadTracks(true);
    break;

  case "ListBest":
    ListBest();
    break;
		
  default:
    usage();
    break;
    
}

function close()
{
  var app = WScript.CreateObject("iTunes.Application");
  app.Quit();
  app = null;
}

function play()
{
  var app = WScript.CreateObject("iTunes.Application");
  app.Play();
  app = null;
}

function PlayPause()
{
	var app = WScript.CreateObject("iTunes.Application");
	app.PlayPause();
	app = null;
}

function pause()
{
  var app = WScript.CreateObject("iTunes.Application");
  app.Stop();
  app = null;
}

function next()
{
  var app = WScript.CreateObject("iTunes.Application");
  app.Play();
  app.NextTrack();
  app = null;
}

function previous()
{
  var app = WScript.CreateObject("iTunes.Application");
	app.Play();
  app.PreviousTrack();
  app = null;
}

function alarm()
{

  // Play iTunes
  var app = WScript.CreateObject("iTunes.Application");
  app.SoundVolume = 25;
  app.Play();

  // Gradually increase volume
  for (var i = app.SoundVolume ; i <= 100 ; ++i) 
  {
    app.SoundVolume = i;
    
    WScript.Sleep(5000);
  
    // If the volume has been changed by another application (user), stop changing it.
    // Allow some variance, since the sound volume may not change to exactly what it is set to.
    //WScript.Echo("SoundVolume=" + app.SoundVolume + " i=" + i);
    if (app.SoundVolume > (i+2) || app.SoundVolume < (i-2))
    {
      app = null;
      return;
    }
    
  }
  app = null;
}

function usage()
{
  WScript.Echo("usage: close|play|PlayPause|next|previous|stop|ListDeadTracks|DeleteDeadTracks");
  WScript.Quit(1);
}

function DeadTracks(DoDelete)
{
	var ITTrackKindFile	= 1;
	var app = WScript.CreateObject("iTunes.Application");
	var	mainLibrary = app.LibraryPlaylist;
	var	tracks = mainLibrary.Tracks;
	var	numTracks = tracks.Count;

	while (numTracks != 0)
	{
		var	currTrack = tracks.Item(numTracks);
					
		if (currTrack.Kind == ITTrackKindFile)
		{
			if (currTrack.Location == "")
			{
				if (DoDelete)
				{
					WScript.Echo("Deleting dead track " + currTrack.Name + ' - ' + currTrack.AlbumArtist);
					currTrack.Delete();
				}
				else		
					WScript.Echo(currTrack.Name + ' - ' + currTrack.AlbumArtist);
			}
		}
	
		numTracks--;
	}
}
 
function DeleteDeadTracks()
{
	
}
 
 function ListBest()
 {
 
 	var app = WScript.CreateObject("iTunes.Application");
	
	var librarySource = app.LibrarySource;
	var bestPlaylist = librarySource.Playlists.ItemByName("Best");
	
	if (bestPlaylist == null)
	{
		WScript.Echo("Best playlist does not exist.");
		WScript.Quit(1);
	}

	var	count = bestPlaylist.Tracks.Count;
	var i = 1
	
	//WScript.Echo("number of tracks=" + count);
	//WScript.Echo("size=" + bestPlaylist.Size/1024/1024 + " mb");

	while (i <= count)
	{
		//WScript.Echo("value=" + bestPlaylist.Tracks(i).Name);
		WScript.Echo(bestPlaylist.Tracks(i).Location);
		i = i + 1
	}
 }