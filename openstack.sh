#!/bin/bash

TFTP_SERVER="10.86.11.161"

wget http://$TFTP_SERVER/yum_repo/images/os/openstack/script/common.inc
chmod a+x common.inc

source common.inc

#server_level=`python getParam.py $mac '' server_level`

#cluster_id=`python getParam.py $mac '' cluster_id`
#SERVER_MAC_LIST=`python getParam.py '' $cluster_id  macaddress`

#for MAC in $(echo $SERVER_MAC_LIST|awk '{print;}')
#do
#    MGR_IP=`python getParam.py $MAC '' mgr_ip`
#    SERVER_LEVEL=`python getParam.py $MAC '' server_level`
#    sed -i "$ a $MGR_IP $SERVER_LEVEL" /etc/hosts
#done

sed -i "/127.0.0.1/d" /etc/hosts

# For testing
sed -i "$ a 10.86.11.171 controller" /etc/hosts
sed -i "$ a 10.86.11.172 network" /etc/hosts
sed -i "$ a 10.86.11.173 compute" /etc/hosts
sed -i "$ a 10.86.11.174 cinder" /etc/hosts
sed -i "$ a 10.86.11.175 swift" /etc/hosts
# end

# For testing
if [ $mac = "c6:2d:59:aa:ec:a1" ]
then
   server_level="controller"

elif [ $mac = "5e:50:d2:f4:2c:c7" ]
then
   server_level="network"

elif [ $mac = "f6:c9:dc:eb:f0:8e" ]
then
   server_level="compute"

elif [ $mac = "7e:8b:62:af:6e:7e" ]
then
   server_level="cinder"

elif [ $mac = "d6:90:60:c9:7f:9c" ]
then
   server_level="swift"
fi 
# end

echo "Server type is: $server_level"

case $server_level in
"controller")
   wget http://$TFTP_SERVER/yum_repo/images/os/openstack/script/controller.sh
   chmod a+x controller.sh
   source controller.sh
   ;;
"network")
   wget http://$TFTP_SERVER/yum_repo/images/os/openstack/script/network.sh
   chmod a+x network.sh
   source network.sh
   ;;
"compute")
   wget http://$TFTP_SERVER/yum_repo/images/os/openstack/script/compute.sh
   chmod a+x compute.sh
   source compute.sh
   ;;
"cinder")
   wget http://$TFTP_SERVER/yum_repo/images/os/openstack/script/cinder.sh
   chmod a+x cinder.sh
   source cinder.sh
   ;;
"swift")
   wget http://$TFTP_SERVER/yum_repo/images/os/openstack/script/swift.sh
   chmod a+x swift.sh
   source swift.sh
   ;;
*)
   echo "Error server type"
   exit 1
   ;;
esac

apt-get -y install vim &>/dev/null
