OfficeVersion="15"
OfficeTitle=".* - "
WordProgram=""
WordFastStartTitle="wfs.* - Word"
OfficeArchitecture="x86"
OfficeDir=""
OfficeTemplates="$UDATA/app/office/templates"; IsPlatform win && OfficeTemplates="$WIN_HOME/data/app/office/templates"

if IsPlatform mac; then
	WordProgram="$P/Microsoft Word.app"
	return
fi

if [[ -f "$P/Microsoft Office/root/Office16/winword.exe" ]]; then
	OfficeDir="$P/Microsoft Office/root/Office16"
elif [[ -f "$P32/Microsoft Office/root/Office16/WinWord.exe" ]]; then
	OfficeDir="$P32/Microsoft Office/root/Office16"
else
	return 0
fi

WordProgram="$OfficeDir/WINWORD.EXE"
