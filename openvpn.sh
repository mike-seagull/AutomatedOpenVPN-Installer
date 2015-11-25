#!/bin/bash

# How To Setup and Configure an OpenVPN Server on CentOS 7
# inspired by https://www.digitalocean.com/community/tutorials/how-to-setup-and-configure-an-openvpn-server-on-centos-7

echo "Started $(basename "$0")"

if [[ $EUID -ne 0 ]]; then
	echo "This script must be run as root"
	exit 1
fi

if [[ "$#" -gt 0 ]]; then
    clientname="$1"
else
    clientname="client"
fi

if [ -n "$(command -v apt-get)" ]; then
    packagemanager="apt-get"
elif [ -n "$(command -v yum)" ]; then
    packagemanager="yum"
else
    echo "Cannot install needed components"
    exit 1
fi

publicip=$(curl -s checkip.dyndns.org | sed -e 's/.*Current IP Address: //' -e 's/<.*$//')
localip=$(ifconfig | grep -Eo 'inet (addr:)?([0-9]*\.){3}[0-9]*' | grep -Eo '([0-9]*\.){3}[0-9]*' | grep -v '127.0.0.1')
working_dir=$(cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd)

echo "Installing epel-release"
$packagemanager install epel-release -y -q > /dev/null 2>&1

echo "Installing openvpn and wget"
$packagemanager install openvpn wget -y -q > /dev/null 2>&1

echo "Creating the server config file"
cp /usr/share/doc/openvpn*/*/sample-config-files/server.conf* /etc/openvpn/
cp ./configuration/server.conf /etc/openvpn/server.conf

# some servers use nogroup and some use nobody
if getent group nogroup > /dev/null 2>&1; then
    echo "group nogroup" >> /etc/openvpn/server.conf
elif getent group nobody > /dev/null 2>&1; then
    echo "group nobody" >> /etc/openvpn/server.conf
fi

wget --no-check-certificate -O /etc/openvpn/easy-rsa.tgz https://github.com/OpenVPN/easy-rsa/releases/download/3.0.1/EasyRSA-3.0.1.tgz > /dev/null 2>&1
tar xzf /etc/openvpn/easy-rsa.tgz -C /etc/openvpn/
rm /etc/openvpn/easy-rsa.tgz
mv /etc/openvpn/EasyRSA-3.0.1 /etc/openvpn/easy-rsa

cp /etc/openvpn/easy-rsa/openssl-1.0.cnf /etc/openvpn/easy-rsa/openssl.cnf

cd /etc/openvpn/easy-rsa

./easyrsa init-pki > /dev/null 2>&1
./easyrsa --batch build-ca nopass > /dev/null 2>&1
./easyrsa build-server-full server nopass > /dev/null 2>&1
./easyrsa gen-dh > /dev/null 2>&1
./easyrsa gen-crl > /dev/null 2>&1

cd /etc/openvpn/easy-rsa/pki > /dev/null 2>&1

cp ca.crt issued/server.crt private/server.key /etc/openvpn
cp dh.pem /etc/openvpn/dh2048.pem

cd ${working_dir}
bash client.sh $clientname

echo "Configuring the firewall"
if [ -n "$(command -v firewalld)" ]; then
    firewall-cmd --add-service openvpn > /dev/null 2>&1
    firewall-cmd --permanent --add-service openvpn > /dev/null 2>&1
    firewall-cmd --add-masquerade > /dev/null 2>&1
    firewall-cmd --permanent --add-masquerade > /dev/null 2>&1
    firewall-cmd --reload > /dev/null 2>&1
elif [ -n "$(command -v iptables)" ]; then
    iptables -t nat -A POSTROUTING -s 10.8.0.0/24 -o eth0 -j MASQUERADE > /dev/null 2>&1
    iptables -t nat -A POSTROUTING -o venet0 -j SNAT --to-source $publicip > /dev/null 2>&1
    iptables -t nat -A POSTROUTING -o venet0 -j SNAT --to-source $localip > /dev/null 2>&1
    iptables -t nat -A POSTROUTING -s 10.8.0.0/24 -j SNAT --to-source $publicip > /dev/null 2>&1
    iptables -t nat -A POSTROUTING -s 10.8.0.0/24 -j SNAT --to-source $localip > /dev/null 2>&1
    iptables -D FORWARD -j REJECT --reject-with icmp-host-prohibited > /dev/null 2>&1
    iptables -D INPUT -j REJECT --reject-with icmp-host-prohibited > /dev/null 2>&1
    service iptables save > /dev/null 2>&1
    chkconfig --add openvpn > /dev/null 2>&1
    chkconfig openvpn on > /dev/null 2>&1
    service openvpn start > /dev/null 2>&1
else
    echo "ERROR: cannot configure firewall"
fi

sed -i '/net.ipv4.ip_forward = 0/d' /etc/sysctl.conf # delete line if it exists
if ! grep -Fxq "net.ipv4.ip_forward = 1" /etc/sysctl.conf; then
    echo "net.ipv4.ip_forward = 1" >> /etc/sysctl.conf
    sysctl -p > /dev/null 2>&1 # Centos 6
    systemctl restart network.service > /dev/null 2>&1 # Centos 7
fi

echo "Starting the openvpn server"
systemctl -f enable openvpn@server.service > /dev/null 2>&1 # Centos 7

# Start OpenVPN:
service openvpn start > /dev/null 2>&1 # Centos 6 & Debian 8
systemctl start openvpn@server.service > /dev/null 2>&1 # Centos 7

echo "Done."
exit 0
