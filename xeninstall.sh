#!/bin/bash
export PATH=$PATH:/sbin:/usr/local/bin:/usr/local/sbin
#yum -y update
#yum -y install SDL bridge-utils cyrus-sasl-md5 e4fsprogs-libs ebtables xz xz-libs cyrus-sasl cyrus-sasl-lib cyrus-sasl-lib cyrus-sasl-plain cyrus-sasl-plain PyXML libGL.so.1 xen-hypervisor-abi libXxf86vm libdrm mesa-libGL sharutils expect expect-devel 
cd /etc/yum.repos.d
mv * /home
wget http://$tftp_server_ip/yum_repo/images/packages/centos-5-10/repo/CentOS-Base.repo
cp /resource/GITCO-XEN3.4.4_x86_64.repo /etc/yum.repos.d/

echo 'start updating system'
yum -y update
echo 'finish updating system'

yum -y install SDL bridge-utils cyrus-sasl-md5 e4fsprogs-libs ebtables xz xz-libs cyrus-sasl cyrus-sasl-lib cyrus-sasl-lib cyrus-sasl-plain cyrus-sasl-plain PyXML libGL.so.1 xen-hypervisor-abi libXxf86vm libdrm mesa-libGL sharutils expect expect-devel 

yum -y install xen libvirt
mv /home/CentOS-* .
rm -f CentOS-Base.repo
wget http://$tftp_server_ip/yum_repo/images/packages/centos-5-10/repo/CentOS-Base.repo

sed -i 's/default=1/default=0/g' /boot/grub/grub.conf
sed -i 's/xen.gz-3.4.4/xen.gz-3.4.4 dom0_mem=4096m/g' /boot/grub/grub.conf
cd /etc/xen/
mv xend-config.sxp xend-config.sxp.bck
#wget -N http://icp.s.mygrid.asia/xen3.4.3/xend-config.sxp
wget -N http://$tftp_server_ip/yum_repo/images/os/CServer/resource/xend-config.sxp



