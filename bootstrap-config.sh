user="jjbutare" 									# user to run bootstrap as
timezone="America/Denver"					# host timezone
locale="en_US.UTF-8"							# host locale

baseDomain="butare.net"
workgroup="hagerman"
domain="$workgroup.$baseDomain"
systemUser="wsystem"

dns1="192.168.100.10"
dns2="192.168.100.11"
host="nas3.$domain" port=608			# host or mounted drive to use for scripts and installers
proxy="http://proxy.$domain:3128" # proxy server for package download

fileServer="$host"
hashiServers=( pi3 pi4 )
hashiClients=( pi5 rp1 )

#user=""
#host="/mnt/d"
#proxy=""
#workgroup=""
