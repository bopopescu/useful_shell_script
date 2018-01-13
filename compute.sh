#!/bin/bash

# For testing
mgr_ip="10.86.11.173"

#source common.inc

echo "compute" > /etc/hostname

#tunnel_ip=`python getParam.py $mac '' tunnel_ip`
tunnel_ip="10.0.1.31"

mv /etc/sysctl.conf /etc/sysctl.conf.old

cd /etc

wget http://$TFTP_SERVER/yum_repo/images/os/openstack/config/compute-sysctl.conf
if [ ! $? -eq 0 ]
then
   echo "wget compute-sysctl.conf failed: $?"
   exit 1
else
   echo "Get compute-sysctl.conf: OK"
   mv compute-sysctl.conf sysctl.conf
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
else
   echo "Install ntp: OK"
fi

rm -f /etc/ntp.conf 
cd /etc
wget http://$TFTP_SERVER/yum_repo/images/os/openstack/config/others-ntp.conf
if [ ! $? -eq 0 ]
then
   echo "wget controller-ntp.conf failed: $?"
else
   echo "Get controller-ntp.conf: OK"
fi
mv others-ntp.conf ntp.conf
cd -

service ntp restart
if [ ! $? -eq 0 ]
then
   echo "Restart ntp service failed: $?"
else
   echo "Restart ntp service: OK"
fi

# Install nova components
apt-get -y --force-yes install nova-compute sysfsutils

rm -f /etc/nova/nova.conf

cd /etc/nova

wget http://$TFTP_SERVER/yum_repo/images/os/openstack/config/nova.conf
if [ ! $? -eq 0 ]
then
   echo "wget nova.conf failed: $?"
   exit 1
else
   echo "Get nova.conf: OK"

   sed -i "s/admin_password = nova/admin_password = $NOVA_PASS/g" nova.conf
   sed -i "s/admin_password = neutron/admin_password = $NEUTRON_PASS/g" nova.conf
   sed -i "s/rabbit_password =/rabbit_password = $RABBIT_PASS/g" nova.conf
   sed -i "s/my_ip =/my_ip = $mgr_ip/g" nova.conf
   sed -i "s/vncserver_proxyclient_address =/vncserver_proxyclient_address = $mgr_ip/g" nova.conf
fi

cd -

rm -f /var/lib/nova/nova.sqlite

apt-get -y --force-yes install neutron-plugin-ml2 neutron-plugin-openvswitch-agent
if [ ! $? -eq 0 ]
then
   echo "Install neutron plugin failed: $?"
   exit 1
else
   echo "Install neutron plugin: OK"
fi

rm -f /etc/neutron/neutron.conf

cd /etc/neutron

wget http://$TFTP_SERVER/yum_repo/images/os/openstack/config/neutron-compute.conf
if [ ! $? -eq 0 ]
then
   echo "wget neutron-compute.conf failed: $?"
   exit 1
else
   echo "Get neutron-compute: OK"
   mv neutron-compute.conf neutron.conf
   sed -i "s/admin_password =/admin_password = $NEUTRON_PASS/g" neutron.conf
   sed -i "s/rabbit_password =/rabbit_password = $RABBIT_PASS/g" neutron.conf
fi

cd -

rm -f /etc/neutron/plugin/ml2_conf.ini
cd /etc/neutron/plugin/ml2

wget http://$TFTP_SERVER/yum_repo/images/os/openstack/config/compute-ml2_conf.ini
if [ ! $? -eq 0 ]
then
   echo "wget compute-ml2_conf.ini failed: $?"
   exit 1
else
   echo "Get compute-ml2_conf.ini: OK"
   mv compute-ml2_conf.ini ml2_conf.ini
   sed -i "s/local_ip =/local_ip = $tunnel_ip/g" ml2_conf.ini
fi

cd -

apt-get -y install libvirt*
if [ ! $? -eq 0 ]
then
   echo "Install libvirt failed: $?"
   exit 1
else
   echo "Install libvirt: OK"
fi

hvm_support=`egrep -c '(vmx|svm)' /proc/cpuinfo`
if [ $hvm_support = "0" ]
then
   sed -i "/virt_type/d" /etc/nova/nova-compute.conf
   sed -i "$ a virt_type=qemu" /etc/nova/nova-compute.conf
fi  

service nova-compute restart
if [ ! $? -eq 0 ]
then
   echo "Restart nova-compute failed: $?"
   exit 1
else
   echo "Restart nova-compute: OK"
fi

service neutron-plugin-openvswitch-agent restart
if [ ! $? -eq 0 ]
then
   echo "Restart neutron-plugin-openvswitch-agent failed: $?"
   exit 1
else
   echo "Restart neutron-plugin-openvswitch-agent: OK"
fi


echo "Install openstack compute node successfully!"
