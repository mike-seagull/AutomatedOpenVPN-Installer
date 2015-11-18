# AutomatedOpenVPN-Installer

----
Automated script to install an OpenVPN server. It is originally made for RedHat Distros and has only been tested on CentOS 7.

----
## openvpn.sh
### usage
    sudo sh openvpn.sh <clientname>

Openvpn.sh takes in a client name and defaults to "client". It must be ran as root.

----
## client.sh
### usage
    sh client.sh <clientname>

Client.sh can be ran separately and should be to add more clients to the openvpn server. It also takes in a client name and defaults to "client".

