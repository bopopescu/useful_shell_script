for i in 0 1 2 3
do
>/etc/sysconfig/network-scripts/ifcfg-eth$i 
cat >> /etc/sysconfig/network-scripts/ifcfg-eth$i <<IFS
DEVICE=eth$i
USERCTL=no
ONBOOT=yes
MASTER=bond0
SLAVE=yes
BOOTPROTO=none
HWADDR=$(/sbin/ifconfig eth$i|egrep -o "([[:xdigit:]]{2}[:]){5}[[:xdigit:]]{2}") 
IFS
done
   
# Create the bond0 device file.
>/etc/sysconfig/network-scripts/ifcfg-bond0 
cat >> /etc/sysconfig/network-scripts/ifcfg-bond0 <<BOND
DEVICE=bond0
ONBOOT=yes
USERCTL=no
BRIDGE=br0
BOND

cat >> /etc/sysconfig/network-scripts/ifcfg-br0 <<IFS
DEVICE=br0
ONBOOT=yes
BOOTPROTO=none
IPADDR=$private_ip
NETMASK=$private_netmask
NO_ALIASROUTING=yes
TYPE=Bridge
IFS

# RHEL6 uses /etc/modprobe.d directory
if [ -d /etc/modprobe.d ]; then
        BONDCONFIG=/etc/modprobe.d/bonding.conf
else # Assume RHEL5
        BONDCONFIG=/etc/modprove.conf
fi

# Load the bonding kernel module with active-backup mode and set mii link monitoring to 100 ms.
cp /etc/modprobe.conf /tmp/modprobe.conf.bonding
test -f "${BONDCONFIG}" && cp "${BONDCONFIG}" /tmp/modprobe.conf.bonding
cat >> /tmp/modprobe.conf.bonding <<EOF
alias bond0 bonding
options bond0 mode=1 miimon=100
EOF

cat /tmp/modprobe.conf.bonding|uniq > "${BONDCONFIG}"

wget -N http://$tftp_server_ip/yum_repo/images/os/CServer/resource/GITCO-XEN3.4.4_x86_64.repo
wget -N http://$tftp_server_ip/yum_repo/images/os/CServer/resource/xeninstall.sh
wget -N http://$tftp_server_ip/yum_repo/images/os/CServer/resource/basicconfig.sh
wget -N http://$tftp_server_ip/yum_repo/images/os/CServer/resource/ifup-eth
wget -N http://$tftp_server_ip/yum_repo/images/os/CServer/resource/ccp-install.sh
wget -N http://$tftp_server_ip/yum_repo/images/os/CServer/resource/ccpagent-install.sh
wget -N http://$tftp_server_ip/yum_repo/images/os/CServer/v1.5/ccp-v1.5-package.tar.gz
wget -N http://$tftp_server_ip/yum_repo/images/os/CServer/v1.5/ccpagent-1.5-bin.tar.gz
wget -N http://$tftp_server_ip/yum_repo/images/os/CServer/v1.5/ccpagent-post-1.5.tar.gz
wget -N http://$tftp_server_ip/yum_repo/images/os/CServer/v1.5/ccp-zendframework-phpmyadmin-bin.tar.gz
wget -N http://$tftp_server_ip/yum_repo/images/os/CServer/resource/install-tpl.sh
wget -N http://$tftp_server_ip/yum_repo/images/os/CServer/resource/ccp_generic.zl
wget -N http://$tftp_server_ip/yum_repo/images/os/CServer/resource/vmconfig.sh
wget -N http://$tftp_server_ip/yum_repo/images/os/CServer/resource/tserver.cfg
wget -N http://$tftp_server_ip/yum_repo/images/os/CServer/resource/sshpass-1.05.tar.gz

chmod +x *.sh
echo "starting update system and install xen......."

sh xeninstall.sh

echo "finish installing xen!"

echo "start installing ccp!"
sh ccp-install.sh $grid l

echo "start installing ccpagent!"
sh ccpagent-install.sh l $grid $servernum 3.4.4

echo "copy licenses!"
mv ccp_generic.zl /vm/licenses/
sed -i 's/of=$2/of=$2 bs=20M/' /www/production-$grid/$grid.ccp.mygrid.asia/command/md_img_to_vg.sh
sh basicconfig.sh $server_level $grid $private_gateway

cd /vm/bin/

yum install -y sharutils lynx  apr-util

if [ -f createvm-* ]; then
   rm -f createvm-*
   rm -f all.csv
   rm -f vm_gen.csv
   rm -f dhcp1.txt
else
   sh /vm/bin/bulk-createvm.sh
   cp  createvm-* all.csv
   sh /vm/bin/gencsv.sh
   sh /vm/bin/gen_dhcpd_conf.sh
fi
