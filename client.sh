#!/bin/bash

# creates the OpenVPN client certificate, ovpn file and tars them all
# Michael Hollister
# Nov 24, 2015

echo "Started $(basename "$0")"

usage (){
    echo "Usage: $(basename "$0") <clientname>"
}

if [[ $EUID -ne 0 ]]; then
    echo "This script must be run as root"
    exit 1
elif [[ "$#" -ne 1 ]]; then
    echo "Not enough arguments!"
    usage
    exit 1
elif [[ "$1" == "-h" || "$1" == "--help" ]]; then
    usage
    exit 0
fi

if [[ "$#" -gt 0 ]]; then
    clientname="$1"
else
    clientname="client"
fi

publicip=$(curl -s checkip.dyndns.org | sed -e 's/.*Current IP Address: //' -e 's/<.*$//')
working_dir=$(cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd)

cd /etc/openvpn/easy-rsa

echo "Building certificate for $clientname"
./easyrsa build-client-full $clientname nopass > /dev/null 2>&1

echo "Creating the ovpn file"
mkdir /etc/openvpn/ovpn_configs > /dev/null 2>&1
cp ${working_dir}/configuration/client.ovpn /etc/openvpn/ovpn_configs/${clientname}.ovpn
ovpn="/etc/openvpn/ovpn_configs/${clientname}.ovpn"
echo "remote $publicip $port" >> $ovpn
echo "<ca>" >> $ovpn
cat /etc/openvpn/easy-rsa/pki/ca.crt >> $ovpn
echo "</ca>" >> $ovpn
echo "<cert>" >> $ovpn
cat /etc/openvpn/easy-rsa/pki/issued/$clientname.crt >> $ovpn
echo "</cert>" >> $ovpn
echo "<key>" >> $ovpn
cat /etc/openvpn/easy-rsa/pki/private/$clientname.key >> $ovpn
echo "</key>" >> $ovpn

cp /etc/openvpn/ovpn_configs/$clientname.ovpn $HOME/
echo "The config file for $clientname is in $HOME"
exit 0
