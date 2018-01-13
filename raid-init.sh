#!/bin/sh -x

section="cloudfactory"
key="ip"

cf_server_ip=`cat /install_scripts/cf.ini | awk 'BEGIN{FS="=";OFS=":";}/\['$section'\]/,/\[.*[^('$section')].*\]/{gsub(/[[:blank:]]*/,"",$1);if(NF==2 && $1=="'$key'"){gsub(/^[[:blank:]]*/,"",$2);gsub(/[[:blank:]]*$/,"",$2);print $2;}}'`

wget http://$cf_server_ip/yum_repo/images/utils/scripts/getParam.py
chmod a+x getParam.py

mac=`ifconfig eth0|grep HWaddr|awk '{print $5}'`
server=`python getParam.py $mac '' name |cut -c 1-7`

if [ 1$server = 1 ];then
   mac=`ifconfig eth2|grep HWaddr|awk '{print $5}'`
   server=`python getParam.py $mac '' name |cut -c 1-7`
fi

#tftp_server=`python getParam.py $mac '' tftp_ip`
#yum_repo_root=$tftp_server"/yum_repo/images/os"

cd /resource 

wget  http://$cf_server_ip/yum_repo/images/os/XenServer/MegaCli
chmod a+x MegaCli

dev_slot_list=`./MegaCli -PDList -aALL|egrep 'Enclosure Device ID|Slot Number'|awk 'NR%2==0{print $3};NR%2!=0{print $4;}'`

sdaslots="["
sdbslots="["

index=1

for num in $(echo $dev_slot_list|awk '{print;}')
do
   if (($index%2 != 0))
   then
       if (($index < 5)) 
       then
          sdaslots="$sdaslots""$num"":"
       else
          sdbslots="$sdbslots""$num"":"
       fi 
   else
       if (($index < 6))
       then
          sdaslots="$sdaslots""$num"","
       else
          sdbslots="$sdbslots""$num"","
       fi 
   fi 
   index=$(($index+1))
done

sdaslots=`echo $sdaslots|sed 's/,$/]/'`
sdbslots=`echo $sdbslots|sed 's/,$/]/'`

./MegaCli -CfgLdAdd -r1 "$sdaslots" WB Direct -a0
./MegaCli -CfgLdAdd -r5 "$sdbslots" WB Direct -a0

cd -
