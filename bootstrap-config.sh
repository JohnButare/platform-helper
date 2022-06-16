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

# DNS
dnsServers="pi2,pi1" # update pi2 first
dns1="10.10.100.10"
dns2="10.10.100.11"

# proxy
noProxy="localhost,127.0.0.1,.$baseDomain,.$domain,web,www,autoproxy,.releases.ubuntu.com"

# time
timezone="America/Denver"
timeServer="time.butare.net"

dhcpServers="pi2,pi1" # update pi2 first
mqttServer="mosquitto"

hostTimeout="200" # host discovery timeout in milliseconds
hostWaitTimeout="200" # seconds to wait for host to be available

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
hagermanWireguardServers="pi2.$hagermanBaseDomain,pi1.$hagermanBaseDomain"

# HashiCorp
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
