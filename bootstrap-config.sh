user="jjbutare"						# run the bootstrap as this user
timezone="America/Denver"
timeServer="time.hagerman.butare.net"
locale="en_US.UTF-8"

network="wiggin"
workgroup="hagerman"
baseDomain="butare.net"
domain="$workgroup.$baseDomain"
systemUser="wsystem"

dnsServers="pi2,pi1" # update pi2 first
dns1="10.10.100.10"
dns2="10.10.100.11"

dhcpServers="pi2,pi1" # update pi2 first
mqttServer="mosquitto"

hostTimeout="200" # host discovery timeout in milliseconds
hostWaitTimeout="200" # seconds to wait for host to be available

# networks
networks="wiggin@10.10.100.10,wiggin@10.10.100.11" # list of DNS servers for the specified network in the format NETWORK@IP
wigginFileServers="file2.$baseDomain,file1.$baseDomain" # list of file servers in the format HOST
wigginProxyServers="proxy.$baseDomain:3128" # list of proxy servers in the format HOST:PORT

# Dropbox
dropboxCompany="Juntos Holdings"
dropboxUser="John Butare"

# file server
fs="files.$baseDomain" fsProtocol="smb" fsUser="jjbutare"

# web server
web="$fs" webUnc="//$web/web"

# bootstrap
bootstrapHost="$fs" # HOST, DIR, or Windows drive letter (/mnt/D) for access to scripts and installers
bootstrapProxyServer="proxy.$domain" proxyPort="3128"
bootstrapProxy="http://$proxyServer:$proxyPort"
bootstrapShare="public" bootstrapDir="/share/CACHEDEV1_DATA/Public" bootstrapPort="608"

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
