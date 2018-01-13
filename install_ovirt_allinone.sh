#!/bin/sh

yum -y install --nogpgcheck ovirt-engine-setup-plugin-allinone

wget http://$tftp_server/yum_repo/images/packages/oVirt/answer-ovirt-allinone.conf

sed -i "s/fqdn=str:cls-master.org/fqdn=str:$server_name.org/g" answer-ovirt-allinone.conf

engine-setup --config-append=answer-ovirt-allinone.conf 

host_ip=`python getParam.py $mac '' mgr_ip`

#For testing
host_ip='192.168.10.20'

idrac_ip=`python getParam.py $mac '' idrac_ip`
idrac_user=`python getParam.py $mac '' idrac_user`
idrac_password=`python getParam.py $mac '' idrac_password`
#nfs_storage_ip=`python getParam.py $mac '' nfs_storage_ip`
#nfs_storage_path=`python getParam.py $mac '' nfs_storage_path`

#Add NFS storage of type data and iso to "Default" data center

yum -y install httpd
 
rm -f ~/ca.crt
wget http://$host_ip/ca.crt -O ~/ca.crt

rm -f ~/register_host.cmd
touch ~/register_host.cmd

#echo "update host --name local_host --power_management-enabled true --power_management-type drac7 --power_management-address $idrac_ip --power_management-username $idrac_user --power_management-password $idrac_password" > ~/register_host.cmd

echo "add storagedomain --name iso1 --datacenter-identifier local_datacenter" >> ~/register_host.cmd

echo "exit" >> ~/register_host.cmd

sshpass -p123456 ovirt-shell -I -c -A ~/ca.crt -l "https://$host_ip:443/api" -u admin@internal -f ~/register_host.cmd 2> /var/log/ovirt_err.log 


sed -i "/ifup em1/d" /etc/rc.d/rc.local
sed -i "/install_ovirt/d" /etc/rc.d/rc.local
sed -i '$ a ifup ovirtmgmt' /etc/rc.d/rc.local

echo "Installation oVirt-AllInOne completed"
