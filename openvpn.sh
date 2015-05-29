#!/bin/bash

# How To Setup and Configure an OpenVPN Server on CentOS 7
# inspired by https://www.digitalocean.com/community/tutorials/how-to-setup-and-configure-an-openvpn-server-on-centos-7

if [[ $EUID -ne 0 ]]; then
	echo "This script must be run as root" 1>&2
	exit 1
elif [[ "$1" == "-h" || "$1" == "--help" ]]; then
    echo "Usage: $(basename "$0")"
    echo -e "Optional argument: -h|--help\t Shows this information"
    echo -e "Optional argument: <CLIENTNAME>\t Name for the client. Defaults to \"client\""
    exit 1
fi

if [[ "$#" -gt 0 ]]; then
    CLIENTNAME="client"
else
	CLIENTNAME="$1"
fi

exit 0

PUBLICIP=$(curl -s checkip.dyndns.org | sed -e 's/.*Current IP Address: //' -e 's/<.*$//')
LOCALIP=$(ifconfig | grep -Eo 'inet (addr:)?([0-9]*\.){3}[0-9]*' | grep -Eo '([0-9]*\.){3}[0-9]*' | grep -v '127.0.0.1')

removeOctet () {
	# This function removes an octect from an ip address and returns the result
	# Example:
	# "RESULT=$(removeOctet 10.0.1.1)" RESULT is 10.0.1
	# "RESULT=$(removeOctet 10.0.1)" RESULT 10.0
	IPADDRESS=$1
	echo $IPADDRESS | sed 's/\.[0-9]*$//' # make sure to catch this in a variable
}

# Before we start we'll need to install the Extra Packages for Enterprise Linux (EPEL) repository. 
# This is because OpenVPN isn't available in the default CentOS repositories. The EPEL repository 
# is an additional repository managed by the Fedora Project containing non-standard but popular packages.
yum install epel-release -y

# Step 1 — Installing OpenVPN

# First we need to install OpenVPN. We'll also install Easy RSA for generating our SSL key pairs, 
# which will secure our VPN connections.
yum install openvpn easy-rsa -y

# Step 2 — Configuring OpenVPN

# create a configuration file
cp /usr/share/doc/openvpn-*/sample/sample-config-files/server.conf /etc/openvpn.bak
touch /etc/openvpn/server.conf
echo "port 1194" > /etc/openvpn/server.conf
echo "proto udp" >> /etc/openvpn/server.conf
echo "dev tun" >> /etc/openvpn/server.conf
echo "ca ca.crt" >> /etc/openvpn/server.conf
echo "cert server.crt" >> /etc/openvpn/server.conf
echo "key server.key" >> /etc/openvpn/server.conf
echo "dh dh2048.pem" >> /etc/openvpn/server.conf
echo "server $(removeOctet $(removeOctet $LOCALIP)).3.0 255.255.255.0" >> /etc/openvpn/server.conf
echo "ifconfig-pool-persist ipp.txt" >> /etc/openvpn/server.conf
echo "keepalive 10 120" >> /etc/openvpn/server.conf
echo "comp-lzo" >> /etc/openvpn/server.conf
echo "persist-key" >> /etc/openvpn/server.conf
echo "persist-tun" >> /etc/openvpn/server.conf
echo "status openvpn-status.log" >> /etc/openvpn/server.conf
echo "verb 3" >> /etc/openvpn/server.conf
echo "push \"redirect-gateway def1 bypass-dhcp\"" >> /etc/openvpn/server.conf
echo "push \"dhcp-option DNS 8.8.8.8\"" >> /etc/openvpn/server.conf
echo "push \"dhcp-option DNS 8.8.4.4\"" >> /etc/openvpn/server.conf
echo "user nobody" >> /etc/openvpn/server.conf
echo "group nobody" >> /etc/openvpn/server.conf

# Step 3 — Generating Keys and Certificates

# Let's create a directory for the keys to go in.
mkdir -p /etc/openvpn/easy-rsa/keys

