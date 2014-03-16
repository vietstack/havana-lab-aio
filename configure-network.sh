#!/bin/bash

InterfaceFile=/etc/network/interfaces

cat > $InterfaceFile <<EOF
# Localhost
auto lo
iface lo inet loopback

# Not Internet connected (OpenStack management network)
auto eth0
iface eth0 inet static
   address 10.10.10.51
   netmask 255.255.255.0

# For exposing OpenStack API over the Internet
auto eth1
iface eth1 inet static
   address 192.168.1.251
   netmask 255.255.255.0
   gateway 192.168.1.1
   dns-nameservers 8.8.8.8 8.8.4.4
EOF

#Mapping interface with MAC

MapMACFile=/etc/udev/rules.d/70-persistent-net.rules
eth1MAC=$(ifconfig eth1 | grep eth1 | awk '{print $5}')
eth0MAC=$(ifconfig eth0 | grep eth0 | awk '{print $5}')

cat > $MapMACFile <<EOF
SUBSYSTEM=="net", ACTION=="add", DRIVERS=="?*", ATTR{address}=="$eth0MAC",  ATTR{dev_id}=="0x0", ATTR{type}=="1", KERNEL=="eth*", NAME="eth0"

SUBSYSTEM=="net", ACTION=="add", DRIVERS=="?*", ATTR{address}=="$eth1MAC",  ATTR{dev_id}=="0x0", ATTR{type}=="1", KERNEL=="eth*", NAME="eth1"
EOF

# Restart Network
/etc/init.d/networking restart

exit 0

