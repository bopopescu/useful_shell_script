#!/bin/bash

template_server_ip="10.1.4.11"

WWW_SAMBA=$template_server_ip
TSERVER=$template_server_ip

TSERVER_STATE=`xm list|awk '{print $1}'|grep tserver|wc -l`

TRY_TIME=0

while [ 1$TSERVER_STATE -eq 10 -a $TRY_TIME -lt 60 ]; do
   sleep 10
   echo "No DomU tserver exists"
   TRY_TIME=$(($TRY_TIME+1))
   TSERVER_STATE=`xm list|awk '{print $1}'|grep tserver|wc -l`
done
 
#mv /www /www_old
#mkdir /www

mkdir -p /vm/template
mkdir -p /vm/customer-template
mkdir -p /vm/idc-template
mkdir -p /vm/mdftp
mkdir -p /vm/backup

mount.cifs //$TSERVER/template /vm/template -o user=nobody,password=tservershare
while [ ! $? -eq 0 ]; do
   echo "Mount /vm/template failed"
   sleep 10
   mount.cifs //$TSERVER/template /vm/template -o user=nobody,password=tservershare
done
mount.cifs //$TSERVER/customer-template /vm/customer-template -o user=nobody,password=tservershare
mount.cifs //$TSERVER/idc-template /vm/idc-template -o user=nobody,password=tservershare
mount.cifs //$TSERVER/mdftp /vm/mdftp -o user=nobody,password=tservershare
mount.cifs //$WWW_SAMBA/www /www -o user=nobody,password=tservershare
mount.cifs //$TSERVER/backup /vm/backup -o user=nobody,password=tservershare

if [ ! -d /www/blank ]
then
   mv /www_old/* /www
fi

if [ ! -d /vm/template/config ]
then
   cd /vm/template
   mkdir config
   cd -
fi


mac=`ifconfig eth0|grep HWaddr|awk '{print $5}'`
grid=`python getParam.py $mac '' grid`

if [ ! -d /vm/template/config/$grid ]
then
   cd /vm/template/config
   mkdir $grid
   cd -
fi
