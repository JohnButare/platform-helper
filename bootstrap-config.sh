systemUser="wsystem"
locale="en_US.UTF-8"

# user
user="jjbutare"
dropboxCompany="Juntos Holdings"
dropboxUser="John Butare"

# system network
network="hagerman"
workgroup="$network"
baseDomain="butare.net"
domain="$network.$baseDomain"

# DNS
dnsServers="pi2,pi1" # update pi2 first
dns1="10.10.100.10"
dns2="10.10.100.11"

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
hagermanBackupServers="backup3.$hagermanBaseDomain,backup2.$hagermanBaseDomain,backup1.$hagermanBaseDomain" # list of backup servers in the format HOST1 [,HOST2]...
hagermanDockerServers="pi1.$hagermanBaseDomain,pi2.$hagermanBaseDomain" # Docker Swarm managers
hagermanFileServers="file2.$hagermanBaseDomain,file1.$hagermanBaseDomain"
hagermanProxyServers="proxy.$hagermanBaseDomain:3128"
hagermanWebServers="web2.$hagermanBaseDomain,web1.$hagermanBaseDomain"
hagermanWireguardServers="pi2.$hagermanBaseDomain,pi1.$hagermanBaseDomain"

# bootstrap
bootstrapHost="$fs" # HOST, DIR, or Windows drive letter (/mnt/D) for access to scripts and installers
bootstrapProxyServer="proxy.$domain" proxyPort="3128"
bootstrapProxy="http://$proxyServer:$proxyPort"
bootstrapShare="public" bootstrapDir="/share/CACHEDEV1_DATA/Public" bootstrapPort="608"

# file server
fs="file.$baseDomain" fsProtocol="smb" fsUser="jjbutare"

# HashiCorp
hashiCredentialPath=""
hashiCertificateDevice="$CDATA/VeraCrypt/personal.hc" hashiCertificateDir="data/hashi"
hashiServers="pi1,pi2,pi3"
hashiClients=""
hashiVaultServers="pi1,pi2"

# HashiCorp Testing
hashiTestCredentialPath=""
#hashiTestCertificateDevice="" hashiTestCertificateDir="$UDATA/app/hashi"
hashiTestCertificateDevice="$CDATA/VeraCrypt/personal.hc" hashiTestCertificateDir="data/hashi"
hashiTestServers="pi4,pi5,pi6"
hashiTestClients="pi7"
hashiTestVaultServers="pi4,pi5"
