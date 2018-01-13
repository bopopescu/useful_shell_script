#!/bin/sh

mac=`ifconfig eth0|grep HWaddr|awk '{print $5}'`
server=`python getParam.py $mac '' name |cut -c 1-7`

if [ 1$server = 1 ];then
   mac=`ifconfig eth2|grep HWaddr|awk '{print $5}'`
   server=`python getParam.py $mac '' name |cut -c 1-7`
fi

export mac

cf_server_ip='192.168.10.100'

wget http://$cf_server_ip/yum_repo/images/utils/scripts/getParam.py
chmod a+x getParam.py

tftp_server_ip=$cf_server_ip
export tftp_server_ip

#Change root password
ssh_user=`python getParam.py $mac '' ssh_user`
ssh_password=`python getParam.py $mac '' ssh_password`
echo "echo -e "$ssh_password"\n"$ssh_password" | (passwd --stdin $ssh_user)"

echo "Get Manager network information.........."

mgr_ip=`python getParam.py $mac '' mgr_ip`
install_ip=`python getParam.py $mac '' install_ip`
netmask=`python getParam.py $mac '' netmask`
gateway=`python getParam.py $mac '' gateway`

wget http://$tftp_server_ip/yum_repo/images/os/XenServer/scripts/create-rs-pool.sh
chmod a+x create-rs-pool.sh
sh create-rs-pool.sh

echo "Create resource pool.........."

task_uuid=`python getParam.py $mac '' task_uuid`
san_ip=`python getParam.py '' $task_uuid san_ip`
cluster_id=`python getParam.py $mac '' cluster_id`
server_count=`python getParam.py '' $cluster_id macaddress|wc -l`

if [ $san_ip != "" ]
then
   wget http://$tftp_server_ip/yum_repo/images/os/XenServer/scripts/add-pool-storage.sh
   chmod a+x add-pool-storage.sh
   #sh add-pool-storage.sh

   echo "Add SAN storage.........."
fi

wget http://$tftp_server_ip/yum_repo/images/os/XenServer/scripts/status-notify.py
chmod a+x status-notify.py

line_num=`awk "/master.sh/{print NR;exit}" /etc/rc.d/rc.local`
line_num=$(($line_num-1)) 
i=0
while [ $i -lt 3 ]
do
   sed -i "$line_num d" /etc/rc.d/rc.local
   i=$(($i+1))
done

echo "Configure network............."

host_uuid=`xe host-list|awk 'NR==1{print $5}'`

eth0_pif=`xe pif-list device=eth0 host-uuid=$host_uuid|awk 'NR==1{print $5}'`
eth1_pif=`xe pif-list device=eth1 host-uuid=$host_uuid|awk 'NR==1{print $5}'`
eth2_pif=`xe pif-list device=eth2 host-uuid=$host_uuid|awk 'NR==1{print $5}'`
eth3_pif=`xe pif-list device=eth3 host-uuid=$host_uuid|awk 'NR==1{print $5}'`

xe host-param-set name-label=master-$mgr_ip uuid=$host_uuid
xe host-management-reconfigure pif-uuid=$eth0_pif

xe pif-reconfigure-ip uuid=$eth0_pif mode=static IP=$mgr_ip netmask=$netmask gateway=$gateway

server_joined=`xe host-list|grep uuid|wc -l`

while [ ! $server_joined -eq $server_count ]
do
   sleep 10
   server_joined=`xe host-list|grep uuid|wc -l`
   echo 'Host number is: '$server_joined
done

#xe pif-reconfigure-ip uuid=$eth0_pif mode=static IP=$install_ip netmask=255.255.255.0
ifconfig xenbr0 $install_ip/24 up

sleep 30

echo "Send finished notificaton to Cloudfactory agent.........."
python status-notify.py $cf_server_ip $mac &>/var/log/master_notify.log & 

sleep 30

ifconfig xenbr0 $mgr_ip/24 up
xe pif-reconfigure-ip uuid=$eth0_pif mode=static IP=$mgr_ip netmask=$netmask gateway=$gateway

route add default gw $gateway
 
bond02_uuid=`xe network-create name-label=bond02`
bond13_uuid=`xe network-create name-label=bond13`

host_uuids=`xe host-list|grep uuid|awk '{print $5}'`

for host_uuid in $(echo $host_uuids | awk '{print;}')
do
    #host_name=`xe host-param-get param-name=name-label uuid=$host_uuid`
    
    host_eth0_pif=`xe pif-list host-uuid=$host_uuid device=eth0|grep -E '^uuid'|awk '{print $5}'`
    host_eth2_pif=`xe pif-list host-uuid=$host_uuid device=eth2|grep -E '^uuid'|awk '{print $5}'`
    
    xe bond-create network-uuid=$bond02_uuid pif-uuids=$host_eth0_pif,$host_eth2_pif mode=lacp 

    host_eth1_pif=`xe pif-list host-uuid=$host_uuid device=eth1|grep -E '^uuid'|awk '{print $5}'`
    host_eth3_pif=`xe pif-list host-uuid=$host_uuid device=eth3|grep -E '^uuid'|awk '{print $5}'`
    
    xe bond-create network-uuid=$bond13_uuid pif-uuids=$host_eth1_pif,$host_eth3_pif mode=lacp
done


