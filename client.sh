#!/bin/bash

# creates the OpenVPN client certificate, ovpn file and tars them all
# Michael Hollister
# May 28, 2015

if [[ $EUID -ne 0 ]]; then
    echo "This script must be run as root" 1>&2
    exit 1
elif [[ "$#" -ne 1 || "$1" == "-h" || "$1" == "--help" ]]; then
    echo "Usage: $(basename "$0") <CLIENTNAME>"
    exit 1
fi

CLIENTNAME=$1
PUBLICIP=$(curl -s checkip.dyndns.org | sed -e 's/.*Current IP Address: //' -e 's/<.*$//')

#build certificate
cd /etc/openvpn/easy-rsa
export KEY_CN="$CLIENTNAME"
export EASY_RSA="${EASY_RSA:-.}"
"$EASY_RSA/pkitool" $CLIENTNAME

# find open port number to assign to the client
PORT=1194 # start with the default 1194
while grep -Fxq "port $PORT" /etc/openvpn/server.conf; do
    port=$((PORT+1))
done
# add the port to the openvpn server
echo "port $PORT" >> /etc/openvpn/server.conf

# reload the firewall with the new configurations
firewall-cmd --reload

# restart OpenVPN with the new port
systemctl restart openvpn@server.service

# create ovpn file
mkdir /etc/openvpn/ovpn_configs
touch /etc/openvpn/ovpn_configs/${CLIENTNAME}.ovpn
echo "${CLIENTNAME}" >> /etc/openvpn/${CLIENTNAME}.ovpn
echo "dev tun" >> /etc/openvpn/${CLIENTNAME}.ovpn
echo "proto udp" >> /etc/openvpn/${CLIENTNAME}.ovpn
echo "$PUBLICIP $PORT" >> /etc/openvpn/${CLIENTNAME}.ovpn
echo "resolv-retry infinite" >> /etc/openvpn/${CLIENTNAME}.ovpn
echo "nobind" >> /etc/openvpn/${CLIENTNAME}.ovpn
echo "persist-key" >> /etc/openvpn/${CLIENTNAME}.ovpn
echo "persist-tun" >> /etc/openvpn/${CLIENTNAME}.ovpn
echo "comp-lzo" >> /etc/openvpn/${CLIENTNAME}.ovpn
echo "verb 3" >> /etc/openvpn/${CLIENTNAME}.ovpn
echo "ca /path/to/ca.crt" >> /etc/openvpn/${CLIENTNAME}.ovpn
echo "cert /path/to/CLIENTNAME.crt" >> /etc/openvpn/${CLIENTNAME}.ovpn
echo "key /path/to/CLIENTNAME.key" >> /etc/openvpn/${CLIENTNAME}.ovpn

# tar.gz certificates and config file in home directory
cd $HOME
mkdir ${CLIENTNAME}_openvpn
cp /etc/openvpn/easy-rsa/keys/ca.crt ${CLIENTNAME}_openvpn/
cp /etc/openvpn/easy-rsa/keys/$CLIENTNAME.crt ${CLIENTNAME}_openvpn/
cp /etc/openvpn/easy-rsa/keys/$CLIENTNAME.key ${CLIENTNAME}_openvpn/
cp /etc/openvpn/ovpn_configs/$CLIENTNAME.ovpn ${CLIENTNAME}_openvpn/
tar -zcvf ${CLIENTNAME}_openvpn.tar.gz ${CLIENTNAME}_openvpn
rm -rf ${CLIENTNAME}_openvpn
