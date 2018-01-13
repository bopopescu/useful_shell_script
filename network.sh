#!/bin/bash

# For testing
mgr_ip="10.86.11.172"

#source common.inc

echo "network" > /etc/hostname

#tunnel_ip=`python getParam.py $mac '' tunnel_ip`
tunnel_ip="10.0.1.21"

mv /etc/sysctl.conf /etc/sysctl.conf.old

cd /etc

wget http://$TFTP_SERVER/yum_repo/images/os/openstack/config/network-sysctl.conf
if [ ! $? -eq 0 ]
then
   echo "wget network-sysctl.conf failed: $?"
   exit 1
else
   echo "Get network-sysctl.conf: OK"
   mv network-sysctl.conf sysctl.conf
fi

cd -

sysctl -p

# Disable automatic update services
sed -i "/APT::Periodic::Update-Package-Lists/d" /etc/apt/apt.conf.d/10periodic
sed -i '$ a APT::Periodic::Update-Package-Lists "0";' /etc/apt/apt.conf.d/10periodic

cd /etc/apt

mv sources.list sources.list.old
wget http://$TFTP_SERVER/yum_repo/images/os/openstack/config/sources.list

cd -

apt-get -y update
# Enable the OpenStack repository
apt-get -y install ubuntu-cloud-keyring
echo "deb http://10.86.11.161/ccp/ubuntu-cloud/ubuntu-cloud.archive.canonical.com/ubuntu" "trusty-updates/juno main" > /etc/apt/sources.list.d/cloudarchive-juno.list

apt-get -y update
apt-get -y dist-upgrade

# Installing NTP service 
apt-get -y install ntp
if [ ! $? -eq 0 ]
then
   echo "Install ntp failed: $?"
   exit 1
else
   echo "Install ntp: OK"
fi

rm -f /etc/ntp.conf 
cd /etc

wget http://$TFTP_SERVER/yum_repo/images/os/openstack/config/others-ntp.conf
if [ ! $? -eq 0 ]
then
   echo "wget controller-ntp.conf failed: $?"
   exit 1
else
   echo "Get controller-ntp.conf: OK"
fi
mv others-ntp.conf ntp.conf

cd -

service ntp restart
if [ ! $? -eq 0 ]
then
   echo "Restart ntp service failed: $?"
   exit 1 
else
   echo "Restart ntp service: OK"
fi

# Install neutron components
apt-get -y --force-yes install neutron-plugin-ml2 neutron-plugin-openvswitch-agent neutron-l3-agent neutron-dhcp-agent bridge-utils
if [ ! $? -eq 0 ]
then
   echo "Install neutron components failed: $?"
   exit 1
else
   echo "Install neutron components: OK"
fi

rm -f /etc/neutron/neutron.conf

cd /etc/neutron

wget http://$TFTP_SERVER/yum_repo/images/os/openstack/config/neutron.conf
if [ ! $? -eq 0 ]
then
   echo "wget neutron.conf failed: $?"
   exit 1
else
   echo "Get neutron.conf: OK"
   
   sed -i "s/admin_password =/admin_password = $NEUTRON_PASS/g" neutron.conf
   sed -i "s/rabbit_password =/rabbit_password = $RABIIT_PASS/g" neutron.conf
fi

cd -

# Configure ML2
rm -f /etc/neutron/plugins/ml2/ml2_conf.ini
cd /etc/neutron/plugins/ml2
wget http://$TFTP_SERVER/yum_repo/images/os/openstack/config/ml2_conf.ini
if [ ! $? -eq 0 ]
then
   echo "wget ml2_conf.ini failed: $?"
   exit 1
else
   echo "Get ml2_conf.ini: OK"
   sed -i "s/local_ip =/local_ip = $tunnel_ip/g" ml2_conf.ini
fi

cd -

# Configure l3 agent
rm -f /etc/neutron/l3_agent.ini
cd /etc/neutron

wget http://$TFTP_SERVER/yum_repo/images/os/openstack/config/l3_agent.ini
if [ ! $? -eq 0 ]
then
   echo "wget l3_agent.ini failed: $?"
   exit 1
else
   echo "Get l3_agent.ini: OK"
fi

cd -

# Configure dhcp agent
rm -f /etc/neutron/dhcp_agent.ini

cd /etc/neutron

wget http://$TFTP_SERVER/yum_repo/images/os/openstack/config/dhcp_agent.ini
if [ ! $? -eq 0 ]
then
   echo "wget dhcp_agent.ini failed: $?"
   exit 1
else
   echo "Get dhcp_agent.ini: OK"
fi

wget http://$TFTP_SERVER/yum_repo/images/os/openstack/config/dnsmasq-neutron.conf
if [ ! $? -eq 0 ]
then
   echo "wget dnsmasq-neutron.conf failed: $?"
   exit 1
else
   echo "Get dnsmasq-neutron.conf: OK"
fi

cd -

# Configure metadata agent
rm -f /etc/neutron/metadata_agent.ini
cd /etc/neutron
wget http://$TFTP_SERVER/yum_repo/images/os/openstack/config/metadata_agent.ini
if [ ! $? -eq 0 ]
then
   echo "wget metadata_agent.ini failed: $?"
   exit 1
else
   echo "Get metadata_agent.ini: OK"
   sed -i "s/admin_password =/admin_password = $NEUTRON_PASS/g" metadata_agent.ini
fi

cd -

service openvswitch-switch restart
if [ ! $? -eq 0 ]
then
   echo "Restart openvswitch-switch service failed: $?"
   exit 1
else
   echo "Restart openvswitch-switch service: OK"
fi

ovs-vsctl add-br br-ex
ovs-vsctl add-port br-ex eth2
if [ ! $? -eq 0 ]
then
   echo "Ovs add port to bridge 'br-ex' failed: $?"
   exit 1
else
   echo "Ovs add port to bridge 'br-ex': OK"
fi

service neutron-plugin-openvswitch-agent restart && service neutron-l3-agent restart && service neutron-dhcp-agent restart && service neutron-metadata-agent restart
if [ ! $? -eq 0 ]
then
   echo "Restart neutron services failed: $?"
   exit 1
else
   echo "Restart neutron services: OK"
fi

echo "Install openstack network node successfully!"
