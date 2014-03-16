#!/bin/bash

#PREPARE UBUNTU
#Add Havana repositories
apt-get -y install ubuntu-cloud-keyring python-software-properties software-properties-common python-keyring

echo deb http://ubuntu-cloud.archive.canonical.com/ubuntu precise-proposed/havana main >> /etc/apt/sources.list.d/havana.list

#update system
apt-get -y update && apt-get -y upgrade && apt-get -y dist-upgrade

#MySQL, RabbitMQ, NTP
apt-get install -y mysql-server python-mysqldb rabbitmq-server ntp


# Replace 127.0.0.1 by 0.0.0.0 for sql connect to all interface
sed -i 's/127.0.0.1/0.0.0.0/g' /etc/mysql/my.cnf
service mysql restart

# Databases set up 
mysql -u root -p << EOF
CREATE DATABASE keystone;
GRANT ALL ON keystone.* TO 'keystone'@'%' IDENTIFIED BY 'openstacktest';
GRANT ALL ON keystone.* TO 'keystone'@'localhost' IDENTIFIED BY 'openstacktest';

CREATE DATABASE glance;
GRANT ALL ON glance.* TO 'glance'@'%' IDENTIFIED BY 'openstacktest';
GRANT ALL ON glance.* TO 'glance'@'localhost' IDENTIFIED BY 'openstacktest';

CREATE DATABASE neutron;
GRANT ALL ON neutron.* TO 'neutron'@'%' IDENTIFIED BY 'openstacktest';
GRANT ALL ON neutron.* TO 'neutron'@'localhost' IDENTIFIED BY 'openstacktest';

CREATE DATABASE nova;
GRANT ALL ON nova.* TO 'nova'@'%' IDENTIFIED BY 'openstacktest';
GRANT ALL ON nova.* TO 'nova'@'localhost' IDENTIFIED BY 'openstacktest';

CREATE DATABASE cinder;
GRANT ALL ON cinder.* TO 'cinder'@'%' IDENTIFIED BY 'openstacktest';
GRANT ALL ON cinder.* TO 'cinder'@'localhost' IDENTIFIED BY 'openstacktest';

CREATE DATABASE heat;
GRANT ALL ON heat.* TO 'heat'@'%' IDENTIFIED BY 'openstacktest';
GRANT ALL ON heat.* TO 'heat'@'localhost' IDENTIFIED BY 'openstacktest';
EOF

#Enable IP Forwarding:
sed -i 's/#net.ipv4.ip_forward=1/net.ipv4.ip_forward=1/' /etc/sysctl.conf
sysctl net.ipv4.ip_forward=1

#KEYSTONE IIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIII
apt-get install -y keystone

#REMOVE SQLite Alchemist-------------------------------------------------------------------------------------------------------modulate-
sed -i 's|connection = sqlite:////var/lib/keystone/keystone.db|connection = mysql://keystone:openstacktest@10.10.10.51/keystone |g' /etc/keystone/keystone.conf

#Remove Keystone SQLite database:
rm /var/lib/keystone/keystone.db

#Restart the identity service then synchronize the database:
service keystone restart
keystone-manage db_sync

#Fill up the Keystone database using the two scripts available in this repository:
wget https://raw2.github.com/Ch00k/openstack-install-aio/master/populate_keystone.sh
sh populate_keystone.sh

#Create a simple credential file and source it so you have your credentials loaded in your environnment
echo -e 'export OS_TENANT_NAME=admin\nexport OS_USERNAME=admin\nexport OS_PASSWORD=openstacktest\nexport OS_AUTH_URL="http://192.168.1.251:5000/v2.0/"' > ~/.keystonerc
source ~/.keystonerc
echo "source ~/.keystonerc" >> ~/.bashrc

#GLANCE IIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIII
#Install Glance
apt-get -y install glance

