locale="en_US.UTF-8"
timezone="America/Denver"
timezoneWin="Mountain Standard Time" # tzutil.exe /l
timeServer="time.butare.net"

# user
user="jjbutare"
dropboxCompany="Juntos Holdings"
dropboxUser="John Butare"

# bootstrap
bootstrapUser="$user"
bootstrapBin="//$bootstrapUser@ender.butare.net/system/usr/local/data/bin" # initial bin directory UNC (//[USER@]SERVER/SHARE[/DIRS][:PROTOCOL])
bootstrapProxyServer="proxy.butare.net" boostrapProxyPort="3128"
bootstrapProxy="http://$bootstrapProxyServer:$boostrapProxyPort"
bootstrapDns1="10.10.100.8"
bootstrapDns2="10.10.100.7"

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
noProxy="localhost,127.0.0.1,.$baseDomain,.$domain,web,www,autoproxy,.releases.ubuntu.com,.internal,.local"

# other
mqttServer="mosquitto"

#
# HashiCorp
#

hashiDnsDomain="service"
hashiCredentialPath=""
hashiCertificateDevice="$CLOUD/data/VeraCrypt/personal.hc" hashiCertificateDir="data/hashi"
hashiServers="pi1,pi2,pi3"
hashiClients="pi4"
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
networks="hagerman@10.10.100.8,hagerman@10.10.100.7" # list of 
networks+="dt@10.10.0.91,dt@10.10.0.92,dt@10.10.0.93,dt@10.10.0.94"

# hagerman network
hagermanBaseDomain="butare.net" hbd="$hagermanBaseDomain"
hagermanDomain="hagerman.$hagermanBaseDomain" hd="$hagermanDomain"
hagermanCredentialPaths="CloudFlare,domotz,JumpCloud,LastPass,namecheap,ssh,system,unifi"
hagermanNas="nas3.$hd"																			# NAS Server
hagermanVip="10.10.100.6" 																	# Virtual IP Address

hagermanCameraServers="BackShedCamera,BackYardEastCamera,ChickenYardNorthCamera,ChickenYardSouthCamera,FrontPatioCamera,FrontYardEastCamera,FrontYardWestCamera,LivingRoomCamera"
hagermanDhcpServers="pi1,pi2,pi3,pi4"
hagermanDnsIps="10.10.100.8,10.10.100.7"
hagermanDnsServers="pi1,pi2,pi3,pi4"
hagermanBackupUser="$user"
hagermanBackupServers="backup2.$hbd,backup1.$hbd" 					# backup (Borg)
hagermanHassServers="pi9.$hbd,pi11.$hbd"										# Home Assistant
hagermanLbServers="pi1.$hd,pi2.$hd,pi3.$hd,pi4.$hd"					# Load Balancer (NGINX reverse proxy)
hagermanProxyServers="proxy.$hbd:3128" 											# Forward Proxy (Squid)
hagermanWireguardServers="pi4.$hd,pi3.$hd,pi2.$hd,pi1.$hd" 	# Wireguard VPN
hagermanWireguardPort="51820"