# We also need to copy the key and certificate generation scripts into the directory.
cp -rf /usr/share/easy-rsa/2.0/* /etc/openvpn/easy-rsa

# To make life easier for ourselves we're going to edit the default values the script
# uses so we don't have to type our information in each time. This information is stored
# in the vars file so let's open this for editing.
# The ones that matter the most are:

# KEY_NAME: You should enter server here; you could enter something else, but then you 
# would also have to update the configuration files that reference server.key and server.crt
# KEY_CN: Enter the domain or subdomain that resolves to your server
cp /etc/openvpn/easy-rsa/vars /etc/openvpn/easy-rsa/vars.bak # make a backup
echo 'export EASY_RSA="`pwd`"' > /etc/openvpn/easy-rsa/vars
echo 'export OPENSSL="openssl"' >> /etc/openvpn/easy-rsa/vars
echo 'export PKCS11TOOL="pkcs11-tool"' >> /etc/openvpn/easy-rsa/vars
echo 'export GREP="grep"' >> /etc/openvpn/easy-rsa/vars
echo 'export KEY_CONFIG=`$EASY_RSA/whichopensslcnf $EASY_RSA`' >> /etc/openvpn/easy-rsa/vars
echo 'export KEY_DIR="$EASY_RSA/keys"' >> /etc/openvpn/easy-rsa/vars
echo 'echo NOTE: If you run ./clean-all, I will be doing a rm -rf on $KEY_DIR' >> /etc/openvpn/easy-rsa/vars
echo 'export PKCS11_MODULE_PATH="dummy"' >> /etc/openvpn/easy-rsa/vars
echo 'export PKCS11_PIN="dummy"' >> /etc/openvpn/easy-rsa/vars
echo 'export KEY_SIZE=2048' >> /etc/openvpn/easy-rsa/vars
echo 'export CA_EXPIRE=3650' >> /etc/openvpn/easy-rsa/vars
echo 'export KEY_EXPIRE=3650' >> /etc/openvpn/easy-rsa/vars
echo 'export KEY_COUNTRY="US"' >> /etc/openvpn/easy-rsa/vars
echo 'export KEY_PROVINCE="CA"' >> /etc/openvpn/easy-rsa/vars
echo 'export KEY_CITY="SanFrancisco"' >> /etc/openvpn/easy-rsa/vars
echo 'export KEY_ORG="Fort-Funston"' >> /etc/openvpn/easy-rsa/vars
echo 'export KEY_EMAIL="me@myhost.mydomain"' >> /etc/openvpn/easy-rsa/vars
echo 'export KEY_OU="MyOrganizationalUnit"' >> /etc/openvpn/easy-rsa/vars
echo 'export KEY_NAME="server"' >> /etc/openvpn/easy-rsa/vars
echo "export KEY_CN=\"$(dnsdomainname)\"" >> /etc/openvpn/easy-rsa/vars

# We're also going to remove the chance of our OpenSSL configuration not loading due to 
# the version being undetectable. We're going to do this by copying the required configuration 
# file and removing the version number.
cp /etc/openvpn/easy-rsa/openssl-1.0.0.cnf /etc/openvpn/easy-rsa/openssl.cnf

# To start generating our keys and certificates we need to move into our easy-rsa directory 
# and source in our new variables.
cd /etc/openvpn/easy-rsa
source ./vars

# Then we will clean up any keys and certificates which may already be in this folder 
# and generate our certificate authority.
./clean-all

# When you build the certificate authority, you will be asked to enter all the information 
# we put into the vars file, but you will see that your options are already set as the defaults. 
# So, you can just press ENTER for each one.
# --batch takes in the defaults
./build-ca --batch

# The next things we need to generate will are the key and certificate for the server. 
# Again you can just go through the questions and press ENTER for each one to use your defaults. 
# At the end, answer Y (yes) to commit the changes.
./build-key-server --batch server

# We also need to generate a Diffie-Hellman key exchange file. This command will take a minute 
# or two to complete:
./build-dh

# That's it for our server keys and certificates. Copy them all into our OpenVPN directory.
cd /etc/openvpn/easy-rsa/keys
cp dh2048.pem ca.crt server.crt server.key /etc/openvpn

# All of our clients will also need certificates to be able to authenticate. These keys and 
# certificates will be shared with your clients, and it's best to generate separate keys and 
# certificates for each client you intend on connecting.
# Make sure that if you do this you give them descriptive names, but for now we're going to 
# have one client so we'll just call it client.
cd /etc/openvpn/easy-rsa
# automated version of ./build-key
# thanks to https://github.com/Nyr/openvpn-install/blob/master/openvpn-install.sh
export KEY_CN="client"
export EASY_RSA="${EASY_RSA:-.}"
"$EASY_RSA/pkitool" client

# Step 4 — Routing

# add the openvpn service:
firewall-cmd --add-service openvpn
firewall-cmd --permanent --add-service openvpn
# add the masquerade:
firewall-cmd --add-masquerade
firewall-cmd --permanent --add-masquerade
# reload the firewall with the new configurations
firewall-cmd --reload

# Then we must enable IP forwarding in sysctl if its hasnt been already 
if ! grep -Fxq "net.ipv4.ip_forward = 1" /etc/sysctl.conf; then
	echo "net.ipv4.ip_forward = 1" >> /etc/sysctl.conf
	systemctl restart network.service
fi
# Step 5 — Starting OpenVPN

# Now we're ready to run our OpenVPN service. So lets add it to systemctl:
systemctl -f enable openvpn@server.service
# Start OpenVPN:
systemctl start openvpn@server.service


# Step 6 — Configuring a Client

# create ovpn file
mkdir /etc/openvpn/ovpn_configs
touch /etc/openvpn/ovpn_configs/client.ovpn
echo "client" >> /etc/openvpn/client.ovpn
echo "dev tun" >> /etc/openvpn/client.ovpn
echo "proto udp" >> /etc/openvpn/client.ovpn
echo "$PUBLICIP 1194" >> /etc/openvpn/client.ovpn
echo "resolv-retry infinite" >> /etc/openvpn/client.ovpn
echo "nobind" >> /etc/openvpn/client.ovpn
echo "persist-key" >> /etc/openvpn/client.ovpn
echo "persist-tun" >> /etc/openvpn/client.ovpn
echo "comp-lzo" >> /etc/openvpn/client.ovpn
echo "verb 3" >> /etc/openvpn/client.ovpn
echo "ca /path/to/ca.crt" >> /etc/openvpn/client.ovpn
echo "cert /path/to/client.crt" >> /etc/openvpn/client.ovpn
echo "key /path/to/client.key" >> /etc/openvpn/client.ovpn

# tar.gz certificates and config file in home directory
cd $HOME
mkdir client_openvpn
cp /etc/openvpn/easy-rsa/keys/ca.crt client_openvpn/
cp /etc/openvpn/easy-rsa/keys/client.crt client_openvpn/
cp /etc/openvpn/easy-rsa/keys/client.key client_openvpn/
cp /etc/openvpn/ovpn_configs/client.ovpn client_openvpn/
tar -zcvf client_openvpn.tar.gz client_openvpn
rm -rf client_openvpn