#------------------Configure glance-api.conf and glance-registry.conf---------
GlanceAPIConf=/etc/glance/glance-api.conf
GlanceRegConf=/etc/glance/glance-registry.conf
sed -i 's|sql_connection = sqlite:////var/lib/glance/glance.sqlite|sql_connection = mysql://glance:openstacktest@10.10.10.51/glance|g' $GlanceAPIConf $GlanceRegConf
sed -i 's|auth_host = 127.0.0.1|auth_host = 10.10.10.51|g' $GlanceAPIConf $GlanceRegConf
sed -i 's|admin_tenant_name = %SERVICE_TENANT_NAME%|admin_tenant_name = service|g' $GlanceAPIConf $GlanceRegConf
sed -i 's|admin_user = %SERVICE_USER%|admin_user = glance|g' $GlanceAPIConf $GlanceRegConf
sed -i 's|admin_password = %SERVICE_PASSWORD%|admin_password = openstacktest|g' $GlanceAPIConf $GlanceRegConf
sed -i 's|#flavor=|flavor = keystone|g' $GlanceAPIConf $GlanceRegCon

#---------------------OK------------------------------------------

#------------------------glance-api-paste.ini && glance-registry-paste.ini
GlanceRegPaste=/etc/glance/glance-registry-paste.ini
GlanceAPIPaste=/etc/glance/glance-api-paste.ini
sed -i 's|\[filter:authtoken]|[filter:authtoken]\nadmin_password = openstacktest|' $GlanceRegPaste $GlanceAPIPaste
sed -i 's|\[filter:authtoken]|[filter:authtoken]\nadmin_user = glance|' $GlanceRegPaste $GlanceAPIPaste
sed -i 's|\[filter:authtoken]|[filter:authtoken]\nadmin_tenant_name = service|' $GlanceRegPaste $GlanceAPIPaste
sed -i 's|\[filter:authtoken]|[filter:authtoken]\nauth_protocol = http|' $GlanceRegPaste $GlanceAPIPaste
sed -i 's|\[filter:authtoken]|[filter:authtoken]\nauth_port = 35357|' $GlanceRegPaste $GlanceAPIPaste
sed -i 's|\[filter:authtoken]|[filter:authtoken]\nauth_host = 10.10.10.51|' $GlanceRegPaste $GlanceAPIPaste

#-----------------------------------OK-----------------------------------------------------------

#Remove Glance's SQLite database
rm /var/lib/glance/glance.sqlite

#Restart Glance services
service glance-api restart; service glance-registry restart

#Synchronize Glance database:
glance-manage db_sync

#Restart the services again to take modifications into account
service glance-registry restart; service glance-api restart

# NEUTRON IIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIII

# OpenVSwitch======================================================================================================================
#Install OpenVSwitch:
apt-get install -y openvswitch-controller openvswitch-switch openvswitch-datapath-dkms

#Create bridges:
#br-int for VM interaction:
ovs-vsctl add-br br-int
#br-ex to give VMs access to the Internet:
ovs-vsctl add-br br-ex

#Modify network configuration of your host-------------------------------------------------------------------

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
#
auto eth1
iface eth1 inet manual
   up ifconfig \$IFACE 0.0.0.0 up
   up ip link set \$IFACE promisc on
   down ip link set \$IFACE promisc off
   down ifconfig \$IFACE down

# Add br-ex inteface
auto br-ex
iface br-ex inet static
   address 192.168.1.251
   netmask 255.255.255.0
   gateway 192.168.1.1
   dns-nameservers 8.8.8.8 8.8.4.4
EOF

#Add eth1 to br-ex:
ovs-vsctl add-port br-ex eth1

/etc/init.d/networking restart
sleep 15s
ping 8.8.8.8 -c 3
#Neutron ===================================================================================================================
#Install Neutron packages:
apt-get install -y neutron-server neutron-plugin-openvswitch neutron-plugin-openvswitch-agent dnsmasq neutron-dhcp-agent neutron-l3-agent neutron-metadata-agent

#Stop neutron-server:
service neutron-server stop

