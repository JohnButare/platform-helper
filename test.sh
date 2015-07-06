#!/usr/bin/env bash
. function.sh
	if [[ -f "$WINDIR/system32/Narrator.exe" ]] && ask "Disable narrator"; then
		echo "Disabling narrator shortcut key..."
		mv "$WINDIR/system32/Narrator.exe" "$WINDIR/system32/NarratorDisable.exe" || return
	fi
