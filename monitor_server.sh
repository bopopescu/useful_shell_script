#!/bin/bash
#####DOWNLOAD#####
echo download installation package
wget http://$tftp_server_ip/yum_repo/images/os/cserver/resource/snmpd.conf
wget http://$tftp_server_ip/yum_repo/images/os/cserver/resource/nagios-plugins-1.5.tar.gz
wget http://$tftp_server_ip/yum_repo/images/os/cserver/resource/nrpe-2.13.tar.gz
wget http://$tftp_server_ip/yum_repo/images/os/cserver/resource/Sys-Statistics-Linux-0.66.tar.gz
wget http://$tftp_server_ip/yum_repo/images/os/cserver/resource/ibm_utl_sraidmr_megacli-8.00.48_linux_32-64.zip
wget http://$tftp_server_ip/yum_repo/images/os/cserver/resource/check_linux_stats.pl
wget http://$tftp_server_ip/yum_repo/images/os/cserver/resource/check_megaraid.sh
wget http://$tftp_server_ip/yum_repo/images/os/cserver/resource/check_megaraid_sas
#cd /root
gcc -v >/dev/null 2>&1
if [ $? = 0 ];
then
echo The Development tools already installed!
else
        echo The Development tools not installed,Installing ??????
        read -p "(y/n)" y
        if [ $y = y ]
        then
    yum -y install gcc openssl        
 #  yum groupinstall "Development tools"
        else break
fi
fi
echo install snmp
yum -y install net-snmp*
mv -f snmpd.conf /etc/snmp/ 
useradd nagios
echo
echo running install nagios-plugins-1.5
echo
tar -xzvf nagios-plugins-1.5.tar.gz >/dev/null 2>&1
cd nagios-plugins-1.5
./configure --prefix=/usr/local/nagios --with-nagios-user=nagios --with-nagios-group=nagios >/dev/null 2>&1
make >/dev/null 2>&1
make install >/dev/null 2>&1
#cd /root
cd -
echo
echo install nrpe-2.13
echo
tar -xzvf nrpe-2.13.tar.gz >/dev/null 2>&1
cd nrpe-2.13
yum -y install openssl*  xinetd -y >/dev/null 2>&1
./configure --enable-ssl --enable-command-args >/dev/null 2>&1
make all >/dev/null 2>&1
mkdir -p /usr/local/nagios/etc >/dev/null 2>&1
mkdir /usr/local/nagios/bin >/dev/null 2>&1
make all >/dev/null 2>&1
make install-plugin >/dev/null 2>&1
make install-daemon >/dev/null 2>&1
make install-daemon-config >/dev/null 2>&1
make install-xinetd >/dev/null 2>&1
cd -
sed -i "s/127.0.0.1/127.0.0.1 $tftp_server_ip/" /etc/xinetd.d/nrpe
echo "nrpe            5666/tcp                        # nagios" >> /etc/services
cat >> /usr/local/nagios/etc/nrpe.cfg<<EOF
command[check_sda]=/usr/local/nagios/libexec/check_disk -w 20% -c 10% -p /dev/sda
command[check_cpu_usage]=/usr/local/nagios/libexec/check_linux_stats.pl -C -w 90 -c 100 -s 5
command[check_load_average]=/usr/local/nagios/libexec/check_linux_stats.pl -L -w 10,8,5 -c 20,18,15
command[check_memory_usage]=/usr/local/nagios/libexec/check_linux_stats.pl -M -w 99.5,50 -c 100,80
command[check_disk_usage]=/usr/local/nagios/libexec/check_linux_stats.pl -D -w 10 -c 5 -p /
command[check_disk_io]=/usr/local/nagios/libexec/check_linux_stats.pl -I -w 100,70 -c 150,100 -p sda1
command[check_network_usage]=/usr/local/nagios/libexec/check_linux_stats.pl -N -w 4000000 -c 5000000 -p eth1,eth2,bond0,br0
command[check_uptime]=/usr/local/nagios/libexec/check_linux_stats.pl -U -w 9
command[check_raid_disk]=cat /usr/local/nagios/libexec/diskraid.txt
command[check_raid_status]=/usr/local/nagios/libexec/check_megaraid_sas
EOF
echo
echo install other
echo
mv  check_megaraid_sas check_linux_stats.pl check_megaraid.sh  /usr/local/nagios/libexec/
cd /usr/local/nagios/libexec/
chown nagios.nagios check_megaraid_sas check_linux_stats.pl check_megaraid.sh
chmod 755 check_megaraid_sas check_linux_stats.pl check_megaraid.sh
#cd /root
cd -
tar xzvf Sys-Statistics-Linux-0.66.tar.gz >/dev/null 2>&1
cd Sys-Statistics-Linux-0.66
perl Makefile.PL >/dev/null 2>&1
make && make install >/dev/null 2>&1
#cd /root
cd -
unzip -o ibm_utl_sraidmr_megacli-8.00.48_linux_32-64.zip
cd linux/
rpm -ivh Lib_Utils-1.00-09.noarch.rpm  MegaCli-8.00.48-1.i386.rpm >/dev/null 2>&1
ln -sf /opt/MegaRAID/MegaCli/MegaCli64 /usr/bin/megacli
#/etc/init.d/snmpd restart >/dev/null 2>&1
chkconfig snmpd on
if [ $? = 0 ];
 then echo snmp already installed!
else echo snmp is error
fi
#/etc/init.d/xinetd restart >/dev/null 2>&1
chkconfig xinetd on
/usr/local/nagios/libexec/check_nrpe -H localhost
if [ $? = 0 ];
 then echo nrpe already installed!
else echo nrpe is error
fi

cd -
exit