#config file neutron.conf
NeutronConf=/etc/neutron/neutron.conf
sed -i 's|connection = sqlite:////var/lib/neutron/neutron.sqlite|connection = mysql://neutron:openstacktest@10.10.10.51/neutron|g' $NeutronConf
sed -i 's|auth_host = 127.0.0.1|auth_host = 10.10.10.51|g' $NeutronConf
sed -i 's|admin_tenant_name = %SERVICE_TENANT_NAME%|admin_tenant_name = service|g' $NeutronConf
sed -i 's|admin_user = %SERVICE_USER%|admin_user = neutron|g' $NeutronConf
sed -i 's|admin_password = %SERVICE_PASSWORD%|admin_password = openstacktest|g' $NeutronConf
sed -i 's|#flavor=|flavor = keystone|g' $NeutronConf

#config api-paste.ini file
NeutronAPIPaste=/etc/neutron/api-paste.ini
sed -i 's|\[filter:authtoken]|[filter:authtoken]\nadmin_password = openstacktest|' $NeutronAPIPaste
sed -i 's|\[filter:authtoken]|[filter:authtoken]\nadmin_user = neutron|' $NeutronAPIPaste
sed -i 's|\[filter:authtoken]|[filter:authtoken]\nadmin_tenant_name = service|' $NeutronAPIPaste
sed -i 's|\[filter:authtoken]|[filter:authtoken]\nauth_protocol = http|' $NeutronAPIPaste
sed -i 's|\[filter:authtoken]|[filter:authtoken]\nauth_port = 35357|' $NeutronAPIPaste
sed -i 's|\[filter:authtoken]|[filter:authtoken]\nauth_host = 10.10.10.51|' $NeutronAPIPaste

#Config metadata-agent.ini file
MetaDataAgent=/etc/neutron/metadata_agent.ini
sed -i 's|auth_url = http://localhost:5000/v2.0|auth_url = http://10.10.10.51:35357/v2.0|g' $MetaDataAgent
sed -i 's|admin_tenant_name = %SERVICE_TENANT_NAME%|admin_tenant_name = service|g' $MetaDataAgent
sed -i 's|admin_user = %SERVICE_USER%|admin_user = neutron|g' $MetaDataAgent
sed -i 's|admin_password = %SERVICE_PASSWORD%|admin_password = openstacktest|g' $MetaDataAgent
sed -i 's|# nova_metadata_ip = 127.0.0.1|nova_metadata_ip = 10.10.10.51|g' $MetaDataAgent
sed -i 's|# nova_metadata_port = 8775|nova_metadata_port = 8775|g' $MetaDataAgent
sed -i 's|# metadata_proxy_shared_secret =|metadata_proxy_shared_secret = helloOpenStack|g' $MetaDataAgent

#Config l3-agent.init
cat >> /etc/neutron/l3_agent.ini << EOF
interface_driver = neutron.agent.linux.interface.OVSInterfaceDriver
use_namespaces = True
external_network_bridge = br-ex
signing_dir = /var/cache/neutron
admin_tenant_name = service
admin_user = neutron
admin_password = openstacktest
auth_url = http://10.10.10.51:35357/v2.0
l3_agent_manager = neutron.agent.l3_agent.L3NATAgentWithStateReport
root_helper = sudo neutron-rootwrap /etc/neutron/rootwrap.conf
interface_driver = neutron.agent.linux.interface.OVSInterfaceDriver
EOF

#Config dhcp_agent.ini
cat >> /etc/neutron/dhcp_agent.ini << EOF
interface_driver = neutron.agent.linux.interface.OVSInterfaceDriver
dhcp_driver = neutron.agent.linux.dhcp.Dnsmasq
use_namespaces = True
signing_dir = /var/cache/neutron
admin_tenant_name = service
admin_user = neutron
admin_password = openstacktestauth_url = http://10.10.10.51:35357/v2.0
dhcp_agent_manager = neutron.agent.dhcp_agent.DhcpAgentWithStateReport
root_helper = sudo neutron-rootwrap /etc/neutron/rootwrap.conf
state_path = /var/lib/neutron
EOF

