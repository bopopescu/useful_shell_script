#!/bin/sh

cd /resource 

#tftp_server_ip="10.1.1.101"
tftp_server_ip="10.86.11.161"

mkdir -p lib64
chmod a+r lib64
cd lib64
wget  http://$tftp_server_ip/yum_repo/images/os/cserver/libs/libm.so.6
chmod a+x libm.so.6 
wget  http://$tftp_server_ip/yum_repo/images/os/cserver/libs/libcrypto.so.6 
chmod a+x libcrypto.so.6
wget  http://$tftp_server_ip/yum_repo/images/os/cserver/libs/libc.so.6
chmod a+x libc.so.6
wget  http://$tftp_server_ip/yum_repo/images/os/cserver/libs/ld-linux.so.2
chmod a+x ld-linux.so.2
wget  http://$tftp_server_ip/yum_repo/images/os/cserver/libs/libdl.so.2
chmod a+x libdl.so.2
wget  http://$tftp_server_ip/yum_repo/images/os/cserver/libs/libz.so.1
chmod a+x libz.so.1
wget  http://$tftp_server_ip/yum_repo/images/os/cserver/libs/libpthread.so.0
chmod a+x libpthread.so.0
wget  http://$tftp_server_ip/yum_repo/images/os/cserver/libs/libgcc_s.so.1
chmod a+x libgcc_s.so.1
cd -

wget  http://$tftp_server_ip/yum_repo/images/os/cserver/libs/libsysfs.so.2.0.1
chmod a+x libsysfs.so.2.0.1

wget  http://$tftp_server_ip/yum_repo/images/os/cserver/libs/libsysfs.so.2.0.2
chmod a+x libsysfs.so.2.0.2
 
mkdir -p usr/lib64
chmod a+r usr/lib64
cd usr/lib64
wget  http://$tftp_server_ip/yum_repo/images/os/cserver/libs/libreadline.so.5
chmod a+x libreadline.so.5
wget  http://$tftp_server_ip/yum_repo/images/os/cserver/libs/libncurses.so.5
chmod a+x libncurses.so.5
wget  http://$tftp_server_ip/yum_repo/images/os/cserver/libs/libstdc++.so.6
chmod a+x libstdc++.so.6
wget  http://$tftp_server_ip/yum_repo/images/os/cserver/libs/libsysfs.so.2.0.1
chmod a+x libsysfs.so.2.0.1
cd -

wget  http://$tftp_server_ip/yum_repo/images/os/cserver/resource/MegaRAID/MegaCli64
chmod a+x MegaCli64

./MegaCli64 -CfgLdDel -LALL -aALL

dev_slot_list=`./MegaCli64 -PDList -aALL|egrep 'Enclosure Device ID|Slot Number'|awk 'NR%2==0{print $3};NR%2!=0{print $4;}'`

sdaslots="["
sdbslots="["

array0="["
array1="["
array2="["

index=1

for num in $(echo $dev_slot_list|awk '{print;}')
do
#   if (($index%2 != 0))
#   then
#       if (($index < 5)) 
#       then
#          sdaslots="$sdaslots""$num"":"
#       else
#          sdbslots="$sdbslots""$num"":"
#       fi 
#   else
#       if (($index < 6))
#       then
#          sdaslots="$sdaslots""$num"","
#       else
#          sdbslots="$sdbslots""$num"","
#       fi 
#   fi 
#   index=$(($index+1))

   # For raid 5
   if (($index%2 != 0))
   then
        #if (($index < 5))
        #then
           sdaslots="$sdaslots""$num"":"
        #fi
   else
        #if (($index < 6))
        #then
           sdaslots="$sdaslots""$num"","
        #fi
   fi 

   # For raid 10
   if (($index%2 != 0))
   then
        if (($index < 5))
        then
           array0="$array0""$num"":"
        elif (($index < 9))
        then
           array1="$array1""$num"":"
        elif (($index < 12))
        then
           array2="$array2""$num"":"
        fi
   else
        if (($index < 6))
        then
           array0="$array0""$num"","
        elif (($index < 10))
        then
           array1="$array1""$num"","
        elif (($index < 13))
           array2="$array2""$num"","
        then
        fi
   fi
       
   index=$(($index+1))
done

sdaslots=`echo ${sdaslots%?}`
sdaslots=$sdaslots"]"
array0=`echo ${array0%?}`
array1=`echo ${array1%?}`
array0=$array0"]"
array1=$array1"]"

echo "*******************"
echo "dev_slot_list: "$dev_slot_list
echo "sdaslots: "$sdaslots
echo "sdbslots: "$sdbslots
echo "array0: "$array0
echo "array1: "$array1
echo "*******************"

#sdaslots=`echo $sdaslots|sed 's/,$/]/'`
#sdbslots=`echo $sdbslots|sed 's/,$/]/'`

#./MegaCli64 -CfgLdAdd -r1 "$sdaslots" WB Direct -a0
#./MegaCli64 -CfgLdAdd -r5 "$sdbslots" WB Direct -a0

echo "./MegaCli64 -CfgLdAdd -r5 "$sdaslots" WB RA Direct CachedBadBBU -sz500GB -a0"
./MegaCli64 -CfgLdAdd -r5 "$sdaslots" WB RA Direct CachedBadBBU -sz500GB -a0 
#./MegaCli64 -CfgSpanAdd -r10 -Array0"$array0" -Array1"$array1" -Array2"$array2" WB RA Direct CachedBadBBU -sz500GB -a0

cd -
