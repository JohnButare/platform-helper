
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
    WScript.Quit(1);  
}

//app.Stop();