#Config neutron-plugin.ini
NeutronPlugin=/etc/neutron/plugins/openvswitch/ovs_neutron_plugin.ini
sed -i 's|\[ovs]|#[ovs]|g' $NeutronPlugin
sed -i 's|\[securitygroup]|#[securitygroup]|g' $NeutronPlugin
cat >> $NeutronPlugin << EOF
[ovs]
tenant_network_type = gre
enable_tunneling = True
tunnel_id_ranges = 1:1000
integration_bridge = br-int
tunnel_bridge = br-tun
local_ip = 10.10.10.51
[securitygroup]
firewall_driver = neutron.agent.linux.iptables_firewall.OVSHybridIptablesFirewallDriver
[database]
sql_connection=mysql://neutron:openstacktest@10.10.10.51/neutron
EOF

#Remove Neutron's SQLite database
rm /var/lib/neutron/neutron.sqlite

#Restart all neutron services:
echo -e 'for i in $( ls /etc/init.d/neutron-* ); do service `basename $i` restart; done\nservice dnsmasq restart' > neutronrestart.sh
sed -i 's|\#!/bin/sh -e|#!/bin/sh -e \nsh /root/havana-lab-aio/neutronrestart.sh|' /etc/rc.local
sh /root/havana-lab-aio/neutronrestart.sh

#Check Neutron agents
neutron agent-list

#NOVA IIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIII

#Config nova.conf file
cat > /etc/nova/nova.conf << EOF
[DEFAULT]
logdir=/var/log/nova
state_path=/var/lib/nova
lock_path=/run/lock/nova
api_paste_config=/etc/nova/api-paste.ini
compute_scheduler_driver=nova.scheduler.simple.SimpleScheduler
nova_url=http://10.10.10.51:8774/v1.1/
sql_connection=mysql://nova:openstacktest@10.10.10.51/nova
root_helper=sudo nova-rootwrap /etc/nova/rootwrap.conf

# Auth
use_deprecated_auth=false
auth_strategy=keystone

# Imaging service
glance_api_servers=10.10.10.51:9292
image_service=nova.image.glance.GlanceImageService

# Vnc configuration
novnc_enabled=true
novncproxy_base_url=http://192.168.1.251:6080/vnc_auto.html
novncproxy_port=6080
vncserver_proxyclient_address=10.10.10.51
vncserver_listen=0.0.0.0

# Network settings
network_api_class=nova.network.neutronv2.api.API
neutron_url=http://10.10.10.51:9696
neutron_auth_strategy=keystone
neutron_admin_tenant_name=service
neutron_admin_username=neutron
neutron_admin_password=openstacktest
neutron_admin_auth_url=http://10.10.10.51:35357/v2.0
libvirt_vif_driver=nova.virt.libvirt.vif.LibvirtHybridOVSBridgeDriver
linuxnet_interface_driver=nova.network.linux_net.LinuxOVSInterfaceDriver
firewall_driver=nova.virt.firewall.NoopFirewallDriver
security_group_api=neutron

# Metadata
service_neutron_metadata_proxy = True
neutron_metadata_proxy_shared_secret = helloOpenStack
metadata_host = 10.10.10.51
metadata_listen = 10.10.10.51
metadata_listen_port = 8775

# Compute
compute_driver=libvirt.LibvirtDriver

# Cinder
volume_api_class=nova.volume.cinder.API
osapi_volume_listen_port=5900
cinder_catalog_info=volume:cinder:internalURL

EOF

#Config nova-compute.conf
cat > /etc/nova/nova-compute.conf << EOF
[DEFAULT]
libvirt_type=kvm
libvirt_ovs_bridge=br-int
libvirt_vif_type=ethernet
libvirt_vif_driver=nova.virt.libvirt.vif.LibvirtHybridOVSBridgeDriver
libvirt_use_virtio_for_bridges=True
compute_driver=libvirt.LibvirtDriver
EOF

