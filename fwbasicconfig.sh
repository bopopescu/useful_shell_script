# RHEL6 uses /etc/modprobe.d directory
if [ -d /etc/modprobe.d ]; then
        BONDCONFIG=/etc/modprobe.d/bonding.conf
else # Assume RHEL5
        BONDCONFIG=/etc/modprove.conf
fi

# Load the bonding kernel module with active-backup mode and set mii link monitoring to 100 ms.
cp /etc/modprobe.conf /tmp/modprobe.conf.bonding
test -f "{BONDCONFIG}" && cp "${BONDCONFIG}" /tmp/modprobe.conf.bonding
cat >> /tmp/modprobe.conf.bonding <<EOF
alias bond0 bonding
options bond0 mode=1 miimon=100
alias bond1 bonding
options bond1 mode=1 miimon=100
EOF

cat /tmp/modprobe.conf.bonding|uniq > "${BONDCONFIG}"

>/etc/sysconfig/network-scripts/ifcfg-eth0 
cat >> /etc/sysconfig/network-scripts/ifcfg-eth0 <<IFS
DEVICE=eth0
USERCTL=no
ONBOOT=yes
BOOTPROTO=none
IPADDR=$public_ip
NETMASK=$public_netmask
GATEWAY=$public_gateway
HWADDR=$(/sbin/ifconfig em1|egrep -o "([[:xdigit:]]{2}[:]){5}[[:xdigit:]]{2}") 
IFS

for i in 1 2 
do
j=$(($i+1))
# WAN
>/etc/sysconfig/network-scripts/ifcfg-eth$i 
cat >> /etc/sysconfig/network-scripts/ifcfg-eth$i <<IFS
DEVICE=eth$i
USERCTL=no
ONBOOT=yes
MASTER=bond0
SLAVE=yes
BOOTPROTO=none
HWADDR=$(/sbin/ifconfig em$j|egrep -o "([[:xdigit:]]{2}[:]){5}[[:xdigit:]]{2}")
IFS
done

# Heartbeat
>/etc/sysconfig/network-scripts/ifcfg-eth3 
cat >> /etc/sysconfig/network-scripts/ifcfg-eth3 <<IFS
DEVICE=eth3
USERCTL=no
ONBOOT=yes
IPADDR=$heartbeat_ip
NETMASK=255.255.255.0
BOOTPROTO=none
HWADDR=$(/sbin/ifconfig em4|egrep -o "([[:xdigit:]]{2}[:]){5}[[:xdigit:]]{2}")
IFS

# Create the bond0 device file.
>/etc/sysconfig/network-scripts/ifcfg-bond0 
cat >> /etc/sysconfig/network-scripts/ifcfg-bond0 <<BOND
DEVICE=bond0
ONBOOT=yes
IPADDR=$private_ip
NETMASK=$private_netmask
USERCTL=no
BOND

sed -i '/HOSTNAME/d' /etc/sysconfig/network
echo "HOSTNAME=$server_level-$grid" >> /etc/sysconfig/network

# off first
chkconfig atd off --level 3
chkconfig bluetooth off --level 3
chkconfig dnsmasq off --level 3
chkconfig firstboot off --level 3
chkconfig messagebus off --level 3

# service on 
chkconfig acpid on --level 3
chkconfig crond on --level 3
chkconfig irqbalance on --level 3
chkconfig lvm2-monitor on --level 3
chkconfig network on --level 3
chkconfig sshd on --level 3
chkconfig syslog on --level 3
chkconfig sendmail on --level 3

mkdir -p /root/script/firewall-gateway
cd /root/script/firewall-gateway
wget -N http://$tftp_server_ip/yum_repo/images/os/Firewall/resource/fw-common.inc
chmod a+x fw-common.inc
wget -N http://$tftp_server_ip/yum_repo/images/os/Firewall/resource/fw-local.inc
chmod a+x fw-local.inc
wget -N http://$tftp_server_ip/yum_repo/images/os/Firewall/resource/fw.enable
chmod a+x fw.enable
wget -N http://$tftp_server_ip/yum_repo/images/os/Firewall/resource/fw.local
chmod a+x fw.local
wget -N http://$tftp_server_ip/yum_repo/images/os/Firewall/resource/getParam.py
chmod a+x getParam.py
wget -N http://$tftp_server_ip/yum_repo/images/os/Firewall/resource/fw-firstboot.sh
chmod a+x fw-firstboot.sh

echo "[IPINFO]" >> fw.conf

echo manage_ip=$manage_ip >> fw.conf

echo public_gateway=$public_gateway >> fw.conf

#for fw_mac in $(echo $mac_list|awk '{print;}')
#do
#    s_level=`python getParam.py $fw_mac '' server_level`
#    s_num=${s_level: -1}
#    if [[ $s_level == *"CServer"* ]]
#    then 
#        priv_ip=`python getParam.py $fw_mac '' private_ip`
#        echo CS"$s_num"_ip=$priv_ip >> fw.conf
#    fi 
#done

