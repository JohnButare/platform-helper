OfficeVersion="15"
OfficeTitle=".* - "
WordProgram=""
WordFastStartTitle="wfs.* - Word"
OfficeArchitecture="x86"
OfficeBits="32"
Office365=""

if [[ -d "$P/Microsoft Word.app" ]]; then
	WordProgram="$P/Microsoft Word.app"

elif [[ -f "$P/Microsoft Office/root/Office16/winword.exe" ]]; then
	OfficeDir="$P/Microsoft Office/root/Office16"
	Office365="true"

elif [[ -f "$P32/Microsoft Office/root/Office16/WinWord.exe" ]]; then
	OfficeDir="$P32/Microsoft Office/root/Office16"
	
else
	OfficeDir=""
	return 1
fi

[[ ! $WordProgram ]] && WordProgram="$OfficeDir/WinWord.exe"

# x64 Office if we are running under x64 OS and Office is installs to $P
if [[ "$(OsArchitecture)" == "x64" && "$OfficeDir" =~ ^$P/ ]]; then
	OfficeArchitecture=x64
	OfficeBits=64
fi

return 0
