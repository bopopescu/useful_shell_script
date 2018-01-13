#!/bin/sh
 
#mgr_ip=`vmtoolsd --cmd "info-get guestinfo.ovfenv"|grep manager_ip|awk '{print $3}'|awk -F\" '{print $2}'`
#mgr_netmask=`vmtoolsd --cmd "info-get guestinfo.ovfenv"|grep manager_netmask|awk '{print $3}'|awk -F\" '{print $2}'`
#mgr_gateway=`vmtoolsd --cmd "info-get guestinfo.ovfenv"|grep manager_gateway|awk '{print $3}'|awk -F\" '{print $2}'`

mgr_ip=`vmtoolsd --cmd "info-get guestinfo.mgr_ip"`
mgr_netmask=`vmtoolsd --cmd "info-get guestinfo.mgr_netmask"`
mgr_gateway=`vmtoolsd --cmd "info-get guestinfo.mgr_gateway"`

sed -i "s/IPADDR=/IPADDR=$mgr_ip/g" /etc/sysconfig/network/ifcfg-eth0
sed -i "s/NETMASK=/NETMASK=$mgr_netmask/g" /etc/sysconfig/network/ifcfg-eth0
sed -i "s/GATEWAY=/GATEWAY=$mgr_gateway/g" /etc/sysconfig/network/ifcfg-eth0

service network restart

route add default gw $mgr_gateway

sed -i '/init_vcenter/d' /etc/init.d/rc
