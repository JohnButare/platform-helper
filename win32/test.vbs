set outlookApplication = GetObject(, "Outlook.Application")

appointments = new Object();
var date = new Date();
//var nowDate = formatDate(date);
var nowDate = dateFormatter.toOutlookFilterString(date);

var filterCurrent = "([Start] < '" + nowDate + "') AND ([End] > '" + nowDate + "')";
var filterFuture = "([Start] >= '" + nowDate + "')";
