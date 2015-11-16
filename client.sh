#!/bin/sh

# creates the OpenVPN client certificate, ovpn file and tars them all
# Michael Hollister
# May 28, 2015

# logger
source "./bash-logging/streamhandler.sh" > /dev/null 2>&1
info "Started $(basename "$0")"

usage (){
    echo "Usage: $(basename "$0") <clientname>"
}

if [[ $EUID -ne 0 ]]; then
    #echo "This script must be run as root" 1>&2
    error "This script must be run as root"
    exit 1
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
source ./vars > /dev/null 2>&1
# automated version of ./build-key
# thanks to https://github.com/Nyr/openvpn-install/blob/master/openvpn-install.sh
export KEY_CN="$clientname"
export EASY_RSA="${EASY_RSA:-.}"
"$EASY_RSA/pkitool" $clientname > /dev/null 2>&1

# create ovpn file
info "Creating the ovpn file"
mkdir /etc/openvpn/ovpn_configs > /dev/null 2>&1
touch /etc/openvpn/ovpn_configs/${clientname}.ovpn
echo "client" >> /etc/openvpn/ovpn_configs/${clientname}.ovpn
echo "dev tun" >> /etc/openvpn/ovpn_configs/${clientname}.ovpn
echo "proto udp" >> /etc/openvpn/ovpn_configs/${clientname}.ovpn
echo "remote $publicip $port" >> /etc/openvpn/ovpn_configs/${clientname}.ovpn
echo "resolv-retry infinite" >> /etc/openvpn/ovpn_configs/${clientname}.ovpn
echo "nobind" >> /etc/openvpn/ovpn_configs/${clientname}.ovpn
echo "persist-key" >> /etc/openvpn/ovpn_configs/${clientname}.ovpn
echo "persist-tun" >> /etc/openvpn/ovpn_configs/${clientname}.ovpn
echo "comp-lzo" >> /etc/openvpn/ovpn_configs/${clientname}.ovpn
echo "verb 3" >> /etc/openvpn/ovpn_configs/${clientname}.ovpn
echo "ca /path/to/ca.crt" >> /etc/openvpn/ovpn_configs/${clientname}.ovpn
echo "cert /path/to/${clientname}.crt" >> /etc/openvpn/ovpn_configs/${clientname}.ovpn
echo "key /path/to/${clientname}.key" >> /etc/openvpn/ovpn_configs/${clientname}.ovpn

# tar.gz certificates and config file in home directory
info "GZipping certificates and config file"
cd $HOME
mkdir ${clientname}_openvpn
cp /etc/openvpn/easy-rsa/keys/ca.crt ${clientname}_openvpn/
cp /etc/openvpn/easy-rsa/keys/$clientname.crt ${clientname}_openvpn/
cp /etc/openvpn/easy-rsa/keys/$clientname.key ${clientname}_openvpn/
cp /etc/openvpn/ovpn_configs/$clientname.ovpn ${clientname}_openvpn/
tar -zcvf ${clientname}_openvpn.tar.gz ${clientname}_openvpn > /dev/null 2>&1
rm -rf ${clientname}_openvpn

info "The certificates and config file for $clientname are gzipped in $HOME"
exit 0
