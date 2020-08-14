#!/usr/bin/env zsh
. function.sh || exit

 cat kea-dhcp4-wiggin-reservations.json | sed '/^[	 ]*\/\//d' | head -10