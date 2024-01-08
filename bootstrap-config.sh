locale="en_US.UTF-8"
timezone="America/Denver"
timezoneWin="Mountain Standard Time" # tzutil.exe /l

# user
user="jjbutare"
dropboxCompany="JuntosHoldings"
dropboxUser="John Butare"

# bootstrap
# - bootStrapBin - initial bin directory UNC in the format //[USER@]SERVER/SHARE[/DIRS][:PROTOCOL]
# - bootstrapInstall - installation directory, if unset find it
bootstrapBin="//ender.hagerman.butare.net/system/usr/local/data/bin"
bootstrapInstall="//ender.butare.net/public/install"
bootstrapProxyServer="proxy.butare.net" boostrapProxyPort="3128"
bootstrapProxy="http://$bootstrapProxyServer:$boostrapProxyPort"
bootstrapDns1="10.10.100.8"
bootstrapDns2="10.10.100.7"

# system
network="hagerman"
workgroup="$network"
wifi="Wiggin"
baseDomain="butare.net"
domain="$network.$baseDomain"
systemUser="wsystem"
confDir="Dropbox/network/system"
hostTimeout="200"

#
# servers
#

servers="pi1,pi2,pi3,pi4,pi5,pi6,pi7,pi9,pi10,pi11,rp1,rp2,rp3,rp4,zima1,zima2"

# proxy
noProxy="localhost,127.0.0.1,.$baseDomain,.$domain,web,www,autoproxy,.releases.ubuntu.com,.internal,.local"
noProxy+=",10.96.0.0/12,192.168.59.0/24,192.168.49.0/24,192.168.39.0/24" # minikube - https://minikube.sigs.k8s.io/docs/handbook/vpn_and_proxy/

# other
mqttServer="mosquitto"

#
# HashiCorp
#

hashiDnsDomain="service"
hashiCredentialPath=""
hashiCertificateDevice="$CLOUD/data/app/CryFS/personal" hashiCertificateDir="data/hashi"
hashiServers="pi1,pi2,pi3,pi4"
hashiClients="pi6,pi7,pi9,pi10,pi11,rp1,rp2,rp3,rp4"
hashiVaultServers="pi2,pi1"

# HashiCorp Testing
hashiTestCredentialPath=""
#hashiTestCertificateDevice="" hashiTestCertificateDir="$UDATA/app/hashi"
hashiTestCertificateDevice="$CLOUD/data/VeraCrypt/personal.hc" hashiTestCertificateDir="data/hashi"
hashiTestServers="pi20,pi21"
hashiTestClients="pi22"
hashiTestVaultServers="pi20,pi21"

#
# networks
#

# networks - list of networks that the system can connect to, format is NETWORK@DNS_IP
# hagerman 10.10.100.8|7 (lb3|lb2)
# dt 10.10.0.91-94
networks="hagerman@10.10.100.8,dt@10.10.0.91,hagerman@10.10.100.7,dt@10.10.0.92"

# external network
externalTimeServer="time.apple.com"

# dt network
dtUser="jbutare"
dtAdDomain="coexist" 				# Active Directory domain
dtDomain="coexist.local"		# DNS Domain

# hagerman network
hagermanUser="jjbutare"
hagermanBaseDomain="butare.net" hbd="$hagermanBaseDomain"
hagermanDomain="hagerman.$hagermanBaseDomain" hd="$hagermanDomain"

hagermanCameraServers="BackShedCamera,BackYardEastCamera,FrontPatioCamera,FrontYardEastCamera,FrontYardWestCamera,LivingRoomCamera"
hagermanBackupUser="$user"
hagermanGitServer="git.$hbd"																# Git Server
hagermanProxyServers="proxy.$hbd:3128" 											# Forward Proxy Server (Squid)
hagermanSyslogServer="syslog.$hbd"													# syslog server for remote system logs
hagermanTimeServer="time.butare.net"												# Time Server
hagermanVip="10.10.100.6" 																	# Virtual IP Address
hagermanWireguardPort="51820"																# WireGuard Port
