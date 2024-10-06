#!/usr/bin/env zsh
PLATFORM_DIR="${${(%):-%x}:h}"
PLATFORM_DIR="/usr/local/data/bin"
. "$PLATFORM_DIR/function.sh" || exit
. "$PLATFORM_DIR/app.sh" || exit
. "$PLATFORM_DIR/color.sh" || exit
SourceIfExists "$ZPLUG_REPOS/mafredri/zsh-async/async.zsh" || exit


echo "test ZSH script"
ScriptDir