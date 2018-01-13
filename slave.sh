#!/bin/sh

cf_server_ip='192.168.10.100'

wget http://$cf_server_ip/yum_repo/images/utils/scripts/getParam.py
chmod a+x getParam.py

mac=`ifconfig eth0|grep HWaddr|awk '{print $5}'`
server=`python getParam.py $mac '' name |cut -c 1-7`

if [ 1$server = 1 ];then
   mac=`ifconfig eth2|grep HWaddr|awk '{print $5}'`
   server=`python getParam.py $mac '' name |cut -c 1-7`
fi

export mac

echo "Get Manager network information.........."

mgr_ip=`python getParam.py $mac '' mgr_ip`
netmask=`python getParam.py $mac '' netmask`
gateway=`python getParam.py $mac '' gateway`


#Change root password
ssh_user=`python getParam.py $mac '' ssh_user`
ssh_password=`python getParam.py $mac '' ssh_password`
#echo -e "$ssh_password"\n"$ssh_password" | (passwd --stdin $ssh_user)

san_storage_ip=`python getParam.py $mac '' san_ip`

if [ $san_storage_ip != "" ]
then

san_target_iqn=`python getParam.py $mac '' san_target`
san_user=`python getParam.py $mac '' san_user`
san_password=`python getParam.py $mac '' san_password`

echo "Change iscsid setting.........."

sed -i 's/#node.session.auth.authmethod = CHAP/node.session.auth.authmethod = CHAP/g' /etc/iscsi/iscsid.conf
sed -i "s/#node.session.auth.username = username/node.session.auth.username = $san_user/g" /etc/iscsi/iscsid.conf
sed -i "s/#node.session.auth.password = password/node.session.auth.password = $san_password/g" /etc/iscsi/iscsid.conf

#service iscsid restart

fi

tftp_server=$cf_server_ip

master_ip=''
master_user=''
master_password=''

cluster_id=`python getParam.py $mac '' cluster_id`
MAC_LIST=`python getParam.py '' $cluster_id macaddress`
MASTER_TYPE="master"

for macaddr in $(echo $MAC_LIST | awk '{print;}')
do
       typename=`python getParam.py $macaddr '' server_level`
       if [ $typename = $MASTER_TYPE ]
       then
          master_ip=`python getParam.py $macaddr '' mgr_ip`
          master_user=`python getParam.py $macaddr '' ssh_user`
          master_password=`python getParam.py $macaddr '' ssh_password`
          break
       fi
done

wget http://$tftp_server/yum_repo/images/os/XenServer/scripts/status-notify.py
chmod a+x status-notify.py
python status-notify.py $tftp_server $mac & 

echo "Send finished notificaton to Cloudfactory agent.........."

wget http://$tftp_server/yum_repo/images/os/XenServer/scripts/join-rs-pool.sh
chmod a+x join-rs-pool.sh
sh join-rs-pool.sh $master_ip $master_user $master_password $mgr_ip $netmask $gateway &>/var/log/join-rs.log &

line_num=`awk "/slave.sh/{print NR;exit}" /etc/rc.d/rc.local`
line_num=$(($line_num-1)) 
i=0
while [ $i -lt 3 ]
do
   sed -i "$line_num d" /etc/rc.d/rc.local
   i=$(($i+1))
done


