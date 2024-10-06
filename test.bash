#!/usr/bin/env bash
PLATFORM_DIR="${BASH_SOURCE[0]%/*}"
. "$PLATFORM_DIR/function.sh" || exit
. "$PLATFORM_DIR/app.sh" || exit
. "$PLATFORM_DIR/color.sh" || exit

echo "test BASH script"
