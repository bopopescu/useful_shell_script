#!/bin/sh
#$1 需要查找哪个节点上的硬盘符合，输入为IP地址
#Ret=`ls /dev/disk/by-path/ -l | awk '{print $9}' | grep "ip"`
#tmp_file=".disk_tmp_file.txt"

if [ $# -gt 1 ] ; then
	echo "USAGE: $0 XXX.XXX.XXX.XXX or" 
        echo "USAGE: $0 " 
        exit 1
fi

if [ $# -eq 1 ]; then
	Ret=`sudo ls /dev/disk/by-path/* -l | grep "$1" | awk '{print $11}' | awk -F "/" '{print $3}'`
else
	Ret=`sudo ls /dev/disk/by-path/* -l | grep "ip-"| awk '{print $11}' | awk -F "/" '{print $3}'`
fi

OLD_IFS="$IFS"
IFS=" "
arr=($Ret)
IFS="$OLD_IFS"
sVal=""
for s in ${arr[@]}
do
	sVal="$sVal/dev/$s "
done

#Ret=`cat $tmp_file `
echo $sVal
exit 0;
