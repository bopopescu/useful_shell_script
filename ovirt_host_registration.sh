#!/bin/sh

cf_server='192.168.10.100'

wget http://$cf_server/yum_repo/images/utils/scripts/getParam.py
chmod a+x getParam.py

mac=`ifconfig ovirtmgmt|grep HWaddr|awk '{print $5}'`
tftp_server=$cf_server
CLUSTER_ID=`python getParam.py $mac '' cluster_id`
MAC_LIST=`python getParam.py '' $CLUSTER_ID macaddress`
SERVER_TYPE="ovirt-engine"

#Get IP for server with role "ovirt-engine"
for macaddr in $(echo $MAC_LIST | awk '{print;}')
do
       typename=`python getParam.py $macaddr '' server_level`
       if [ $typename = $SERVER_TYPE ];then
          engine_ip=`python getParam.py $macaddr '' mgr_ip`
          break
       fi
done

host_ip=`python getParam.py $mac '' mgr_ip`
ssh_port=22
ssh_user='root'
ssh_password='asd123'
idrac_ip=`python getParam.py $mac '' idrac_ip`
idrac_user=`python getParam.py $mac '' idrac_user`
idrac_password=`python getParam.py $mac '' idrac_password`
server_name=`python getParam.py $mac '' name`

rm -f ~/ca.crt
wget http://$engine_ip/ca.crt -O ~/ca.crt

rm -f ~/register_host.cmd
touch ~/register_host.cmd

#Register node to ovirt engine
echo "add host --address $host_ip --name $server_name --ssh-port $ssh_port --ssh-user-user_name $ssh_user --ssh-user-password $ssh_password --ssh-authentication_method --power_management-enabled true --power_management-type drac7 --power_management-address $idrac_ip --power_management-username $idrac_user --power_management-password $idrac_password" > ~/register_host.cmd

echo "exit" >> ~/register_host.cmd

sleep 300

sshpass -p123456 ovirt-shell -I -c -A ~/ca.crt -l "https://$engine_ip:443/api" -u admin@internal -f ~/register_host.cmd &
