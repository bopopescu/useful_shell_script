#!/bin/sh
#Change bios and idrac device settings

tftp_server_ip=$1

mkdir -p lib64
chmod a+r lib64
#cd lib64
wget  http://$tftp_server_ip/yum_repo/images/os/ccp/libs/libm.so.6
chmod a+x libm.so.6 
wget  http://$tftp_server_ip/yum_repo/images/os/ccp/libs/libcrypto.so.6 
chmod a+x libcrypto.so.6
wget  http://$tftp_server_ip/yum_repo/images/os/ccp/libs/libc.so.6
chmod a+x libc.so.6
wget  http://$tftp_server_ip/yum_repo/images/os/ccp/libs/ld-linux.so.2
chmod a+x ld-linux.so.2
wget  http://$tftp_server_ip/yum_repo/images/os/ccp/libs/libdl.so.2
chmod a+x libdl.so.2
wget  http://$tftp_server_ip/yum_repo/images/os/ccp/libs/libz.so.1
chmod a+x libz.so.1
wget  http://$tftp_server_ip/yum_repo/images/os/ccp/libs/ipmi_devintf.ko
chmod a+x ipmi_devintf.ko
wget  http://$tftp_server_ip/yum_repo/images/os/ccp/libs/ipmi_si.ko
chmod a+x ipmi_si.ko
wget  http://$tftp_server_ip/yum_repo/images/os/ccp/libs/ipmi_msghandler.ko
chmod a+x ipmi_msghandler.ko

#cd -
 
mkdir -p usr/lib64
chmod a+r usr/lib64
#cd usr/lib64
wget  http://$tftp_server_ip/yum_repo/images/os/ccp/libs/libreadline.so.5
chmod a+x libreadline.so.5
wget  http://$tftp_server_ip/yum_repo/images/os/ccp/libs/libncurses.so.5
chmod a+x libncurses.so.5
wget  http://$tftp_server_ip/yum_repo/images/os/ccp/libs/ipmi_devintf.ko
chmod a+x ipmi_devintf.ko
wget  http://$tftp_server_ip/yum_repo/images/os/ccp/libs/ipmi_si.ko
chmod a+x ipmi_si.ko
wget  http://$tftp_server_ip/yum_repo/images/os/ccp/libs/ipmi_msghandler.ko
chmod a+x ipmi_msghandler.ko
#cd -

modprobe ipmi_devintf

if [ $? -eq 0 ]
then
   echo "Install module ipmi_devintf success!"
else
   echo "Install module ipmi_devintf failed!"
fi

modprobe ipmi_si

if [ $? -eq 0 ]
then
   echo "Install module ipmi_si success!"
else
   echo "Install module ipmi_si failed!"
fi

/etc/init.d/ipmi start

if [ -c "/dev/ipmi0" ]
then
   echo "/dev/ipmi0 exist!"
else
   echo "/dev/ipmi0 missing, create it manually"
  
   mknod -m 0666 /dev/ipmi0 c 252 0
   if [ $? -eq 0 ]
   then
      echo "create /dev/ipmi0 success"
   else
      echo "create /dev/ipmi0 failed"
   fi
fi

#sleep 10

#setenforce 0
wget  http://$tftp_server_ip/yum_repo/images/os/ccp/ipmitool
chmod a+x ipmitool
#./ipmitool -l lan -U root -P asd123 chassis bootdev disk options=persistent
#./ipmitool -U root -P asd123 chassis bootdev disk options=persistent

