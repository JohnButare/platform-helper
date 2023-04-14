#!/usr/bin/env bash
. app.sh || exit

hosts="$(DomotzHelper down)" || exit
IFS=$'\n' ArrayMake hosts "$hosts"

for host in "${hosts[@]}"; do
	name="$(echo "$host" | cut -d"," -f1)"
	mac="$(echo "$host" | cut -d"," -f2)"
	dns="$(MacLookupEthers "$mac")" || return
	log1 "name=$name mac=$mac dns=$dns"
	UniFiController disconnect $mac
done

