#!/usr/bin/env zsh
. "${${(%):-%x}:h}/function.sh" app script color|| exit
SourceIfExists "$ZPLUG_REPOS/mafredri/zsh-async/async.zsh" || exit

echo "test ZSH script"
