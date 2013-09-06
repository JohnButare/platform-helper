WScript.echo "Catsrv.CatalogServer.1 on azSsaba01..."
Set o = CreateObject("SAFRCFileDlg.Panic", "azSsaba01")
WScript.echo "Done"

WScript.echo "Creating TISHistoryLGW.UploadHistory on HistoryLoadGateway.intel.com..."
Set oHlg = CreateObject("TISHistoryLGW.UploadHistory", "HistoryLoadGateway.intel.com")
WScript.echo "Done"

' Set to True to use TESS Test Database.  Default is False to use production TESS database.
' oHlg.Test = True
    
' oHlg.UploadHistory(Wwid, Idsid, SourceId, ContactEmail, CourseCode, StartDate, EndDate)
' MsgBox oHlg.UploadHistory("WWID", "", "IDV", "ChangeMe@intel.com", "005673", "", "")

' MsgBox oHlg.ErrCode
    