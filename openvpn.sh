#!/bin/sh

# How To Setup and Configure an OpenVPN Server on CentOS 7
# inspired by https://www.digitalocean.com/community/tutorials/how-to-setup-and-configure-an-openvpn-server-on-centos-7

# logger
#source "./bash-logging/streamhandler.sh"
#info "Started $(basename "$0")"
echo "Started $(basename "$0")"

if [[ $EUID -ne 0 ]]; then
	#error "This script must be run as root" 1>&2
	echo "This script must be run as root"
	exit 1
elif [[ "$1" == "-h" || "$1" == "--help" ]]; then
    #info "Usage: $(basename "$0")"
    echo "Usage: $(basename "$0")"
    #info -e "Optional argument: -h|--help\t Shows this information"
    echo "Optional argument: -h|--help\t Shows this information"
    #info -e "Optional argument: <clientname>\t Name for the client. Defaults to \"client\""
    echo "Optional argument: <clientname>\t Name for the client. Defaults to \"client\""
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

#debug "publicip = $publicip"
#debug "localip = $localip"
#debug "working_dir=$working_dir"

removeOctet () {
	# This function removes an octect from an ip address and returns the result
	# Example:
	# "RESULT=$(removeOctet 10.0.1.1)" RESULT is 10.0.1
	# "RESULT=$(removeOctet 10.0.1)" RESULT 10.0
	ipaddress=$1
	echo $ipaddress | sed 's/\.[0-9]*$//' # make sure to catch this in a variable
}

# Before we start we'll need to install the Extra Packages for Enterprise Linux (EPEL) repository. 
# This is because OpenVPN isn't available in the default CentOS repositories. The EPEL repository 
# is an additional repository managed by the Fedora Project containing non-standard but popular packages.
#info "Installing epel-release"
echo "Installing epel-release"
$packagemanager install epel-release -y -q > /dev/null 2>&1

# Step 1 — Installing OpenVPN

# First we need to install OpenVPN. We'll also install Easy RSA for generating our SSL key pairs, 
# which will secure our VPN connections.
#info "Installing openvpn and easy-rsa"
echo "Installing openvpn and wget"
$packagemanager install openvpn wget -y -q > /dev/null 2>&1

# Step 2 — Configuring OpenVPN

