#!/bin/sh

if [ ! $# -eq 3 ]
then
    echo "3 arguments needed!"
    exit 1
fi

datastore=""

if [ -d /vmfs/volumes/datastore1 ]
then
  datastore="datastore1"
  cd /vmfs/volumes/datastore1
elif [ -d /vmfs/volumes/datastore2 ]
then
  datastore="datastore2"
  cd /vmfs/volumes/datastore2
fi

wget http://$cf_agent_ip/yum_repo/images/os/vSphere/vmware-ovftool.tar.gz

tar zxvf vmware-ovftool.tar.gz

cd vmware-ovftool

wget http://$cf_agent_ip/yum_repo/images/packages/vSphere/vcenter_server.ovf
wget http://$cf_agent_ip/yum_repo/images/packages/vSphere/vcenter_server-disk1.vmdk
wget http://$cf_agent_ip/yum_repo/images/packages/vSphere/vcenter_server-disk2.vmdk

chmod a+x ovftool

#Import VCSA
./ovftool -dm=thin --disableVerification  --noSSLVerify --datastore=$datastore --name=vcenter_server  vcenter_server.ovf "vi://root:powerall@localhost" 

#Configure vCenter Server manage network

cluster_ip=$1
cluster_netmask=$2
cluster_gateway=$3

echo "Cluster IP: "$cluster_ip
echo "Cluster NETMASK: "$cluster_netmask
echo "Cluster GATEWAY: "$cluster_gateway

echo guestinfo.mgr_ip = "$cluster_ip" >> /vmfs/volumes/$datastore/vcenter_server/vcenter_server.vmx
echo guestinfo.mgr_netmask = "$cluster_netmask" >> /vmfs/volumes/$datastore/vcenter_server/vcenter_server.vmx
echo guestinfo.mgr_gateway = "$cluster_gateway" >> /vmfs/volumes/$datastore/vcenter_server/vcenter_server.vmx

#Power VCSA on
vim-cmd vmsvc/getallvms|grep vcenter_server|awk {'print $1'}|xargs vim-cmd vmsvc/power.on

sleep 10

#Get IP Address of VCSA
vim-cmd vmsvc/getallvms|grep vcenter_server|awk {'print $1'}|xargs vim-cmd vmsvc/get.summary|grep ipAddress|awk '{print $3}'|sed  's/,//g;s/"//g'
