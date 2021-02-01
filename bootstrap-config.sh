user="jjbutare"						# run the bootstrap as this user
timezone="America/Denver"
locale="en_US.UTF-8"

workgroup="hagerman"
baseDomain="butare.net"
domain="$workgroup.$baseDomain"
systemUser="wsystem"

dns1="192.168.100.10"
dns2="192.168.100.11"

proxyNetworks="[wiggin]=192.168.100.10" 
proxyServer="proxy.$domain" proxyPort="3128"
proxy="http://$proxyServer:$proxyPort"

# file server
fs="nas3.$baseDomain" fsProtocol="608"

# web server
web="$fs" webUnc="//$web/web"

# bootstrap
bootstrapHost="$fs" # HOST, DIR, or Windows drive letter (/mnt/D) for access to scripts and installers
bootstrapShare="public" bootstrapDir="/share/CACHEDEV1_DATA/Public" bootstrapPort="608"

# HashiCorp
hashiCredentialPath=""
hashiCertificateDir=""
hashiServers="pi1,pi2,pi3"
hashiClients=""
hashiVaultServers="pi1,pi2"

# HashiCorp Testing
hashiTestCredentialPath=""
hashiTestCertificateDir=""
hashiTestServers="pi4,pi5,pi6"
hashiTestClients="pi7"
hashiTestVaultServers="pi4,pi5"
