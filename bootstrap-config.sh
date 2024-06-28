locale="en_US.UTF-8"
timezone="America/Denver"
timezoneWin="Mountain Standard Time" # tzutil.exe /l

# system
network="hagerman"
wifi="Wiggin"
systemUser="wsystem"
confDir="Dropbox/network/system"
hostTimeout="200"

#
# servers
#

servers="bl1,bl2,pi1,pi2,pi3,pi4,pi5,pi6,pi7,pi8,pi9,pi10,pi11,pi12,pi13,rp1,rp2,rp3,rp4"

# other
mqttServer="mosquitto"

#
# HashiCorp
#

hashiDnsDomain="service"
hashiCredentialPath=""
hashiCertificateDevice="$CLOUD/data/app/CryFS/personal" hashiCertificateDir="data/hashi"
hashiServers="pi1,pi2,pi3,pi4"
hashiClients="pi6,pi7,pi8,pi9,pi10,pi11,rp1,rp2,rp3,rp4"
hashiVaultServers="pi2,pi1"

# HashiCorp Testing
hashiTestCredentialPath=""
#hashiTestCertificateDevice="" hashiTestCertificateDir="$UDATA/app/hashi"
hashiTestCertificateDevice="$CLOUD/data/VeraCrypt/personal.hc" hashiTestCertificateDir="data/hashi"
hashiTestServers="pi20,pi21"
hashiTestClients="pi22"
hashiTestVaultServers="pi20,pi21"

#
# network
#

defaultDomain="hagerman"

# networks - list of known networks, check the DNS servers, format is NETWORK@DNS_IP
# hagerman 10.10.100.8|7 (lb3|lb2)
# sandia 172.29.128.1 - yes (IPOC) no (office)
# sandia 134.253.181.25|16.5 - yes (VPN, office)
networks="hagerman@10.10.100.8,sandia@134.253.181.25,hagerman@10.10.100.7,sandia@134.253.16.5"

# external network
externalTimeServer="time.apple.com"

# proxy common
noProxyLocal="localhost,127.0.0.0/8,::1"
noProxyRemote=".releases.ubuntu.com,.internal,.local"

# hagerman network
hagermanUser="jjbutare"
hagermanBinUnc="//ender.hagerman.butare.net/system/usr/local/data/bin"
hagermanBootstrapDir=""
hagermanInstallUnc="//ender.butare.net/public/install"
hagermanDnsBaseDomain="butare.net"
hagermanDnsDomain="hagerman.$hagermanDnsBaseDomain"
hagermanDns1="10.10.100.8"
hagermanDns2="10.10.100.7"
hagermanDnsSearch="$hagermanDnsBaseDomain $hagermanDnsDomain"

hagermanNoProxy="$noProxyLocal,.$hagermanDnsBaseDomain,web,www,autoproxy,$noProxyRemote"
hagermanNoProxy+=",10.96.0.0/12,192.168.59.0/24,192.168.49.0/24,192.168.39.0/24" # minikube - https://minikube.sigs.k8s.io/docs/handbook/vpn_and_proxy/

hagermanCameraServers="BackShedCamera,BackYardEastCamera,FrontPatioCamera,FrontYardEastCamera,FrontYardWestCamera,LivingRoomCamera"
hagermanBackupUser="$user"
hagermanGitServer="git.$hagermanDnsBaseDomain"							# Git Server
hagermanProxyServer="proxy.$hagermanDnsBaseDomain:3128"			# Forward Proxy Server (Squid), service=proxy.$hbd:3128 ender=10.10.100.9:3128
hagermanSyslogServer="syslog.$hagermanDnsBaseDomain"				# syslog server for remote system logs
hagermanTimeServer="time.butare.net"												# Time Server
hagermanVip="10.10.100.6" 																	# Virtual IP Address
hagermanWireguardPort="51820"																# WireGuard Port

# sandia network
sandiaUser="jjbutar"
sandiaBinUnc=""
sandiaBookmarks="https://ados.sandia.gov/NG/SysAdminTeam/_git/jjbutare-bookmarks"
sandiaBootstrapDir="/mnt/c/Users/jjbutar/OneDrive - Sandia National Laboratories/data/download"
sandiaGitServer="ados.sandia.gov"
sandiaInstallUnc=""
sandiaDnsBaseDomain="sandia.gov"
sandiaDnsDomain="srn.$sandiaDnsBaseDomain"
sandiaDns1="134.253.181.25"
sandiaDns2="134.253.16.5"
sandiaDnsSearch="$sandiaDnsBaseDomain $sandiaDnsDomain ca.$sandiaDnsBaseDomain"
sandiaProxyServer="proxy.$sandiaDnsBaseDomain:80"
sandiaNoProxy="$noProxyLocal,.$sandiaDnsBaseDomain,$noProxyRemote"