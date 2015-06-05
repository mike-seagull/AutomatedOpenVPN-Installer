#!bin/bash

# creates the OpenVPN client certificate, ovpn file and tars them all
# Michael Hollister
# May 28, 2015

# logger
source "./bash-logging/streamhandler.sh"
info "Started $(basename "$0")"

usage (){
    echo "Usage: $(basename "$0") <clientname>"
}

if [[ $EUID -ne 0 ]]; then
    #echo "This script must be run as root" 1>&2
    error "This script must be run as root"
    exit 1
#elif [[ "$#" -ne 1 || "$1" == "-h" || "$1" == "--help" ]]; then
#    echo "Usage: $(basename "$0") <clientname>"
#    exit 1
elif [[ "$#" -ne 1 ]]; then
    error "Not enough arguments!"
    usage
    exit 1
elif [[ "$1" == "-h" || "$1" == "--help" ]]; then
    usage
    exit 0
fi

clientname=$1
debug "clientname=\"$clientname\""
publicip=$(curl -s checkip.dyndns.org | sed -e 's/.*Current IP Address: //' -e 's/<.*$//')
debug "publicip=\"$publicip\""

#build certificate
info "Building certificate for $clientname"
cd /etc/openvpn/easy-rsa
export KEY_CN="$clientname"
export EASY_RSA="${EASY_RSA:-.}"
"$EASY_RSA/pkitool" $clientname

# find open port number to assign to the client
info "Finding an open port number to assign to the $clientname"
port=1194 # start with the default 1194
while grep -Fxq "port $port" /etc/openvpn/server.conf; do
    port=$((port+1))
done
info "Going to use port number $port for $clientname"
# add the port to the openvpn server
info "Adding the port to the openvpn server"
echo "port $port" >> /etc/openvpn/server.conf

# reload the firewall with the new configurations
info "Reloading the firewall with the new configurations"
firewall-cmd --reload

# restart OpenVPN with the new port
info "Restarting OpenVPN with the new port"
systemctl restart openvpn@server.service

# create ovpn file
info "Creating the ovpn file"
mkdir /etc/openvpn/ovpn_configs
touch /etc/openvpn/ovpn_configs/${clientname}.ovpn
echo "${clientname}" >> /etc/openvpn/${clientname}.ovpn
echo "dev tun" >> /etc/openvpn/${clientname}.ovpn
echo "proto udp" >> /etc/openvpn/${clientname}.ovpn
echo "$publicip $port" >> /etc/openvpn/${clientname}.ovpn
echo "resolv-retry infinite" >> /etc/openvpn/${clientname}.ovpn
echo "nobind" >> /etc/openvpn/${clientname}.ovpn
echo "persist-key" >> /etc/openvpn/${clientname}.ovpn
echo "persist-tun" >> /etc/openvpn/${clientname}.ovpn
echo "comp-lzo" >> /etc/openvpn/${clientname}.ovpn
echo "verb 3" >> /etc/openvpn/${clientname}.ovpn
echo "ca /path/to/ca.crt" >> /etc/openvpn/${clientname}.ovpn
echo "cert /path/to/CLIENTNAME.crt" >> /etc/openvpn/${clientname}.ovpn
echo "key /path/to/CLIENTNAME.key" >> /etc/openvpn/${clientname}.ovpn

# tar.gz certificates and config file in home directory
info "GZipping certificates and config file"
cd $HOME
mkdir ${clientname}_openvpn
cp /etc/openvpn/easy-rsa/keys/ca.crt ${clientname}_openvpn/
cp /etc/openvpn/easy-rsa/keys/$clientname.crt ${clientname}_openvpn/
cp /etc/openvpn/easy-rsa/keys/$clientname.key ${clientname}_openvpn/
cp /etc/openvpn/ovpn_configs/$clientname.ovpn ${clientname}_openvpn/
tar -zcvf ${clientname}_openvpn.tar.gz ${clientname}_openvpn
rm -rf ${clientname}_openvpn

info "Done. The certificates and config file for $clientname are gzipped in $HOME"
