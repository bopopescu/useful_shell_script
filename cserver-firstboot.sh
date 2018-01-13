#!/bin/sh
echo nameserver 8.8.8.8 >/etc/resolv.conf
echo nameserver 203.131.233.141 >>/etc/resolv.conf
echo nameserver 203.131.233.151 >>/etc/resolv.conf

cd /etc/sysconfig/network-scripts

if [ -f ifcfg-eth0.bak ]
then
    rm -f ifcfg-eth0
    mv ifcfg-eth0.bak ifcfg-eth0
fi

if [ -f ifcfg-eth1.bak ]
then
    rm -f ifcfg-eth1
    mv ifcfg-eth1.bak ifcfg-eth1
fi

if [ -f ifcfg-eth2.bak ]
then
    rm -f ifcfg-eth2
    mv ifcfg-eth2.bak ifcfg-eth2
fi

if [ -f ifcfg-eth3.bak ]
then
    rm -f ifcfg-eth3
    mv ifcfg-eth3.bak ifcfg-eth3
fi

cd -

service network restart

route del -net 10.1.0.0 netmask 255.255.0.0 dev eth0

sed -i '/cserver-firstboot.sh/d' /etc/rc.local

exit

ifup bond0
ifup br0

tar zxvf sshpass-1.05.tar.gz
cd sshpass-1.05
./configure 
make 
make install
cd -

service network restart

