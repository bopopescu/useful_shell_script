#!/bin/sh

echo 'installation-completed................'

mkdir /mnt
mount /dev/sda1 /mnt
cd /mnt/usr/bin

tftp_server_ip='192.168.10.100'
export tftp_server_ip

wget http://$tftp_server_ip/yum_repo/images/utils/scripts/getParam.py
chmod a+x getParam.py

mac=`ifconfig eth0|grep HWaddr|awk '{print $5}'`
server_type=`python getParam.py $mac '' server_level`

if [ 1$server_type = 1 ];then
   mac=`ifconfig eth2|grep HWaddr|awk '{print $5}'`
   server_type=`python getParam.py $mac '' server_level`
fi

export mac

echo $server_type

case $server_type in
"master")
   wget http://$tftp_server_ip/yum_repo/images/os/XenServer/scripts/master.sh
   chmod a+x master.sh
   sed -i '$ a cd /usr/bin' /mnt/etc/rc.d/rc.local
   sed -i '$ a sh master.sh &> /var/log/master.log &' /mnt/etc/rc.d/rc.local
   sed -i '$ a cd -' /mnt/etc/rc.d/rc.local
   ;;
"slave")
   wget http://$tftp_server_ip/yum_repo/images/os/XenServer/scripts/slave.sh
   chmod a+x slave.sh
   sed -i '$ a cd /usr/bin' /mnt/etc/rc.d/rc.local
   sed -i '$ a sh slave.sh &> /var/log/slave.log &' /mnt/etc/rc.d/rc.local 
   sed -i '$ a cd -' /mnt/etc/rc.d/rc.local
   ;;
*)
   echo "Error server type"
   exit 1
   ;;
esac

cd -

umount /dev/sda1
