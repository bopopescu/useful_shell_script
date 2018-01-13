#!/bin/bash

# For testing
mgr_ip="10.86.11.175"

#source common.inc

echo "swift" > /etc/hostname

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
   exit  1
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

apt-get -y install xfsprogs rsync
if [ ! $? -eq 0 ]
then
   echo "Install xfsprogs, rsync failed: $?"
   exit 1
else
   echo "Install xfsprogs, rsync: OK"
fi

dev1=""
dev2=""
if [ -b /dev/hdb ]
then
   dev1="/dev/hdb"
   dev2="/dev/hdc"
elif [ -b /dev/sdb ]
then
   dev1="/dev/sdb"
   dev2="/dev/sdc"
elif [ -b /dev/xvdb ]
then
   dev1="/dev/xvdb"
   dev2="/dev/xvdc"
fi

mkfs.xfs $dev1 -f
if [ ! $? -eq 0 ]
then
   echo "mkfs.xfs $dev1 failed: $?"
   exit 1
else
   echo "mkfs.xfs $dev1: OK"
fi

mkfs.xfs $dev2 -f
if [ ! $? -eq 0 ]
then
   echo "mkfs.xfs $dev2 failed: $?"
   exit 1
else
   echo "mkfs.xfs $dev2: OK"
fi

mkdir -p /srv/node/`basename $dev1`
mkdir -p /srv/node/`basename $dev2`

echo "$dev1 /srv/node/`basename $dev1` xfs noatime,nodiratime,nobarrier,logbufs=8 0 2" >> /etc/fstab
echo "$dev2 /srv/node/`basename $dev2` xfs noatime,nodiratime,nobarrier,logbufs=8 0 2" >> /etc/fstab

mount /srv/node/`basename $dev1`
if [ ! $? -eq 0 ]
then
   echo "mount $dev1 failed: $?"
   exit 1
else
   echo "mount $dev1: OK"
fi

mount /srv/node/`basename $dev2`
if [ ! $? -eq 0 ]
then
   echo "mount /srv/node/$dev2 failed: $?"
   exit 1
else
   echo "mount /srv/node/$dev2: OK"
fi

rm -f /etc/rsyncd.conf

cd /etc

wget http://$TFTP_SERVER/yum_repo/images/os/openstack/resource/rsyncd.conf
if [ ! $? -eq 0 ]
then
   echo "wget rsyncd.conf failed: $?"
else
   echo "Get rsyncd.conf: OK"
   sed -i "s/address =/address = $mgr_ip/g" rsyncd.conf
fi

cd -

service rsync start
if [ ! $? -eq 0 ]
then
   echo "Restart rsync service failed: $?"
else
   echo "Restart rsync service: OK"
fi

apt-get -y --force-yes install swift swift-account swift-container swift-object
if [ ! $? -eq 0 ]
then
   echo "Install swift components failed: $?"
else
   echo "Install swift components: OK"
fi

rm -f /etc/swift/swift.conf
rm -f /etc/swift/account-server.conf
rm -f /etc/swift/container-server.conf
rm -f /etc/swift/object-server.conf

cd /etc/swift

wget http://$TFTP_SERVER/yum_repo/images/os/openstack/config/swift.conf
wget http://$TFTP_SERVER/yum_repo/images/os/openstack/config/account-server.conf
wget http://$TFTP_SERVER/yum_repo/images/os/openstack/config/container-server.conf
wget http://$TFTP_SERVER/yum_repo/images/os/openstack/config/object-server.conf
sed -i "s/bind_ip =/bind_ip = $mgr_ip/g" account-server.conf
sed -i "s/bind_ip =/bind_ip = $mgr_ip/g" container-server.conf
sed -i "s/bind_ip =/bind_ip = $mgr_ip/g" object-server.conf

cd -

chown -R swift:swift /srv/node

mkdir -p /var/cache/swift
chown -R swift:swift /var/cache/swift

apt-get -y install sshpass
if [ ! $? -eq 0 ]
then
   echo "Install sshpass failed: $?"
else
   echo "Install sshpass: OK"
fi

#cluster_id=`python getParam.py $mac '' cluster_id`
#SERVER_MAC_LIST=`python getParam.py '' $cluster_id  macaddress`

#for MAC in $(echo $SERVER_MAC_LIST|awk '{print;}')
#do
#   server_level=`python getParam.py $MAC '' server_level`
#   if [ $server_level = "controller" ]
#   then
#      CONTROLLER_IP=`python getParam.py $MAC '' mgr_ip`
#      CONTROLLER_USER=`python getParam.py $MAC '' ssh_user`
#      CONTROLLER_PASSWD=`python getParam.py $MAC '' ssh_password`

#      ret=1
#      while [ ! $ret -eq 0 ] 
#      do
#       sshpass -p $CONTROLLER_PASSWD scp $CONTROLLER_USER@$CONTROLLER_IP:/etc/swift/account.ring.gz 
#                                                                         /etc/swift/account.ring.gz
#       sshpass -p $CONTROLLER_PASSWD scp $CONTROLLER_USER@$CONTROLLER_IP:/etc/swift/container.ring.gz 
#                                                                         /etc/swift/container.ring.gz
#       sshpass -p $CONTROLLER_PASSWD scp $CONTROLLER_USER@$CONTROLLER_IP:/etc/swift/object.ring.gz 
#                                                                         /etc/swift/object.ring.gz
#       ret=$?
#       sleep 10
#      done
     
#      break
#   fi
#done

# For testing
       sshpass -p 123456 scp controller@10.86.11.171:/etc/swift/account.ring.gz 
                                        /etc/swift/account.ring.gz
       sshpass -p 123456 scp controller@10.86.11.171:/etc/swift/container.ring.gz 
                                        /etc/swift/container.ring.gz
       sshpass -p 123456 scp controller@10.86.11.171:/etc/swift/object.ring.gz 
                                        /etc/swift/object.ring.gz
# end

swift-init all start
if [ ! $? -eq 0 ]
then
   echo "swift start failed: $?"
else
   echo "swift start: OK"
fi

echo "Install openstack swift node successfully!"
