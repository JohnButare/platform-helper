'********************************************************************
'*
'*  Name:            CSI_Win32_ProductReplacement.vbs
'*  Author:          Darwin Sanoy
'*  Updates:         http://csi-windows.com/community
'*  Bug Reports &
'   Enhancement Req: http://csi-windows.com/contactus
'*
'*  Built/Tested On: Windows 7
'*  Requires:        OS: Any
'*
'*  Main Function:
'*     Retrieves LOCAL MSI package information directly through MSI API.
'*     This is intended to be a replacement for Win32_Product WMI class
'*     because using this class to simply list packages triggers MSI validation 
'*     of packages and in some cases triggers self-healing
'*
'*  Implementation:
'*     Uses new, underdocumented APIs introduced with MSI 3.0 
'*     These new APIs allow enumeration of products in other user contexts

    Const SCRIPTVERSION = 1.2
'*
'*  Revision History:
'*      4/19/11 - 1.2 - inital version (djs)
'*
'*******************************************************************

set oMSI = CreateObject("WindowsInstaller.Installer")
Indent1 = "  "
Indent2 = "     "

'ProductsEX(ProductGUID, UserSID, Context)
'ProductGUID - use product code to check for a specific product
'UserSID - VBNullString for current users, 
'        - "S-1-1-0" for all users
'InstallContextsToEnumerate
'          1 = User Managed (e.g. Packages sent to users by GPO), 
'          2 = User Unmanaged (e.g. Packages the user installed locally
'              ATTENTION: ONLY ENUMERATES FOR CURRENT USER!
'          3 = Machine Managed - packages installed per-machine (ALLUSERS=0)
'  Add up context values to get multiple contexts (e.g. 7 = All contexts)

QueryProductGUID = vbNullString
QueryUserSID = "S-1-1-0"
QueryInstallContextsToEnumerate = 7
QueryProperty = "" 'empty = ALL, ALL=ALL)

'Enumerate all properties of all products in all installation contexts'
wsh.echo CSI_EnumerateProducts(QueryProductGUID, QueryUserSID, QueryInstallContextsToEnumerate,QueryProperty)
wsh.echo vbcrlf &vbcrlf & ""

'Get the version number of a SPECIFIC product (any install context):
wsh.echo CSI_EnumerateProducts("{90140000-0019-0409-0000-0000000FF1CE}", "S-1-1-0", 7, "VersionString")

'Check if a product is installed by ProductCode (any context):
if CSI_EnumerateProducts("{90140000-0019-0409-0000-0000000FF1CE}", "S-1-1-0", 7, "VersionString") = "Product Not Installed." Then wsh.echo "Product is not installed!"

'Get the version number of all products:
wsh.echo  CSI_EnumerateProducts(vbNullString, "S-1-1-0", 7, "VersionString")


Function CSI_EnumerateProducts (ProductGUID, UserSID, InstallContextsToEnumerate, ProductProperty)
Set Products = oMSI.ProductsEx (ProductGUID, UserSID, InstallContextsToEnumerate)
  If NOT Products.count > 0 Then 
    CSI_EnumerateProducts = "No Products Installed."
    Exit Function
  End If 

