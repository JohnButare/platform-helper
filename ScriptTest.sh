isTrue()
{
	printf "isTrue ("; hilightp "$(RunLogArgs "$@")"; printf "): "
	"$@" && { echo "ok"; return; }
	HilightErrEnd "failed"; return 1
}

isFalse()
{
	printf "isFalse ("; hilightp "$(RunLogArgs "$@")"; printf "): "
	"$@" || { echo "ok"; return; }
	HilightErrEnd "failed"; return 1
}