#config api-paste.ini

NovaAPIPaste=/etc/nova/api-paste.ini
sed -i 's|auth_host = 127.0.0.1|auth_host = 10.10.10.51|g' $NovaAPIPaste
sed -i 's|admin_tenant_name = %SERVICE_TENANT_NAME%|admin_tenant_name = service|g' $NovaAPIPaste
sed -i 's|admin_user = %SERVICE_USER%|admin_user = nova|g' $NovaAPIPaste
sed -i 's|admin_password = %SERVICE_PASSWORD%|admin_password = openstacktest|g' $NovaAPIPaste
sed -i 's|#signing_dir = /var/lib/nova/keystone-signing|signing_dirname = /tmp/keystone-signing-nova|g' $NovaAPIPaste

#Restart Nova services:
for i in $( ls /etc/init.d/nova-* ); do service `basename $i` restart; done

#Remove Nova's SQLite database:
rm /var/lib/nova/nova.sqlite

#Synchronize your database:
nova-manage db sync

#Restart Nova services:
for i in $( ls /etc/init.d/nova-* ); do service `basename $i` restart; done

#Check
nova-manage service list

#CINDERIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIII

#Install Cinder packages:
apt-get install -y cinder-api cinder-scheduler cinder-volume

#Create a physical volume and a volume group on the /dev/sda3 partition you created during OS installation:
pvcreate /dev/sda3
vgcreate cinder-volumes /dev/sda3

#Config cinder.conf
cat > /etc/cinder/cinder.conf << EOF
[DEFAULT]
rootwrap_config=/etc/cinder/rootwrap.conf
sql_connection = mysql://cinder:openstacktest@10.10.10.51/cinder
api_paste_config = /etc/cinder/api-paste.ini
iscsi_helper = tgtadm
volume_name_template = volume-%s
volume_group = cinder-volumes
auth_strategy = keystone
volume_clear = none
state_path = /var/lib/cinder
verbose = True
lock_path = /var/lock/cinder
volumes_dir = /var/lib/cinder/volumes
EOF

#Config api-paste.ini
CinderAPIPaste=/etc/cinder/api-paste.ini
sed -i 's|\[filter:authtoken]|[filter:authtoken]\nservice_host = 192.168.1.251|g' $CinderAPIPaste
sed -i 's|\[filter:authtoken]|[filter:authtoken]\nservice_port = 5000|g' $CinderAPIPaste
sed -i 's|\[filter:authtoken]|[filter:authtoken]\nauth_host = 10.10.10.51|g' $CinderAPIPaste
sed -i 's|admin_tenant_name = %SERVICE_TENANT_NAME%|admin_tenant_name = service|g' $CinderAPIPaste
sed -i 's|admin_user = %SERVICE_USER%|admin_user = cinder|g' $CinderAPIPaste
sed -i 's|admin_password = %SERVICE_PASSWORD%|admin_password = openstacktest|g' $CinderAPIPaste

#Remove Cinder's SQLite database:
rm /var/lib/cinder/cinder.sqlite

#Then, synchronize the database:
cinder-manage db sync

#Restart the cinder services:
service tgt restart
for i in $( ls /etc/init.d/cinder-* ); do service `basename $i` restart; done

#SWIFT IIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIII

#Install Swift packages
apt-get -y install swift swift-account swift-container swift-object swift-proxy openssh-server memcached python-pip python-netifaces python-xattr python-memcache xfsprogs python-keystoneclient python-swiftclient python-webob git

#Create configuration diretory:
mkdir -p /etc/swift && chown -R swift:swift /etc/swift/

#Create /etc/swift/swift.conf like the following:
cat > /etc/swift/swift.conf << EOF
[swift-hash]
swift_hash_path_suffix = openstacktest
EOF

#Change ownership on the XFS partition mountpoint:
chown -R swift:swift /srv/node

