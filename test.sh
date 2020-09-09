#!/usr/bin/env zsh
. function.sh || exit

 su - homebridge <<!
$(credential get homebridge)
ssh $USER@$HOSTNAME ls
!
echo $?
