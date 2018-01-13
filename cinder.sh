#!/bin/bash

# For testing
mgr_ip="10.86.11.174"

#source common.inc

echo "cinder" > /etc/hostname

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
else
   echo "Get controller-ntp.conf: OK"
   mv others-ntp.conf ntp.conf
fi

cd -

service ntp restart
if [ ! $? -eq 0 ]
then
   echo "Restart ntp service failed: $?"
   exit 1
else
   echo "Restart ntp service: OK"
fi

# Install LVM2 as we will use it as backend
apt-get -y install lvm2

pv=""
osdev=""
cinder_dev=""
if [ -b /dev/hdb ]
then
   pv="/dev/hdb"
   osdev="hda"
   cinder_dev="hdb"
elif [ -b /dev/sdb ]
then
   pv="/dev/sdb"
   osdev="sda"
   cinder_dev="sdb"
elif [ -b /dev/xvdb ]
then
   pv="/dev/xvdb"
   osdev="xvda"
   cinder_dev="xvdb"
fi

pvcreate $pv
vgremove cinder-volumes
vgcreate cinder-volumes $pv 
if [ ! $? -eq 0 ]
then
   echo "Create vg 'cinder-volumes' failed: $?"
   exit 1
else
   echo "Create vg 'cinder-volumes': OK"
fi

rm -f /etc/lvm/lvm.conf 

cd /etc/lvm

wget http://$TFTP_SERVER/yum_repo/images/os/openstack/config/lvm.conf
if [ ! $? -eq 0 ]
then
   echo "wget lvm.conf failed: $?"
   exit 1
else
   echo "Get lvm.conf: OK"
   sed -i "s/sda/$osdev/g" lvm.conf
   sed -i "s/sdb/$cinder_dev/g" lvm.conf
fi

cd -

apt-get -y --force-yes install cinder-volume python-mysqldb
if [ ! $? -eq 0 ]
then
   echo "Install cinder-volume failed: $?"
   exit 1
else
   echo "Install cinder-volume: OK"
fi

rm -f /etc/cinder/cinder.conf 

cd /etc/cinder

wget http://$TFTP_SERVER/yum_repo/images/os/openstack/config/cinder.conf
if [ ! $? -eq 0 ]
then
   echo "wget cinder.conf failed: $?"
   exit 1
else
   echo "Get cinder.conf: OK"
   sed -i "s/my_ip =/my_ip =$mgr_ip/g" cinder.conf
   sed -i "s/cinder:123456/cinder:$CINDER_DBPASS/g" cinder.conf
   sed -i "s/admin_password =/admin_password = $CINDER_PASS/g" cinder.conf
   sed -i "s/rabbit_password =/rabbit_password = $RABBIT_PASS/g" cinder.conf
fi

cd -

service tgt restart && service cinder-volume restart
if [ ! $? -eq 0 ]
then
   echo "Restart tgt and cinder-volume services failed: $?"
   exit 1
else
   echo "Restart tgt and cinder-volume services: OK"
fi

rm -f /var/lib/cinder/cinder.sqlite

echo "Install openstack cinder node successfully!"
