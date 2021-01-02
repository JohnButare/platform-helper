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

hashiCredentialPrefix="none"
hashiServers="pi3,pi4,pi5"
hashiClients="pi6,pi7"
hashiVaultServers="pi3,pi4"

# host for scripts and installers - host, drive letter (/mnt/D), or local install directory
fs="nas3.$domain" fsUnc="//$bootstrapHost/public"
fsRemote="butare.net" fsRemoteShare="/share/CACHEDEV1_DATA/Public" fsRemotePort=608
