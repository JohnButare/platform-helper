#!/usr/bin/env bash
. function.sh

function log() { echo "$(GetTimeStamp): $1" >> /var/log/logoff.log; }

log "logging off $USER"

log "$USER logoff script has finished"