for i in 1 2 3 4 5 6 7
do
   echo CS"$i"_ip="10.1.1.1"$i >> fw.conf
done
   
echo FW1_heartbeat_ip=$FW1_heartbeat_ip >> fw.conf
echo FW2_heartbeat_ip=$FW2_heartbeat_ip >> fw.conf

cd -

sed -i '/exit $rc/d' /etc/init.d/network
sed -i '$ a cd /root/script/firewall-gateway' /etc/init.d/network
sed -i '$ a ./fw.enable &> /var/log/fw.log &' /etc/init.d/network
sed -i '$ a cd -' /etc/init.d/network
sed -i '$ a exit $rc' /etc/init.d/network

if [ ! -d /etc/ha.d ]
then
    mkdir /etc/ha.d
fi

cd /etc/ha.d/
if [ ! -f authkeys ]
then
   wget http://$tftp_server_ip/yum_repo/images/os/Firewall/resource/ha.d/authkeys
fi
chmod 600 authkeys

if [ ! -f ha.cf ]
then
   wget http://$tftp_server_ip/yum_repo/images/os/Firewall/resource/ha.d/ha.cf
fi
sed -i "$ a ucast eth3 $ucast_ip" ha.cf
sed -i "$ a auto_failback on" ha.cf
sed -i "$ a node    $server_level-""$grid" ha.cf
sed -i "$ a node    $server_level-""$grid" ha.cf

if [ ! -f haresources ]
then
   wget http://$tftp_server_ip/yum_repo/images/os/Firewall/resource/ha.d/haresources
fi
sed -i "$ a $server_level-$grid vip MailTo::support@powerallnetworks.com::"$grid"_Alert_E-Mail" haresources

echo $FW1_heartbeat_ip $server_level"-$grid" >> /etc/hosts
echo $FW2_heartbeat_ip $server_level"-$grid" >> /etc/hosts

cd -

cat > /etc/init.d/vip <<EOF
#!/bin/sh
case "$1" in
'start')
        /root/script/firewall-gateway/vip-up.sh
        ;;
'stop')
       /root/script/firewall-gateway/vip-down.sh
       ;;
'restart')
        /root/script/firewall-gateway/vip-down.sh
        /root/script/firewall-gateway/vip-up.sh
        ;;
*)
        echo "Usage: $0 { Start | Stop | Status | Restart }"
        ;;
esac
exit 0
EOF

chmod a+x /etc/init.d/vip

bond0_11="0.0.0.0"
bond0_12="0.0.0.0"
bond0_101="0.0.0.0"
bond0_102="0.0.0.0"
eth0_101="0.0.0.0"
eth0_102="0.0.0.0"
eth0_103="0.0.0.0"
eth0_104="0.0.0.0"
eth0_105="0.0.0.0"

cat > /root/script/firewall-gateway/vip-up.sh <<EOF
#!/bin/sh
ifconfig bond0:11 $bond0_11 up
ifconfig bond0:12 $bond0_12 up
ifconfig bond0:101 $bond0_101 up
ifconfig bond0:102 $bond0_102 up


ifconfig eth0:101 $eth0_101 up
ifconfig eth0:102 $eth0_102 up
ifconfig eth0:103 $eth0_103 up
ifconfig eth0:104 $eth0_104 up
ifconfig eth0:105 $eth0_105 up
EOF

chmod a+x /root/script/firewall-gateway/vip-up.sh

cat > /root/script/firewall-gateway/vip-down.sh <<EOF
#!/bin/sh
ifconfig bond0:11 $bond0_11 down
ifconfig bond0:12 $bond0_12 down
ifconfig bond0:101 $bond0_101 down
ifconfig bond0:102 $bond0_102 down


ifconfig eth0:101 $eth0_101 down
ifconfig eth0:102 $eth0_102 down
ifconfig eth0:103 $eth0_103 down
ifconfig eth0:104 $eth0_104 down
ifconfig eth0:105 $eth0_105 down
EOF

chmod a+x /root/script/firewall-gateway/vip-down.sh

sed -i '$ a sh /root/script/firewall-gateway/fw-firstboot.sh > /var/log/firstboot.log' /etc/rc.d/rc.local

cd /etc/yum.repos.d
mv * /home

wget http://$tftp_server_ip/yum_repo/images/packages/centos-6-4/repo/CentOS-Base.repo

yum -y remove libtevent
yum -y install libtevent
yum -y remove libtevent
wget http://$tftp_server_ip/yum_repo/images/os/Firewall/Packages/libtevent-0.9.18-3.el6.x86_64.rpm
rpm -ivh libtevent-0.9.18-3.el6.x86_64.rpm
#yum install heartbeat* -y
yum install heartbeat* -y

cd -
#mv /home/CentOS-* .
