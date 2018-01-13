#!/bin/sh

if [ $# -lt 2 ]
then
   echo "More arguments expected!"
   exit 1
fi

action=$1
macaddress=$2
server_name=$3
fixed_ip=$4
bootfile=$5

dhcp_conf="/etc/dhcpd.conf"

if [ $action = "add" ]
then
    sed -i "$ d" $dhcp_conf
    sed -i "$ d" $dhcp_conf
    
    sed -i "$ a host $server_name"{ $dhcp_conf
    sed -i "$ a hardware ethernet $macaddress;"  $dhcp_conf
    sed -i "$ a fixed-address $fixed_ip;"  $dhcp_conf
    sed -i "$ a filename \"$bootfile\";"  $dhcp_conf
    sed -i "$ a }"  $dhcp_conf
    
    sed -i "$ a }" $dhcp_conf
    sed -i "$ a }" $dhcp_conf
    
    service dhcpd restart
 
    if [ ! $? -eq 0 ]
    then
       line_num=`awk "/$macaddress/{print NR;exit}" $dhcp_conf`
       line_num=$(($line_num-1)) 
       i=0
       while [ $i -lt 5 ]
       do
          sed -i "$line_num d" $dhcp_conf
          i=$(($i+1))
       done
    fi 

elif [ $action = "delete" ]
then
    line_num=`awk "/$macaddress/{print NR;exit}" $dhcp_conf`
    line_num=$(($line_num-1)) 
    i=0
    while [ $i -lt 5 ]
    do
       sed -i "$line_num d" $dhcp_conf
       i=$(($i+1))
    done
  
    service dhcpd restart
    exit $?
else
    echo "Invalid argument: $action"
    exit 1
fi
