#!/bin/sh

#***************************Config network bridge for oVirt start*******************************
cd /etc/sysconfig/network-scripts

if [ ! -f ifcfg-ovirtmgmt ]; then

touch ifcfg-ovirtmgmt

cat >> ifcfg-ovirtmgmt << BRG
DEVICE=ovirtmgmt
ONBOOT=yes
TYPE=Bridge
DELAY=0
BOOTPROTO=dhcp
BRG

rm -f ifcfg-em1
touch ifcfg-em1

cat >> ifcfg-em1 << BIF
DEVICE=em1
ONBOOT=yes
BRIDGE=ovirtmgmt
NM_CONTROLLED=no
STP=no
BIF

service network restart

fi

cd -

#***************************Config network bridge for oVirt end*******************************

mac=`ifconfig ovirtmgmt|grep HWaddr|awk '{print $5}'`
export mac

cf_server='192.168.10.100'
export cf_server

cd /install_scripts

wget http://$cf_server/yum_repo/images/utils/scripts/getParam.py
chmod a+x getParam.py

tftp_server=$cf_server
export tftp_server

server_name=`python getParam.py $mac '' name`
export server_name

server_ip=`ifconfig ovirtmgmt|grep Bcast|awk '{print $2}'|cut -c 6-`

sed -i "$ a $server_ip $server_name" /etc/hosts
sed -i "$ a $server_ip $server_name.org" /etc/hosts
sed -i "$ a $cf_server tftp_server" /etc/hosts


#***************************Install extra packages for oVirt start*******************************
cd /etc/yum.repos.d
rm -f *
wget -r -nd --no-parent http://$tftp_server/yum_repo/images/packages/oVirt/repo/ -A repo
cd -

mkdir /glusterfs
cd /glusterfs

wget -r --no-parent http://$tftp_server/yum_repo/images/packages/oVirt/download.gluster.org/pub/gluster/glusterfs/LATEST/EPEL.repo/epel-6/x86_64/ -nd -A rpm

yum -y localinstall glusterfs-libs-3.5.1-1.el6.x86_64.rpm
yum -y localinstall glusterfs-3.5.1-1.el6.x86_64.rpm
yum -y localinstall glusterfs-api-3.5.1-1.el6.x86_64.rpm
yum -y localinstall glusterfs-cli-3.5.1-1.el6.x86_64.rpm
yum -y localinstall glusterfs-fuse-3.5.1-1.el6.x86_64.rpm
yum -y localinstall glusterfs-rdma-3.5.1-1.el6.x86_64.rpm

cd -

mkdir /extra
cd /extra
wget -r --no-parent http://$tftp_server/yum_repo/images/packages/oVirt/extra/ -nd -A rpm
flist=`ls -l|awk 'NR>1{print $9}'`

for f in $flist
do
   yum -y localinstall $f
done
yum -y localinstall novnc-0.4-2.el6.noarch.rpm
yum -y localinstall python-daemon-1.5.2-1.el6.noarch.rpm
cd -

#****************************Install extra packages for oVirt end*******************************

wget http://$tftp_server/yum_repo/images/packages/common/sshpass-1.05-1.el6.x86_64.rpm
rpm -ivh sshpass-1.05-1.el6.x86_64.rpm

server_level=`python getParam.py $mac '' server_level`

#For testing
#server_level="ovirt-all"

echo 'Server type:'$server_level

case $server_level in
     "ovirt-all")   
          echo "Execute install_ovirt_allinone.sh" 
          sh /install_scripts/install_ovirt_allinone.sh &> /var/log/ovirt_install.log &
          ;;
     "ovirt-engine")   
          echo "Execute install_ovirt_engine.sh" 
          sh /install_scripts/install_ovirt_engine.sh &> /var/log/ovirt_install.log &
          ;;
     "ovirt-host")  
          echo "Execute install_ovirt_host.sh" 
          sh /install_scripts/install_ovirt_host.sh &> /var/log/ovirt_install.log &
          ;;
     *)
          echo "Invalid server type, exit installer"
          exit
          ;;
    esac
