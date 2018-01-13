#!/bin/sh

yum -y update

#Install ovirt engine
yum -y install ovirt-engine

wget http://$tftp_server/yum_repo/images/packages/oVirt/answer-ovirt-engine.conf

sed -i "s/fqdn=str:cls-master.org/fqdn=str:$server_name.org/g" answer-ovirt-engine.conf
engine-setup --config-append=answer-ovirt-engine.conf

#Modify iptables to allow access to portals
cd /etc/sysconfig
rm -f iptables
wget http://$tftp_server/yum_repo/images/packages/oVirt/engine-iptables
echo 'Get engine-iptables from tftp server..............'
mv engine-iptables iptables
cd -

chkconfig iptables on
service iptables restart

chkconfig libvirtd on
service libvirtd start

host_ip=`python getParam.py $mac '' mgr_ip`
ssh_port=22
ssh_user=`python getParam.py $mac '' ssh_user`
ssh_password=`python getParam.py $mac '' ssh_password`
idrac_ip=`python getParam.py $mac '' idrac_ip`
idrac_user=`python getParam.py $mac '' idrac_user`
idrac_password=`python getParam.py $mac '' idrac_password`
#nfs_storage_ip=`python getParam.py $mac '' nfs_storage_ip`
#nfs_storage_path=`python getParam.py $mac '' nfs_storage_path`


#Add NFS storage of type data and iso to "Default" data center 
rm -f ~/ca.crt
wget http://$host_ip/ca.crt -O ~/ca.crt

rm -f ~/register_host.cmd
touch ~/register_host.cmd

echo "add host --address $host_ip --name $server_name --ssh-port $ssh_port --ssh-user-user_name $ssh_user --ssh-user-password $ssh_password --ssh-authentication_method --power_management-enabled true --power_management-type drac7 --power_management-address $idrac_ip --power_management-username $idrac_user --power_management-password $idrac_password" > ~/register_host.cmd

echo "exit" >> ~/register_host.cmd

sshpass -p123456 ovirt-shell -I -c -A ~/ca.crt -l "https://$host_ip:443/api" -u admin@internal -f ~/register_host.cmd 2> /var/log/ovirt_err.log 

sleep 300

rm -f ~/register_host.cmd
touch ~/register_host.cmd

#echo "add storagedomain --name nfs --host-name $server_name --type data --storage-type nfs --storage_format  v3 --storage-address $nfs_storage_ip --storage-path $nfs_storage_path" > ~/register_host.cmd

#echo "add storagedomain --name nfs --datacenter-identifier Default" >> ~/register_host.cmd

echo "add storagedomain --name ISO_DOMAIN --datacenter-identifier Default" >> ~/register_host.cmd

echo "exit" >> ~/register_host.cmd

sshpass -p123456 ovirt-shell -I -c -A ~/ca.crt -l "https://$host_ip:443/api" -u admin@internal -f ~/register_host.cmd 2> /var/log/ovirt_err.log 

wget http://$tftp_server/yum_repo/images/utils/scripts/status-notify.py
chmod a+x status-notify.py
python status-notify.py $cf_server $mac 


#Update scripts to run on system boot
sed -i "/ifup em1/d" /etc/rc.d/rc.local
sed -i "/install_ovirt/d" /etc/rc.d/rc.local
sed -i '$ a ifup ovirtmgmt' /etc/rc.d/rc.local

echo "Installation completed for ovirt-engine!"
