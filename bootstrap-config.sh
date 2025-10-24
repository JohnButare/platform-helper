locale="en_US.UTF-8"
timezone="America/Denver"
timezoneWin="Mountain Standard Time" # tzutil.exe /l

# system
network="butare"
wifi="Wiggin"
systemUser="wsystem"
confDir="Dropbox/network/system"
hostTimeout="200"

#
# servers
#

servers="bl3,bl4,pi1,pi2,pi3,pi4,pi5,pi6,pi7,pi8,pi9,pi10,rp1,rp2,rp3,rp4"

# other
mqttServer="mosquitto"

#
# HashiCorp
#

hashiDnsDomain="service"
hashiCredentialPath=""
hashiCertificateDevice="$CLOUD/data/app/CryFS/personal" hashiCertificateDir="data/hashi"
hashiServers="pi1,pi2,pi3,pi4,pi5"
hashiClients="pi6,pi7,pi8,pi9,pi10,pi11,rp1,rp2,rp3,rp4"
hashiVaultServers="pi4,pi3,pi1"

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

defaultDomain="butare"

# networks - list of known networks, format is NETWORK@IP[:PROTOCOL][-DOMAIN](dns)
# - protocol - protocol used to check the IP, ping|dns|nfs|smb|ssh|wg, wg=WireGuard port
# - domain - if specified, the domain the computer must be in to use this network
# - examples
#   - butare 10.10.100.8|7 (lb3|lb2)
#   - sandia 10.248.0.3 - gateware from trace route
networks="sandia@10.248.0.3:ping-sandia,butare@10.10.100.8:dns,butare@10.10.100.7:dns,sandia@134.252.10.16:dns-sandia"

# external network
externalTimeServer="time.apple.com"

# proxy common
noProxyLocal="localhost,127.0.0.0/8,::1"
noProxyRemote=".releases.ubuntu.com,.internal,.local"

# butare network
butareUser="jjbutare"
butareBinUnc="//ender.butare.net/system/usr/local/data/bin"
butareBootstrapCloudDir=""
butareInstallUnc="//ender.butare.net/public/install"
butareNetworkPrefix="2606:a300:9024:308"
butareNetworkPrefixLength="64"
butareDnsBaseDomain="butare.net"
butareDnsDomain="hagerman.$butareDnsBaseDomain"
butareDns1="10.10.100.8"
butareDns2="10.10.100.7"
butareDnsServers="$butareDns1 $butareDns2"
butareDnsSearch="$butareDnsBaseDomain $butareDnsDomain"

butareNoProxy="$noProxyLocal,.$butareDnsBaseDomain,web,www,autoproxy,$noProxyRemote"
butareNoProxy+=",10.10.100.1/22,10.96.0.0/12,192.168.59.0/24,192.168.49.0/24,192.168.39.0/24" # minikube - https://minikube.sigs.k8s.io/docs/handbook/vpn_and_proxy/

butareCameraServers="back-shed-camera,back-yard-east-camera,front-patio-camera,front-yard-east-camera,front-yard-west-camera,living-room-camera"
butareBackupUser="$butareUser"
butareGitServer="git.$butareDnsBaseDomain"					# Git Server
butareGitAlias="git"
butareProxyServer="proxy.$butareDnsBaseDomain:3128"	# Forward Proxy Server (Squid), service=proxy.$hbd:3128 ender=10.10.100.9:3128
butareProxyApps="apt,vars"													# Configure proxy server for these applications, all|apt|firefox|npm|os|vars|wpad
butareSyslogServer="syslog.$butareDnsBaseDomain"		# syslog server for remote system logs
butareTimeServer="time.butare.net"									# Time Server
butareVip="10.10.100.6" 														# Virtual IP Address
butareWireguardPort="51820"													# WireGuard Port
butareWorkgroup="hagerman"													# SMB Workgroup

# sandia network
sandiaUser="jjbutar"
sandiaBinUnc=""
sandiaBookmarks="https://ados.sandia.gov/NG/SysAdminTeam/_git/jjbutare-bookmarks"
sandiaBootstrapCloudDir="/mnt/c/Users/jjbutar/OneDrive - Sandia National Laboratories/data/download"
sandiaGitServer="ados.sandia.gov"
sandiaGitAlias="sandia"
sandiaInstallUnc=""
sandiaDnsBaseDomain="sandia.gov"
sandiaDnsDomain="srn.$sandiaDnsBaseDomain"
sandiaDns1="134.253.181.25"
sandiaDns2="134.253.16.5"
sandiaDnsServers="$sandiaDns1 $sandiaDns2"
sandiaDnsSearch="$sandiaDnsBaseDomain $sandiaDnsDomain ca.$sandiaDnsBaseDomain"
sandiaProxyServer="proxy.$sandiaDnsBaseDomain:80"
sandiaProxyApps="apt,vars" # all|apt|firefox|npm|os|vars|wpad
sandiaNoProxy="$noProxyLocal,.$sandiaDnsBaseDomain,$noProxyRemote"
sandiaVaultUrl="https://csep-vault.sandia.gov"
sandiaVaultStoreDefault="${USER}@sandia.gov-kv"
sandiaVaultPathPrefix=""