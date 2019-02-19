# Window Commands - Win [class] <title|class>, Au3Info.exe to get class
WinActivate() { AutoItScript WinActivate "${@}"; }
WinClose() { AutoItScript WinClose "${@}"; }
WinList() { join -a 2 -e EMPTY -j 1 -t',' -o '2.1,1.2,2.2,2.3' <(ProcessListWin | sort -t, -k1) <(AutoItScript WinList | sort -t, -k1); } # causes error in Synology DSM
WinGetState() {	AutoItScript WinGetState "${@}"; }
WinGetTitle() {	AutoItScript WinGetTitle "${@}"; }
WinSetState() { AutoItScript WinSetState "${@}"; }

WinExists() { WinGetState "${@}"; (( $? & 1 )); }
WinVisible() { WinGetState "${@}"; (( $? & 2 )); }
WinEnabled() { WinGetState "${@}"; (( $? & 4 )); }
WinActive() { WinGetState "${@}"; (( $? & 8 )); }
WinMinimized() { WinGetState "${@}"; (( $? & 16 )); }
WinMaximized() { WinGetState "${@}"; (( $? & 32)); }