# create a configuration file
#info "Creating the server config file"
echo "Creating the server config file"
#cp /usr/share/doc/openvpn-*/sample/sample-config-files/server.conf /etc/openvpn.bak > /dev/null 2>&1 # CentOS
cp /usr/share/doc/openvpn*/*/sample-config-files/server.conf* /etc/openvpn/
cp ./configuration/server.conf /etc/openvpn/server.conf
# some servers use nogroup and some use nobody
if getent group nogroup > /dev/null 2>&1; then
    echo "group nogroup" >> /etc/openvpn/server.conf
elif getent group nobody > /dev/null 2>&1; then
    echo "group nobody" >> /etc/openvpn/server.conf
fi

# touch /etc/openvpn/server.conf
# echo "port 1194" > /etc/openvpn/server.conf
# echo "proto udp" >> /etc/openvpn/server.conf
# echo "dev tun" >> /etc/openvpn/server.conf
# echo "ca ca.crt" >> /etc/openvpn/server.conf
# echo "cert server.crt" >> /etc/openvpn/server.conf
# echo "key server.key" >> /etc/openvpn/server.conf
# echo "dh dh2048.pem" >> /etc/openvpn/server.conf
# echo "server $(removeOctet $(removeOctet $localip)).3.0 255.255.255.0" >> /etc/openvpn/server.conf
# echo "ifconfig-pool-persist ipp.txt" >> /etc/openvpn/server.conf
# echo "keepalive 10 120" >> /etc/openvpn/server.conf
# echo "comp-lzo" >> /etc/openvpn/server.conf
# echo "persist-key" >> /etc/openvpn/server.conf
# echo "persist-tun" >> /etc/openvpn/server.conf
# echo "status openvpn-status.log" >> /etc/openvpn/server.conf
# echo "verb 3" >> /etc/openvpn/server.conf
# echo "push \"redirect-gateway def1 bypass-dhcp\"" >> /etc/openvpn/server.conf
# echo "push \"dhcp-option DNS 8.8.8.8\"" >> /etc/openvpn/server.conf
# echo "push \"dhcp-option DNS 8.8.4.4\"" >> /etc/openvpn/server.conf
# echo "user nobody" >> /etc/openvpn/server.conf
# echo "group nobody" >> /etc/openvpn/server.conf

# Step 3 — Generating Keys and Certificates

# We also need to copy the key and certificate generation scripts into the directory.
wget --no-check-certificate -O /etc/openvpn/easy-rsa.tgz https://github.com/OpenVPN/easy-rsa/releases/download/3.0.1/EasyRSA-3.0.1.tgz > /dev/null 2>&1
tar xzf /etc/openvpn/easy-rsa.tgz -C /etc/openvpn/
rm /etc/openvpn/easy-rsa.tgz
mv /etc/openvpn/EasyRSA-3.0.1 /etc/openvpn/easy-rsa

#cp -rf /usr/share/easy-rsa/2.0/* /etc/openvpn/easy-rsa > /dev/null 2>&1
#cp -rf /usr/share/easy-rsa/* /etc/openvpn/easy-rsa > /dev/null 2>&1

# Let's create a directory for the keys to go in.
mkdir -p /etc/openvpn/easy-rsa/keys > /dev/null 2>&1

# To make life easier for ourselves we're going to edit the default values the script
# uses so we don't have to type our information in each time. This information is stored
# in the vars file so let's open this for editing.
# The ones that matter the most are:

# KEY_NAME: You should enter server here; you could enter something else, but then you 
# would also have to update the configuration files that reference server.key and server.crt
# KEY_CN: Enter the domain or subdomain that resolves to your server
#info "Editing the default values for /etc/openvpn/easy-rsa/vars"
#echo "Editing the default values for /etc/openvpn/easy-rsa/vars"
#cp /etc/openvpn/easy-rsa/vars /etc/openvpn/easy-rsa/vars.bak # make a backup
#cp ./configuration/vars /etc/openvpn/easy-rsa/vars

# echo 'export EASY_RSA="`pwd`"' > /etc/openvpn/easy-rsa/vars
# echo 'export OPENSSL="openssl"' >> /etc/openvpn/easy-rsa/vars
# echo 'export PKCS11TOOL="pkcs11-tool"' >> /etc/openvpn/easy-rsa/vars
# echo 'export GREP="grep"' >> /etc/openvpn/easy-rsa/vars
# echo 'export KEY_CONFIG=`$EASY_RSA/whichopensslcnf $EASY_RSA`' >> /etc/openvpn/easy-rsa/vars
# echo 'export KEY_DIR="$EASY_RSA/keys"' >> /etc/openvpn/easy-rsa/vars
# echo 'echo NOTE: If you run ./clean-all, I will be doing a rm -rf on $KEY_DIR' >> /etc/openvpn/easy-rsa/vars
# echo 'export PKCS11_MODULE_PATH="dummy"' >> /etc/openvpn/easy-rsa/vars
# echo 'export PKCS11_PIN="dummy"' >> /etc/openvpn/easy-rsa/vars
# echo 'export KEY_SIZE=2048' >> /etc/openvpn/easy-rsa/vars
# echo 'export CA_EXPIRE=3650' >> /etc/openvpn/easy-rsa/vars
# echo 'export KEY_EXPIRE=3650' >> /etc/openvpn/easy-rsa/vars
# echo 'export KEY_COUNTRY="US"' >> /etc/openvpn/easy-rsa/vars
# echo 'export KEY_PROVINCE="CA"' >> /etc/openvpn/easy-rsa/vars
# echo 'export KEY_CITY="SanFrancisco"' >> /etc/openvpn/easy-rsa/vars
# echo 'export KEY_ORG="Fort-Funston"' >> /etc/openvpn/easy-rsa/vars
# echo 'export KEY_EMAIL="me@myhost.mydomain"' >> /etc/openvpn/easy-rsa/vars
# echo 'export KEY_OU="MyOrganizationalUnit"' >> /etc/openvpn/easy-rsa/vars
# echo 'export KEY_NAME="server"' >> /etc/openvpn/easy-rsa/vars
#if [ -z "$(dnsdomainname)" ]; then
#    echo "export KEY_CN=\"$(dnsdomainname)\"" >> /etc/openvpn/easy-rsa/vars
#else
#    echo "export KEY_CN=\"$(hostname).com\"" >> /etc/openvpn/easy-rsa/vars
#fi
    
# We're also going to remove the chance of our OpenSSL configuration not loading due to 
# the version being undetectable. We're going to do this by copying the required configuration 
# file and removing the version number.
#cp /etc/openvpn/easy-rsa/openssl-1.0.0.cnf /etc/openvpn/easy-rsa/openssl.cnf
cp /etc/openvpn/easy-rsa/openssl-1.0.cnf /etc/openvpn/easy-rsa/openssl.cnf

# To start generating our keys and certificates we need to move into our easy-rsa directory 
# and source in our new variables.
cd /etc/openvpn/easy-rsa
#source ./vars > /dev/null 2>&1
./easyrsa init-pki > /dev/null 2>&1

# Then we will clean up any keys and certificates which may already be in this folder 
# and generate our certificate authority.
#./clean-all > /dev/null 2>&1

# When you build the certificate authority, you will be asked to enter all the information 
# we put into the vars file, but you will see that your options are already set as the defaults. 
# So, you can just press ENTER for each one.
# --batch takes in the defaults
#./build-ca --batch > /dev/null 2>&1
./easyrsa --batch build-ca nopass > /dev/null 2>&1

# The next things we need to generate will are the key and certificate for the server. 
# Again you can just go through the questions and press ENTER for each one to use your defaults. 
# At the end, answer Y (yes) to commit the changes.
#./build-key-server --batch server > /dev/null 2>&1
./easyrsa build-server-full server nopass > /dev/null 2>&1

# We also need to generate a Diffie-Hellman key exchange file. This command will take a minute 
# or two to complete:
#./build-dh > /dev/null 2>&1
./easyrsa gen-dh > /dev/null 2>&1
./easyrsa gen-crl > /dev/null 2>&1
# That's it for our server keys and certificates. Copy them all into our OpenVPN directory.
#cd /etc/openvpn/easy-rsa/keys
#cp dh2048.pem ca.crt server.crt server.key /etc/openvpn
cd /etc/openvpn/easy-rsa/pki > /dev/null 2>&1
cp ca.crt issued/server.crt private/server.key /etc/openvpn
co dh.pem /etc/openvpn

# All of our clients will also need certificates to be able to authenticate. These keys and 
# certificates will be shared with your clients, and it's best to generate separate keys and 
# certificates for each client you intend on connecting.
# Make sure that if you do this you give them descriptive names
cd ${working_dir}
bash client.sh $clientname

# Step 4 — Routing
#info "Configuring the firewall"
echo "Configuring the firewall"
if [ -n "$(command -v iptables)" ]; then
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
elif [ -n "$(command -v firewalld)" ]; then
    # add the openvpn service:
    firewall-cmd --add-service openvpn > /dev/null 2>&1
    firewall-cmd --permanent --add-service openvpn > /dev/null 2>&1
    # add the masquerade:
    firewall-cmd --add-masquerade > /dev/null 2>&1
    firewall-cmd --permanent --add-masquerade > /dev/null 2>&1
    # reload the firewall with the new configurations
    firewall-cmd --reload > /dev/null 2>&1
else
    echo "ERROR: cannot configure firewall"
fi
# Then we must enable IP forwarding in sysctl if its hasnt been already 
sed -i '/net.ipv4.ip_forward = 0/d' /etc/sysctl.conf # delete line if it exists
if ! grep -Fxq "net.ipv4.ip_forward = 1" /etc/sysctl.conf; then
    echo "net.ipv4.ip_forward = 1" >> /etc/sysctl.conf
    sysctl -p > /dev/null 2>&1 # Centos 6
    systemctl restart network.service > /dev/null 2>&1 # Centos 7
fi
# Step 5 — Starting OpenVPN
#info "Starting the openvpn server"
echo "Starting the openvpn server"
# Now we're ready to run our OpenVPN service. So lets add it to systemctl:

## Centos 6
#chkconfig openvpn on > /dev/null 2>&1
#chkconfig iptables on > /dev/null 2>&1
systemctl -f enable openvpn@server.service > /dev/null 2>&1 # Centos 7

# Start OpenVPN:
service openvpn start > /dev/null 2>&1 # Centos 6 & Debian 8
systemctl start openvpn@server.service > /dev/null 2>&1 # Centos 7

#info "Done."
echo "Done."
exit 0
