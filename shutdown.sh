#!/usr/bin/env bash
. function.sh

function log() { echo "$(GetTimeStamp): $1" >> /var/log/shutdown.log; }

log "system is shutting down"

log "shutdown script has finished"