For Each product In products

  If ProductProperty <> "" AND ProductProperty <> "ALL" Then
    
    If NOT PropertyValidated Then
      On Error Resume Next
      CSI_EnumerateProducts = product.InstallProperty(ProductProperty)
      If NOT Err = 0 Then
        CSI_EnumerateProducts = "No such property."
        On Error Goto 0
        Exit Function
      End If
      PropertyValidated = True
      On Error Goto 0 
    End If
    
    If Products.count = 1 Then 
      Exit Function 'Just return value of one property for one product
    End If 
    
     msg = msg & vbCRLF & vbCRLF & "---Product: " & product.InstallProperty("ProductName")
     msg = msg &  vbCRLF &"ProductCode: " & product.ProductCode
     msg = msg &  vbCRLF &"User SID: " & product.UserSid
     msg = msg &  vbCRLF &"Installed Context: " & MapContext(product.Context)

     msg = msg &  vbCRLF &vbCRLF &Indent2 & ProductProperty & ": " & product.InstallProperty(ProductProperty)
   
  Else 
  'Explanation of the properties at http://msdn.microsoft.com/en-us/library/aa369457(v=vs.85).aspx
  
   msg = msg & vbCRLF & vbCRLF & "---Product: " & product.InstallProperty("ProductName")
   msg = msg &  vbCRLF &"User SID: " & product.UserSid
   msg = msg &  vbCRLF &"Installed Context: " & MapContext(product.Context)
   
   msg = msg &  vbCRLF &vbCRLF & Indent1 & "   Product Properties:"
   msg = msg &  vbCRLF &Indent2 & "ProductName: " & product.InstallProperty("ProductName") 'Or "InstalledProductName"
   msg = msg &  vbCRLF &Indent2 & "ProductCode: " & product.ProductCode
   msg = msg &  vbCRLF &Indent2 & "PackageCode: " & product.InstallProperty("PackageCode")
   msg = msg &  vbCRLF &Indent2 & "VersionString: " & product.InstallProperty("VersionString")
   msg = msg &  vbCRLF &Indent2 & "VersionMajor: " & product.InstallProperty("VersionMajor")
   msg = msg &  vbCRLF &Indent2 & "VersionMinor: " & product.InstallProperty("VersionMinor")
   
   msg = msg &  vbCRLF &vbCRLF & Indent1 & "Installation Details:"
   msg = msg &  vbCRLF &Indent2 & "InstallDate: "   & product.InstallProperty("InstallDate")
   msg = msg &  vbCRLF &Indent2 & "Transforms: "   & product.InstallProperty("Transforms")
   msg = msg &  vbCRLF &Indent2 & "InstallLocation: "   & product.InstallProperty("InstallLocation")
   msg = msg &  vbCRLF &Indent2 & "InstallSource: "   & product.InstallProperty("InstallSource")
   msg = msg &  vbCRLF &Indent2 & "LocalPackage: "   & product.InstallProperty("LocalPackage")
   msg = msg &  vbCRLF &Indent2 & "AssignmentType: " & product.InstallProperty("AssignmentType")
   msg = msg &  vbCRLF &Indent2 & "InstanceType: "   & product.InstallProperty("InstanceType")
   msg = msg &  vbCRLF &Indent2 & "Authorized LUA App: "   & product.InstallProperty("AuthorizedLUAApp")

   msg = msg &  vbCRLF &vbCRLF & Indent1 & "Publisher and Registration Information"
   msg = msg &  vbCRLF &Indent2 & "Publisher: "   & product.InstallProperty("Publisher")
   msg = msg &  vbCRLF &Indent2 & "URLInfoAbout: "   & product.InstallProperty("URLInfoAbout")
   msg = msg &  vbCRLF &Indent2 & "URLUpdateInfo: "   & product.InstallProperty("URLUpdateInfo")
   msg = msg &  vbCRLF &Indent2 & "HelpLink: " & product.InstallProperty("HelpLink")
   msg = msg &  vbCRLF &Indent2 & "HelpTelephone: "  & product.InstallProperty("HelpTelephone")
   msg = msg &  vbCRLF &Indent2 & "ProductIcon: "   & product.InstallProperty("ProductIcon")
   msg = msg &  vbCRLF &Indent2 & "Language: "   & product.InstallProperty("Language")
   msg = msg &  vbCRLF &Indent2 & "RegCompany: "   & product.InstallProperty("RegCompany")
   msg = msg &  vbCRLF &Indent2 & "RegOwner: "   & product.InstallProperty("RegOwner")
    
  End If 
Next

CSI_EnumerateProducts = msg
End Function

Function CSI_GetProductProperty (ProductGUID, ProductProperty)

  UserSID = "S-1-1-0"
  InstallContextsToEnumerate = 7

  Set Products = oMSI.ProductsEx (ProductGUID, UserSID, InstallContextsToEnumerate)
  If NOT Products.count > 0 Then 
    CSI_GetProductProperty = "Product Not Installed."
    Exit Function
  End If 
  
  For Each product In products
  On Error Resume Next
    CSI_GetProductProperty = product.InstallProperty(ProductProperty)
    If NOT Err = 0 Then
      CSI_GetProductProperty = "No such property."
    End If
  On Error Goto 0
  Next
End Function

Function MapContext(context)
   Select Case (context)
		 Case 1  : MapContext = "Per-User Managed" 'MSIINSTALLCONTEXT_USERMANAGED
		 Case 2  : MapContext = "Per-User UN-manged" 'MSIINSTALLCONTEXT_USER
		 Case 3  : MapContext = "Alll Per-User (Managed and UN-managed)" 'MSIINSTALLCONTEXT_USERMANAGED + MSIINSTALLCONTEXT_USER
     Case 4  : MapContext = "Per-Machine" 'MSIINSTALLCONTEXT_MACHINE
     Case 5  : MapContext = "Per-Machine and Per-User Managed" 'MSIINSTALLCONTEXT_USERMANAGED + MSIINSTALLCONTEXT_MACHINE
     Case 6  : MapContext = "Per-Machine and Per-User UN-Managed" 'MSIINSTALLCONTEXT_USER + MSIINSTALLCONTEXT_MACHINE
     Case 7  : MapContext = "All 3 Contexts" 'MSIINSTALLCONTEXT_USERMANAGED + MSIINSTALLCONTEXT_USER + MSIINSTALLCONTEXT_MACHINE      
   End Select
End Function
