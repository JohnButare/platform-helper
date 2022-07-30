locale="en_US.UTF-8"
timezone="America/Denver"
timezoneWin="Mountain Standard Time" # tzutil.exe /l
timeServer="time.butare.net"

# bootstrap
bootstrapBin="//ender.hagerman.butare.net/system/usr/local/data/bin" # initial bin directory UNC (//[USER@]SERVER/SHARE[/DIRS][:PROTOCOL])
bootstrapProxyServer="proxy.butare.net" boostrapProxyPort="3128"
bootstrapProxy="http://$bootstrapProxyServer:$boostrapProxyPort"
bootstrapDns1="10.10.100.8"
bootstrapDns2="10.10.100.7"

# user
user="jjbutare"
dropboxCompany="Juntos Holdings"
dropboxUser="John Butare"

# system
network="hagerman"
workgroup="$network"
baseDomain="butare.net"
domain="$network.$baseDomain"
systemUser="wsystem"
confDir="$CLOUD/network/system"

#
# servers
#

# proxy
noProxy="localhost,127.0.0.1,.$baseDomain,.$domain,web,www,autoproxy,.releases.ubuntu.com"

# other
mqttServer="mosquitto"

#
# HashiCorp
#

hashiDnsDomain="service"
hashiCredentialPath=""
hashiCertificateDevice="$CDATA/VeraCrypt/personal.hc" hashiCertificateDir="data/hashi"
hashiServers="pi1,pi2,pi3"
hashiClients="pi4"
hashiVaultServers="pi2,pi1"

# HashiCorp Testing
hashiTestCredentialPath=""
#hashiTestCertificateDevice="" hashiTestCertificateDir="$UDATA/app/hashi"
hashiTestCertificateDevice="$CDATA/VeraCrypt/personal.hc" hashiTestCertificateDir="data/hashi"
hashiTestServers="pi20,pi21"
hashiTestClients="pi22"
hashiTestVaultServers="pi20,pi21"

#
# networks
#

# networks - list of available networks that the system can be connected to
networks="hagerman@10.10.100.10,hagerman@10.10.100.11" # list of DNS servers for the specified network in the format NETWORK@IP
hagermanBaseDomain="butare.net" hbd="$hagermanBaseDomain"
hagermanDomain="hagerman.$hagermanBaseDomain" hd="$hagermanDomain"
hagermanCredentialPaths="CloudFlare,domotz,JumpCloud,LastPass,namecheap,ssh,system,unifi"
hagermanNas="nas3.$hd"																			# NAS Server
hagermanVip="10.10.100.6" 																	# Virtual IP Address

hagermanCameraServers="BackShedCamera,BackYardEastCamera,ChickenYardNorthCamera,ChickenYardSouthCamera,FrontPatioCamera,FrontYardEastCamera,FrontYardWestCamera,LivingRoomCamera"
hagermanDhcpServers="pi1,pi2,pi3,pi4"
hagermanDnsServers="pi1,pi2,pi3,pi4"
hagermanBackupUser="$user"
hagermanBackupServers="backup2.$hbd,backup1.$hbd" 					# backup (Borg)
hagermanHassServers="pi9.$hbd,pi11.$hbd"										# Home Assistant
hagermanLbServers="pi1.$hd,pi2.$hd,pi3.$hd,pi4.$hd"					# Load Balancer (NGINX reverse proxy)
hagermanProxyServers="proxy.$hbd:3128" 											# Forward Proxy (Squid)
hagermanWireguardServers="pi4.$hd,pi3.$hd,pi2.$hd,pi1.$hd" 	# Wireguard VPN
hagermanWireguardPort="51820"
