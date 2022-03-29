[[ $FZF_CHECKED || ! -d "$HOME/.fzf" ]] && return
FZF_CHECKED="true"

. "$HOME/.fzf/shell/completion.$PLATFORM_SHELL" || return
. "$HOME/.fzf/shell/key-bindings.$PLATFORM_SHELL" || return
_fzf_complete_ssh() { _fzf_complete +m -- "$@" < <(command cat "$UBIN/hosts" 2> /dev/null); }
_fzf_complete_ping() { _fzf_complete +m -- "$@" < <(command cat "$UBIN/hosts" 2> /dev/null); }
