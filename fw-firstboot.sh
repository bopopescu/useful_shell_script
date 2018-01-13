#!/bin/sh

echo nameserver 8.8.8.8 >/etc/resolv.conf
echo nameserver 203.131.233.141 >>/etc/resolv.conf
echo nameserver 203.131.233.151 >>/etc/resolv.conf

sed -i '/fw-firstboot.sh/d' /etc/rc.d/rc.local

cd /etc/sysconfig/network-scripts

for i in 1 2 3 4
do
   if [ -f ifcfg-em$i ]
   then
       rm -f ifcfg-em$i
   fi 
done

cd -

service network restart

route del -net 10.1.0.0 netmask 255.255.0.0

exit
