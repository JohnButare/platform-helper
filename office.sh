OfficeVersion="15"
OfficeTitle=".* - "
WordFastStartTitle="Word Fast Start.* - Word"
OfficeArchitecture="x86"
OfficeBits="32"
Office365=""

if [[ -f "$P/Microsoft Office 15/root/office15/WinWord.exe" ]]; then
	OfficeDir="$P/Microsoft Office 15/root/office15"
	Office365="true"

elif [[ -f "$P32/Microsoft Office 15/root/office15/WinWord.exe" ]]; then
	OfficeDir="$P32/Microsoft Office 15/root/office15"
	Office365="true"

elif [[ -f "$P/Microsoft Office/Office15/WinWord.exe" ]]; then
	OfficeDir="$P/Microsoft Office/Office15"

elif [[ -f "$P32/Microsoft Office/Office15/WinWord.exe" ]]; then
	OfficeDir="$P32/Microsoft Office/Office15"
	OfficeVersion="15"

elif [[ -f "$P/Microsoft Office/Office14/WinWord.exe" ]]; then
	OfficeDir="$P/Microsoft Office/Office14"
	OfficeVersion="14"
	OfficeTitle="* - Microsoft"
	WordFastStartTitle="Word Fast Start.* - Microsoft Word"
	
elif [[ -f "$P32/Microsoft Office/Office14/WinWord.exe" ]]; then
	OfficeDir="$P32/Microsoft Office/Office14"
	OfficeVersion="14"
	OfficeTitle="* - Microsoft"
	WordFastStartTitle="Word Fast Start.* - Microsoft Word"
	
elif [[ -f "$P32/Microsoft Office/Office12/WinWord.exe" ]]; then
	OfficeDir="$P32/Microsoft Office/Office12"
	OfficeVersion="11"
	OfficeTitle="* - Microsoft"
	WordFastStartTitle="Word Fast Start.* - Microsoft Word"
	
elif [[ -f "$P32/Microsoft Office/Office11/WinWord.exe" ]]; then
	OfficeDir="$P32/Microsoft Office/Office11"
	OfficeVersion="11"
	OfficeTitle="* - Microsoft"
	WordFastStartTitle="Word Fast Start.* - Microsoft Word"

else
	OfficeDir=""
	return 1
fi

# x64 Office if we are running under x64 OS and Office is installs to $P
if [[ "$(OsArchitecture)" == "x64" && "$OfficeDir" =~ ^$P/ ]]; then
	OfficeArchitecture=x64
	OfficeBits=64
fi

return 0
