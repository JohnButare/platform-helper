locale="en_US.UTF-8"
timezone="America/Denver"
timezoneWin="Mountain Standard Time" # tzutil.exe /l
timeServer="time.butare.net"

# user
user="jjbutare"
dropboxCompany="Juntos Holdings"
dropboxUser="John Butare"

# bootstrap
# - bootStrapBin - initial bin directory UNC in the format //[USER@]SERVER/SHARE[/DIRS][:PROTOCOL]
# - bootstrapInstall - installation directory, if unset find it
bootstrapBin="//ender.hagerman.butare.net/system/usr/local/data/bin"
bootstrapInstall="//ender.butare.net/public/documents/data/install"
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
noProxy+=",10.96.0.0/12,192.168.59.0/24,192.168.49.0/24,192.168.39.0/24" # minikube - https://minikube.sigs.k8s.io/docs/handbook/vpn_and_proxy/

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
# hagerman 10.10.100.8|7 (lb3|lb2)
# dt 10.10.0.91-94
networks="hagerman@10.10.100.8,dt@10.10.0.91,hagerman@10.10.100.7,dt@10.10.0.92"
# networks="hagerman@10.10.100.99" # test

# dt network
dtUser="jbutare"
dtAdDomain="coexist" 				# Active Directory domain
dtDomain="coexist.local"		# DNS Domain

# hagerman network
hagermanUser="jjbutare"
hagermanBaseDomain="butare.net" hbd="$hagermanBaseDomain"
hagermanDomain="hagerman.$hagermanBaseDomain" hd="$hagermanDomain"
hagermanCredentialPaths="CloudFlare,domotz,JumpCloud,LastPass,namecheap,ssh,system,unifi"
hagermanNas="nas3.$hd"																			# NAS Server
hagermanVip="10.10.100.6" 																	# Virtual IP Address

hagermanCameraServers="BackShedCamera,BackYardEastCamera,ChickenYardNorthCamera,ChickenYardSouthCamera,FrontPatioCamera,FrontYardEastCamera,FrontYardWestCamera,LivingRoomCamera"
hagermanDhcpServers="pi1,pi2,pi3,pi4"
hagermanDnsIps="10.10.100.8,10.10.100.7"
hagermanDnsServers="pi1.$hbd,pi2.$hbd,pi3.butare.net,pi4.$hbd"
hagermanBackupUser="$user"
hagermanBackupServers="backup2.$hbd,backup1.$hbd" 					# backup (Borg)
hagermanHassServers="pi9.$hbd,pi11.$hbd"										# Home Assistant
hagermanLbServers="pi1.$hd,pi2.$hd,pi3.$hd,pi4.$hd"					# Load Balancer (NGINX reverse proxy)
hagermanProxyServers="proxy.$hbd:3128" 											# Forward Proxy (Squid)
hagermanWireguardServers="pi4.$hd,pi3.$hd,pi2.$hd,pi1.$hd" 	# Wireguard VPN
hagermanWireguardPort="51820"
