#!/bin/sh 
mkdir /install_scripts
cd /install_scripts

wget http://192.168.10.100/yum_repo/utils/config/cf.ini

section="cloudfactory"
key="ip"

cf_server=`cat /install_scripts/cf.ini | awk 'BEGIN{FS="=";OFS=":";}/\['$section'\]/,/\[.*[^('$section')].*\]/{gsub(/[[:blank:]]*/,"",$1);if(NF==2 && $1=="'$key'"){gsub(/^[[:blank:]]*/,"",$2);gsub(/[[:blank:]]*$/,"",$2);print $2;}}'`

wget http://$cf_server/yum_repo/images/utils/scripts/getParam.py
chmod a+x getParam.py

mac=`ifconfig eth0|grep HWaddr|awk '{print $5}'`
server=`python getParam.py $mac '' name |cut -c 1-7`
#tftp_server=`python getParam.py $mac '' tftp_ip`

if [ 1$server = 1 ];then
   mac=`ifconfig eth2|grep HWaddr|awk '{print $5}'`
   server=`python getParam.py $mac '' name |cut -c 1-7`
fi

#server_id=`python getParam.py $mac '' id`

#python preinstall-agent.py $server_id >/dev/null 2>&1 < /dev/null &

#echo 'preinstall-agent.py is running..................................'

wget http://$cf_server/yum_repo/images/os/XenServer/scripts/raid-init.sh
chmod a+x raid-init.sh
sh raid-init.sh

if [ ! -b /dev/sda ];
then
   reboot 
fi

cd -

echo 'exit installation-start script..................................'
