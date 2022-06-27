locale="en_US.UTF-8"

# bootstrap
bootstrapBin="//ender.hagerman.butare.net/system/usr/local/data/bin" # initial bin directory UNC (//[USER@]SERVER/SHARE[/DIRS][:PROTOCOL])
bootstrapProxyServer="proxy.butare.net" boostrapProxyPort="3128"
bootstrapProxy="http://$bootstrapProxyServer:$boostrapProxyPort"

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

# DHCP
dhcpServers="pi1,pi2,pi3,pi4"

# DNS
dnsServers="pi1,pi2,pi3,pi4"
dns1="10.10.100.7"
dns2="10.10.100.6"

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
hashiVaultServers="pi1,pi2"

# HashiCorp Testing
hashiTestCredentialPath=""
#hashiTestCertificateDevice="" hashiTestCertificateDir="$UDATA/app/hashi"
hashiTestCertificateDevice="$CDATA/VeraCrypt/personal.hc" hashiTestCertificateDir="data/hashi"
hashiTestServers="pi5,pi6,pi7"
hashiTestClients="pi8"
hashiTestVaultServers="pi5,pi6"

#
# networks
#

# networks - list of available networks that the system can be connected to
networks="hagerman@10.10.100.10,hagerman@10.10.100.11" # list of DNS servers for the specified network in the format NETWORK@IP
hagermanBaseDomain="butare.net"
hagermanDomain="hagerman.$hagermanBaseDomain"
hagermanBackupUser="$user"
hagermanBackupServers="backup3.$hagermanBaseDomain,backup2.$hagermanBaseDomain,backup1.$hagermanBaseDomain" # list of backup servers in the format HOST1 [,HOST2]...
hagermanDockerServers="pi1.$hagermanBaseDomain,pi2.$hagermanBaseDomain" # Docker Swarm managers
hagermanFileServers="file2.$hagermanBaseDomain,file1.$hagermanBaseDomain"
hagermanNas="nas3.$hagermanDomain"
hagermanProxyServers="proxy.$hagermanBaseDomain:3128"
hagermanVip="10.10.100.5"
hagermanWireguardServers="pi2.$hagermanBaseDomain,pi1.$hagermanBaseDomain"