#Create self-signed cert for SSL:
openssl req -new -x509 -nodes -out /etc/swift/cert.crt -keyout /etc/swift/cert.key

#Because the distribution packages do not include a copy of the keystoneauth middleware, ensure that the proxy server includes them:
git clone https://github.com/openstack/swift.git && cd swift && python setup.py install

#Create /etc/swift/proxy-server.conf:
cat > /etc/swift/proxy-server.conf << EOF
[DEFAULT]
bind_port = 8080
user = swift

[pipeline:main]
pipeline = healthcheck cache authtoken keystoneauth proxy-server

[app:proxy-server]
use = egg:swift#proxy
allow_account_management = true
account_autocreate = true

[filter:keystoneauth]
use = egg:swift#keystoneauth
operator_roles = Member,admin,swiftoperator

[filter:authtoken]
paste.filter_factory = keystoneclient.middleware.auth_token:filter_factory
delay_auth_decision = true
signing_dir = /home/swift/keystone-signing
auth_protocol = http
auth_host = 10.10.10.51
auth_port = 35357
admin_token = openstacktest
admin_tenant_name = service
admin_user = swift
admin_password = openstacktest

[filter:cache]
use = egg:swift#memcache

[filter:catch_errors]
use = egg:swift#catch_errors

[filter:healthcheck]
use = egg:swift#healthcheck
EOF

#Create the signing_dir and set its permissions accordingly:
mkdir -p /home/swift/keystone-signing && chown -R swift:swift /home/swift/keystone-signing

#Create the account, container, and object rings:
cd /etc/swift
swift-ring-builder account.builder create 18 3 1
swift-ring-builder container.builder create 18 3 1
swift-ring-builder object.builder create 18 3 1

#Add entries to each ring:
swift-ring-builder account.builder add z1-10.10.10.51:6002/sda4 100
swift-ring-builder container.builder add z1-10.10.10.51:6001/sda4 100
swift-ring-builder object.builder add z1-10.10.10.51:6000/sda4 100

#Rebalance the rings:
swift-ring-builder account.builder rebalance
swift-ring-builder container.builder rebalance
swift-ring-builder object.builder rebalance

#Make sure the swift user owns all configuration files:
chown -R swift:swift /etc/swift

#Start Swift services:
swift-init main start && service rsyslog restart && service memcached restart

#Heat IIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIII
#Install Heat packages:
apt-get -y install heat-api heat-api-cfn heat-engine

#Config Heat.conf
HeatConf=/etc/heat/heat.conf
sed -i 's|\[DEFAULT]|[DEFAULT]\nlog_dir = /var/log/heat|g' $HeatConf
sed -i 's|\[DEFAULT]|[DEFAULT]\nverbose = True|g' $HeatConf
sed -i 's|\[DEFAULT]|[DEFAULT]\nsql_connection = mysql://heat:openstacktest@10.10.10.51/heat|g' $HeatConf
cat >>  $HeatConf << EOF
[keystone_authtoken]
auth_host = 10.10.10.51
auth_port = 35357
auth_protocol = http
auth_uri = http://10.10.10.51:5000/v2.0
admin_tenant_name = service
admin_user = heat
admin_password = openstacktest

[ec2_authtoken]
auth_uri = http://10.10.10.51:5000/v2.0
keystone_ec2_uri = http://10.10.10.51:5000/v2.0/ec2tokens
EOF

################
mkdir /etc/heat/environment.d
wget https://raw2.github.com/openstack/heat/master/etc/heat/environment.d/default.yaml -O /etc/heat/environment.d/default.yaml

#Synchronize Heat database:
heat-manage db_sync

#Restart Heat services:
for i in $( ls /etc/init.d/heat-* ); do service `basename $i` restart; done



#Horizon IIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIII

#Install Horizon packages and remove Ubuntu Horizon theme:
apt-get -y install openstack-dashboard memcached && dpkg --purge openstack-dashboard-ubuntu-theme

#Reload Apache and memcached:
service apache2 restart; service memcached restart
















