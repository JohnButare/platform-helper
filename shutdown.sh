#!/usr/bin/env bash
. function.sh

log="/var/log/shutdown.log"
function log() { echo "$(GetTimeStamp): $1" | tee -a "$log"; }

log "system is shutting down"
vmware close | tee -a "$log"
log "shutdown script has finished"