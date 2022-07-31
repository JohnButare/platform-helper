#!/usr/bin/env bash
. function.sh

echo -n "TTY="; IsTty && echo yes || echo no
echo -n "IsInteractiveShell="; IsInteractiveShell && echo yes || echo no


echo -n 123; CurrentColumn