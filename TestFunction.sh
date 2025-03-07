# description: test functions from ZSH or Bash
#       usage: . TestFunction.sh
. "$BIN/function.sh" || return # re-load functions
. "$BIN/script.sh" || return
. "$BIN/ScriptTest.sh" || return

all()
{
	getIpAddress4 || return
	getIpAddress6 || return
}

getIpAddress4()
{
	header "GetIpAddress4"
	isFalse IsIpAddress4 "bogus" || return
	isFalse IsIpAddress4 "256.0.0.0" || return
	isFalse IsIpAddress4 "256.0.0.0.1" || return
	isFalse IsIpAddress4 "256.0.0.0.912" || return
	isTrue IsIpAddress4 "192.168.1.1" || return
}

getIpAddress6()
{
	header "GetIpAddress6"
	isFalse IsIpAddress6 "bogus" || return
	isTrue IsIpAddress6 "1:2:3:4:5:6:7:8" || return
	isTrue IsIpAddress6 "1::" || return
	isTrue IsIpAddress6 "1:2:3:4:5:6:7::" || return
	isTrue IsIpAddress6 "1::8" || return
	isTrue IsIpAddress6 "1:2:3:4:5:6::8" || return
	isTrue IsIpAddress6 "1:2:3:4:5:6::8" || return
	isTrue IsIpAddress6 "1::7:8" || return
	isTrue IsIpAddress6 "1:2:3:4:5::7:8" || return
	isTrue IsIpAddress6 "1:2:3:4:5::8" || return
	isTrue IsIpAddress6 "1::6:7:8" || return
	isTrue IsIpAddress6 "1:2:3:4::6:7:8" || return
	isTrue IsIpAddress6 "1:2:3:4::8" || return
	isTrue IsIpAddress6 "1::5:6:7:8" || return
	isTrue IsIpAddress6 "1:2:3::5:6:7:8" || return
	isTrue IsIpAddress6 "1:2:3::8" || return
	isTrue IsIpAddress6 "1::4:5:6:7:8" || return
	isTrue IsIpAddress6 "1:2::4:5:6:7:8" || return
	isTrue IsIpAddress6 "1:2::8" || return
	isTrue IsIpAddress6 "1::3:4:5:6:7:8" || return
	isTrue IsIpAddress6 "1::3:4:5:6:7:8" || return
	isTrue IsIpAddress6 "1::8" || return
	isTrue IsIpAddress6 "::2:3:4:5:6:7:8" || return
	isTrue IsIpAddress6 "::2:3:4:5:6:7:8" || return
	isTrue IsIpAddress6 "::8" || return
	isTrue IsIpAddress6 "::" || return
	isTrue IsIpAddress6 "fe80::7:8%eth0" || return
	isTrue IsIpAddress6 "fe80::7:8%1" || return
	isTrue IsIpAddress6 "::255.255.255.255" || return
	isTrue IsIpAddress6 "::ffff:255.255.255.255" || return
	isTrue IsIpAddress6 "::ffff:0:255.255.255.255" || return
	isTrue IsIpAddress6 "2001:db8:3:4::192.0.2.33" || return
	isTrue IsIpAddress6 "64:ff9b::192.0.2.33" || return
}

all
