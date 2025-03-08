isEquals()
{
	local expect="$1"; shift
	printf "isEquals ("; hilightp "$(RunLogArgs "$@")"; printf "): "
	local actual; actual="$($@)" || { HilightErrEnd "failed"; return 1; }

	[[ "$actual" == "$expect" ]] && { echo "ok"; return; }
	EchoEnd "${RED}failed${RESET} (expected='$expect' actual='$actual')"
	return 1
}

varEquals()
{
	local var="$1" expect="$2"; shift 2
	printf "varEquals ("; hilightp "$(RunLogArgs "$@")"; printf "): "
	"$@" || { HilightErrEnd "failed"; return 1; }

	actual="$(eval "echo \$$var")"
	[[ "$actual" == "$expect" ]] && { echo "ok"; return; }
	EchoEnd "${RED}failed${RESET} (expected='$expect' $var='$actual')"
	return 1
}

isFalse()
{
	printf "isFalse ("; hilightp "$(RunLogArgs "$@")"; printf "): "
	"$@" || { echo "ok"; return; }
	HilightErrEnd "failed"; return 1
}


isTrue()
{
	printf "isTrue ("; hilightp "$(RunLogArgs "$@")"; printf "): "
	"$@" && { echo "ok"; return; }
	HilightErrEnd "failed"; return 1
}
