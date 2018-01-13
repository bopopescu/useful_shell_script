#!/bin/sh

yum -y update

#Install vdsm and ovirt-shell
yum -y install ovirt-host-* 
yum -y install ovirt-engine-cli 

vdsm-tool configure --force
rm -f /etc/libvirt/libvirtd.conf
cd /etc/libvirt
wget http://$tftp_server/yum_repo/images/packages/oVirt/libvirtd.conf
cd -

#Modify iptables for compute node
cd /etc/sysconfig
rm -f iptables
wget http://$tftp_server/yum_repo/images/packages/oVirt/host-iptables
echo 'Get host-iptables from tftp server..............'
mv host-iptables iptables
cd -

chkconfig iptables on
service iptables restart
service vdsmd start
service vdsmd restart

sed -i "/ifup em1/d" /etc/rc.d/rc.local
sed -i "/install_ovirt/d" /etc/rc.d/rc.local
sed -i '$ a ifup ovirtmgmt' /etc/rc.d/rc.local

#Try to register itself on every startup
sed -i '$ a sh /install_scripts/ovirt_host_registration.sh > /var/log/ovirt_registration.log' /etc/rc.d/rc.local

#Register node to ovirt engine
sh /install_scripts/ovirt_host_registration.sh

wget http://$tftp_server/yum_repo/images/utils/scripts/status-notify.py
chmod a+x status-notify.py
python status-notify.py $cf_server $mac 

echo "Installation completed for ovirt-host!"
