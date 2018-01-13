#!/bin/bash
tftp_server_ip="192.168.10.100"

sed -i "$ a $tftp_server_ip tftp_server" /etc/hosts

mac=`ifconfig eth0|grep HWaddr|awk '{print $5}'`

grid=`python getParam.py $mac '' grid`
public_ip=`python getParam.py $mac '' mgr_ip`
public_netmask=`python getParam.py $mac '' netmask`
public_gateway=`python getParam.py $mac '' gateway`
server_level=`python getParam.py $mac '' server_level`

#For testing
server_level='CServer1'


servernum=${server_level: -1}
manage_ip=`python getParam.py $mac '' manage_ip`

private_ip=""
private_netmask=""
private_gateway=""
heartbeat_ip=""
ucast_ip=""
FW1_heartbeat_ip="192.168.40.11"
FW2_heartbeat_ip="192.168.40.12"

case $server_level in
"CServer1")
     private_ip="10.1.1.11"
     private_netmask="255.255.0.0"
     private_gateway="10.1.0.10"
   ;;
"CServer2")
     private_ip="10.1.1.12"
     private_netmask="255.255.0.0"
     private_gateway="10.1.0.10"
   ;;
"CServer3")
     private_ip="10.1.1.13"
     private_netmask="255.255.0.0"
     private_gateway="10.1.0.10"
  ;;
"CServer4")
     private_ip="10.1.1.14"
     private_netmask="255.255.0.0"
     private_gateway="10.1.0.10"
   ;;
"CServer5")
     private_ip="10.1.1.15"
     private_netmask="255.255.0.0"
     private_gateway="10.1.0.10"
   ;;
"CServer6")
     private_ip="10.1.1.16"
     private_netmask="255.255.0.0"
     private_gateway="10.1.0.10"
   ;;
"CServer7")
     private_ip="10.1.1.17"
     private_netmask="255.255.0.0"
     private_gateway="10.1.0.10"
   ;;

"Firewall1")
     private_ip="10.1.1.9"
     private_netmask="255.255.0.0"
     heartbeat_ip="192.168.40.11"
     ucast_ip="192.168.40.12"
   ;;
"Firewall2")
     private_ip="10.1.1.10"
     private_netmask="255.255.0.0"
     heartbeat_ip="192.168.40.12"
     ucast_ip="192.168.40.11"
   ;;
*)
   echo "Invalid server type: $server_level"
   exit 1
   ;;
esac

export tftp_server_ip
export mac
export grid
export public_ip
export public_netmask
export public_gateway
export server_level
export servernum
export private_ip
export private_netmask
export private_gateway
export heartbeat_ip
export ucast_ip
export FW1_heartbeat_ip
export FW2_heartbeat_ip
export manage_ip
 
server_type_prefix=`echo $server_level|cut -c 1-7`

case $server_type_prefix in
"CServer")
   wget -N http://$tftp_server_ip/yum_repo/images/os/CServer/resource/cserver.sh
   chmod +x *.sh
   sh cserver.sh
   ;;
"Firewal")
   wget -N http://$tftp_server_ip/yum_repo/images/os/Firewall/resource/fwbasicconfig.sh
   chmod +x *.sh
   sh fwbasicconfig.sh CCP Firewall$servernum
   ;;
*)
   echo "You input is error"
   exit 1
   ;;
esac

wget http://$tftp_server_ip/yum_repo/images/os/CServer/resource/status-notify.py
chmod a+x status-notify.py
#python status-notify.py $tftp_server_ip $mac &>/var/log/master_notify.log & 

chkconfig sendmail off
