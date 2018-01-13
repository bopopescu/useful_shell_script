#!/bin/sh

ip=$1
user=$2
password=$3

install_uuid=$4
role=$5

mac_list=`/usr/bin/sshpass -p $password ssh -o ConnectTimeout=90 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=quiet $user@$ip racadm getsysinfo|grep -E "NIC.* Ethernet"|awk '{print $4}'|grep -v "N/A"`

if [ $? -eq 0 ]
then
    if [ ! -d $install_uuid ]
    then
       mkdir $install_uuid $install_uuid/server_mac $install_uuid/log

       touch $install_uuid/server_mac/$role
    fi 

    for mac in $(echo $mac_list|awk '{print;}')
    do
        echo $mac >> "$install_uuid/server_mac/$role"
    done 
else 
    exit $?
fi 
