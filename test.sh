#!/usr/bin/env zsh
. function.sh || exit

	case "aa$HOSTNAME" in
		jane|pants) i $mac || return;;
		oversoul) i hp9020 $pc || return;;
		rosie) i MsiMotherboard $pc || return;;
		ultron) i $pc || return;;
	esac
