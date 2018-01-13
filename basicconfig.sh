sed -i '/HOSTNAME/d' /etc/sysconfig/network

echo "HOSTNAME=$server_level" >> /etc/sysconfig/network
echo "GATEWAY=$3" >> /etc/sysconfig/network
sed -i '$ a NOZEROCONF=yes' /etc/sysconfig/network
sed -i '/#/d' /etc/rc.local

if [ $1 = CServer1 ]
then    
    vginsda=`pvs|grep -E '/dev/sda.*vg '|wc -l`
    vginhda=`pvs|grep -E '/dev/hda.*vg '|wc -l`

    if [ $vginsda -eq 0 ] && [ $vginhda -eq 0 ] 
    then
      vgremove -f /dev/vg
    
      if [ -b /dev/sdb ]
      then
        if [ -b /dev/sdb1 ]
        then
           pvremove -f /dev/sdb1
        fi
        pvcreate -f /dev/sdb
        pvs|grep sdb|awk '{print $2}'|xargs vgremove -f 
        vgcreate vg /dev/sdb

        if [ ! $? -eq 0 ]
        then
	    pvcreate -f /dev/sdb1
	    vgcreate vg /dev/sdb1
	    if [ ! $? -eq 0 ]
	    then
	        echo 'Could not create volume vg'
	    fi
        fi

      elif [ -b /dev/hdb ]
      then
          if [ -b /dev/hdb1 ]
          then
             pvremove -f /dev/hdb1
          fi

          pvs|grep hdb|awk '{print $2}'|xargs vgremove -f 
          pvcreate /dev/hdb
	  vgcreate vg /dev/hdb

	  if [ ! $? -eq 0 ]
	  then
	      pvcreate /dev/hdb1
	      vgcreate vg /dev/hdb1
	    
              if [ ! $? -eq 0 ]
	      then
	   	  echo 'Could not create volume vg'
	      fi
	  fi
       fi
    fi

    lvremove /dev/vg/dhcp -f
    lvremove /dev/vg/tserver -f
    lvremove /dev/vg/tserver-data -f

    mv /www /www_old
    mkdir /www

    lvcreate -L10G -n tserver /dev/vg
    lvcreate -L10G -n dhcp /dev/vg
    
    #freesize=`vgs|grep -E 'vg '|awk 'NR==1{print int($7-0.5)}'|sed 's/g//g'`
    #if [ $freesize -gt 500 ]
    #then
        lvcreate -L500G -n tserver-data /dev/vg
    #else
    #    lvcreate -L"$freesize"G -n tserver-data /dev/vg
    #fi
    
    mkfs.ext3 /dev/vg/tserver-data > /dev/null
    sleep 180
    
    wget -N http://$tftp_server_ip/yum_repo/images/os/CServer/resource/install-tpl.sh
    chmod 755 ./install-tpl.sh
    ./install-tpl.sh -ccp -r tserver

    if [ -f tserver.img ];then
       dd if=tserver.img of=/dev/vg/tserver bs=100M
    fi

    mkdir -p /vm/etc
    mv tserver.cfg /vm/etc/
    #wget -N http://$tftp_server_ip/yum_repo/images/os/CServer/resource/dhcp.cfg
    #wget -N http://$tftp_server_ip/yum_repo/images/os/CServer/resource/dhcp.img.gz
    #mv dhcp.cfg /vm/etc/
    #gzip -d dhcp.img.gz
    #dd if=dhcp.img of=/dev/vg/dhcp bs=100M
    ln -s /vm/etc/tserver.cfg /etc/xen/auto/tserver
    #ln -s /vm/etc/dhcp.cfg /etc/xen/auto/dhcp

    #mv /www_old/* /www
else
    sed -i '10a sleep 2' /etc/rc.local
fi

# off first
chkconfig atd off --level 3
chkconfig bluetooth off --level 3
chkconfig dnsmasq off --level 3
chkconfig firstboot off --level 3
chkconfig sendmail off

# service on 
chkconfig acpid on --level 3
chkconfig crond on --level 3
chkconfig irqbalance on --level 3
chkconfig libvirtd on --level 3
chkconfig lvm2-monitor on --level 3
chkconfig network on --level 3
chkconfig sshd on --level 3
chkconfig syslog on --level 3
chkconfig xend on --level 3
chkconfig sendmail on --level 3

wget -N http://$tftp_server_ip/yum_repo/images/os/CServer/resource/cserver-firstboot.sh
chmod a+x cserver-firstboot.sh


wget -N http://$tftp_server_ip/yum_repo/images/os/CServer/resource/mount-tserver.sh
chmod a+x mount-tserver.sh
sed -i '$ a ifenslave bond0 eth0 eth1 eth2 eth3' /etc/rc.local
sed -i '$ a sh /resource/cserver-firstboot.sh > /var/log/firstboot.log' /etc/rc.local
sed -i '$ a sh /resource/mount-tserver.sh >/var/log/mount-tserver.log 2>&1 &' /etc/rc.local

