#!/bin/sh

if [ ! $# -eq 6 ]
then
    echo '6 arguments needed!'
    exit 1
fi

master_ip=$1
master_user=$2
master_password=$3
mgr_ip=$4
mgr_netmask=$5
mgr_gateway=$6

echo "master ip is: "$master_ip", user name is: "$master_user", master password is: "$master_password

#sleep 60

echo "Configure network............."

eth0_pif=`xe pif-list device=eth0|awk 'NR==1{print $5}'`
eth1_pif=`xe pif-list device=eth1|awk 'NR==1{print $5}'`
eth2_pif=`xe pif-list device=eth2|awk 'NR==1{print $5}'`
eth3_pif=`xe pif-list device=eth3|awk 'NR==1{print $5}'`

xe host-management-reconfigure pif-uuid=$eth0_pif
xe pif-reconfigure-ip uuid=$eth0_pif mode=static IP=$mgr_ip netmask=$mgr_netmask gateway=$mgr_gateway
host_uuid=`xe host-list|awk 'NR==1{print $5}'`
xe host-param-set name-label=slave-$mgr_ip uuid=$host_uuid

route add default gw $mgr_gateway

echo "xe pool-join master-address=$master_ip master-username=$master_user master-password=$master_password"
xe pool-join master-address=$master_ip master-username=$master_user master-password=$master_password
ret=$?

#TRY_TIME=0

while [ ! $ret -eq 0 ]
do
   echo "Join resource pool failed, try again"
   sleep 30
   xe pool-join master-address=$master_ip master-username=$master_user master-password=$master_password
   ret=$?
   #TRY_TIME=$(($TRY_TIME+1))
done
