#!/bin/sh

task_uuid=`python getParam.py $mac '' task_uuid`
san_storage_ip=`python getParam.py '' $task_uuid san_ip`
san_target_iqn=`python getParam.py '' $task_uuid san_target`
san_user=`python getParam.py '' $task_uuid san_user`
san_password=`python getParam.py '' $task_uuid san_password`

sed -i 's/#node.session.auth.authmethod = CHAP/node.session.auth.authmethod = CHAP/g' /etc/iscsi/iscsid.conf
sed -i "s/#node.session.auth.username = username/node.session.auth.username = $san_user/g" /etc/iscsi/iscsid.conf
sed -i "s/#node.session.auth.password = password/node.session.auth.password = $san_password/g" /etc/iscsi/iscsid.conf

service iscsid restart

xe sr-create name-label=SAN content-type=user device-config-target=$san_storage_ip device-config-targetIQN=$san_target_iqn type=lvmoiscsi shared=true 1 2> 1.txt

line_num=`cat 1.txt|awk '/<SCSIid>/{print NR;}'`
line_num=$(($line_num+1))

scsi_id=`cat 1.txt|awk "NR==$line_num{print $1;}"|sed -e 's/^[ \t]*//'`

line_num=`cat 1.txt|awk '/<LUNid>/{print NR;}'`
line_num=$(($line_num+1))

lun_id=`cat 1.txt|awk "NR==$line_num{print $1;}"|sed -e 's/^[ \t]*//'`

xe sr-create name-label=SAN content-type=user device-config-target=$san_storage_ip device-config-targetIQN=$san_target_iqn  device-config:SCSIid=$scsi_id device-config-LUNid=$lun_id type=lvmoiscsi shared=true

#xe sr-create type=nfs name-label="$poolUUID" device-config:server=$nfs_storage_ip device-config:serverpath=/kickstart

if [ ! $? -eq 0 ]
then
   echo "Add SAN storage failed"
   exit
fi
