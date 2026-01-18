# description: test functions from ZSH or Bash
#       usage: . TestFunction.sh
. "$BIN/function.sh" "" || return # re-load functions
. "$BIN/color.sh" || return
. "$BIN/script.sh" || return
. "$BIN/ScriptTest.sh" || return

allTest()
{
	HeaderBig "Running All Function Tests"
	getIpAddress4Test || return
	getIpAddress6Test || return
	isLocalHostTest || return
	getSshPortTest || return
	getSshHostTest || return
	getSshUserTest || return
	getUriTest || return
}

getIpAddress4Test()
{
	header "GetIpAddress4"

	isFalse IsIpAddress4 "bogus" || return
	isFalse IsIpAddress4 "256.0.0.0" || return
	isFalse IsIpAddress4 "256.0.0.0.1" || return
	isFalse IsIpAddress4 "256.0.0.0.912" || return
	isTrue IsIpAddress4 "192.168.1.1" || return
}

getIpAddress6Test()
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

isLocalHostTest()
{
	header "IsLocalHost"

	isFalse IsLocalHost "bogus" || return
	isTrue IsLocalHost "" || return
	isTrue IsLocalHost "localhost" || return
	isTrue IsLocalHost "127.0.0.1" || return
	
	isFalse IsLocalHost "::2" || return
	isTrue IsLocalHost "::1" || return
	isTrue IsLocalHost "00::0:1" || return

	isTrue IsLocalHost "$(GetHostname)" || return
	isTrue IsLocalHost "$(GetHostname).$(GetDnsDomain)" || return
}

getSshHostTest()
{
	header "GetSshHost"

	local ip="fd31:31b1:f03f:d348:4ca5:dfff:fe81:ef32"
	isEquals "$ip" GetSshHost "$ip" || return
	isEquals "$ip" GetSshHost "user@$ip:22" || return
	varEquals host "$ip" GetSshHost "user@$ip:22" host || return
}

getSshPortTest()
{
	header "GetSshPort"

	isEquals "" GetSshPort "host" || return
	isEquals "22" GetSshPort "user@host:22" || return

	local ip="192.168.1.1"
	isEquals "" GetSshPort "$ip" || return
	isEquals "22" GetSshPort "user@$ip:22" || return
	varEquals port 22 GetSshPort "$ip:22" port || return

	local ip="fd31:31b1:f03f:d348:4ca5:dfff:fe81:ef32"
	isEquals "" GetSshPort "$ip" || return
	isEquals "22" GetSshPort "user@$ip:22" || return
	varEquals port 22 GetSshPort "$ip:22" port || return
}

getSshUserTest()
{
	header "GetSshUser"
	isEquals "user" GetSshUser "user@host:port" || return 
}

# getUriTest - PROTOCOL://SERVER:PORT[/DIRS]
getUriTest()
{
	header "GetUri"	
	getUriDo "protocol" "server" "port" "dir1/dir2" || return
	getUriDo "protocol" "10.10.100.1" "port" "dir1/dir2" || return
	getUriDo "protocol" "1:2:3:4:5:6:7:8" "port" "dir1/dir2" || return
	getUriDo "protocol" "1:2:3:4:5:6:7:8" "" "dir1/dir2" || return
}

getUriDo()
{
	local protocol="$1" server="$2" port="$3" dirs="$4"
	local uri="$(UriMake "$protocol" "$server" "$port" "$dirs")"

	isEquals "$protocol" GetUriProtocol "$uri" || return
	isEquals "$server" GetUriServer "$uri" || return
	isEquals "$port" GetUriPort "$uri" || return
	isEquals "$dirs" GetUriDirs "$uri" || return
}

# run tests
[[ ! $@ ]] && { all; return; }
for test in "$@"; do "$(LowerCaseFirst "$test")"Test || return; done
