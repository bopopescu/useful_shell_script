#!/bin/sh 

# Singleton
#exec 9>/tmp/tplService.lock

#if ! flock -n 9
#then 
#    echo "There is another tplService running, exit"
#    exit 1
#else
#    trap 'rm -rf /tmp/tplService.lock' 0
#fi
TPLDIR=/root/vm/template

STORAGETYPE=PSAN
STORAGENODE=2
STORAGENODEID=2

get_config_value()
{
   cfile=$1
   section=$2
   key=$3
   value=`cat $cfile|awk 'BEGIN{FS="=";OFS=":";}/\['$section'\]/,/\[.*[^('$section')].*\]/{gsub(/[[:blank:]]*/,"",$1);if(NF==2 && $1=="'$key'"){gsub(/^[[:blank:]]*/,"",$2);gsub(/[[:blank:]]*$/,"",$2);print $2;}}'`
   echo $value        
}

config_file="/etc/tpl.conf"

section="account"

key="user"
user=`get_config_value $config_file $section $key`

key="password"
password=`get_config_value $config_file $section $key`

key="master_ip"
master_ip=`get_config_value $config_file $section $key`

local_ip=`ifconfig ring0|awk 'NR==2{split($2, a, ":");print a[2]}'`
local_pv=`/root/tplworker/view_disks_in_node.sh`

echo LOCALPV=$local_pv
# Syncronize tpl.conf from master node

#sshpass -p $password scp -o StrictHostKeyChecking=no $user@$master_ip:/etc/tpl.conf /etc/tpl.conf

if [ ! $? -eq 0 ]
then
   echo "Failed to sync tpl.conf from master node"
   exit 1
fi

# Set io priority for current process and child process
ionice -c3 -p$$

echo  STORAGETYPE=$STORAGETYPE

while true
do
    section="prefill"

    tplList=`ls $TPLDIR -l|awk 'NR>1{print $NF}'|grep -e "\.img$"`

    #echo $tplList

    for tpl in $tplList
    do
      key=$tpl
      lvName=""

      prefill_num=`get_config_value $config_file $section $key`


      # No special setting for this template, get the default value instead
      if [ -z "$prefill_num" ]
      then
	  key="default"
	  prefill_num=`get_config_value $config_file $section $key`
      fi


      if [ $STORAGETYPE = "PSAN" ]
	then
	      current_lv_reserved_num=`lvs -o +devices | grep $local_pv|awk 'NR>1{print;}'|grep $tpl|wc -l`
	      total_prefill_num=$(($prefill_num*$STORAGENODE))
	else
	      current_lv_reserved_num=`lvs | awk 'NR>1{print;}'|grep $tpl|wc -l`
	      total_prefill_num=$prefill_num
      fi

      echo $tpl: $current_lv_reserved_num/$prefill_num $total_prefill_num

      if [ $prefill_num -gt $current_lv_reserved_num ]
      then
	  for ((i=1; i<=$total_prefill_num; i++))
	  do
	     lvcount=`lvs|grep $tpl-reserved-$i|wc -l`
	     if [ $lvcount = 0 ]
	     then
		lvName="$tpl""-reserved-$i"
		break
	     fi 
	  done

	  # Running multiple nodes concurrently may lead to this scenario
	  if [ -z "$lvName" ]
	  then
	     echo "$tpl: No valid name to create a new LV for."
	     continue
	  fi

	  tplSize=`du -b $TPLDIR/$tpl|awk '{print $1}'`

          pv=""
          
          if [ $STORAGETYPE = "PSAN" ]
          then
              pv_size=`pvs --units b 2>/dev/null|grep $local_pv|awk '{print $6}'|tr -d 'B'`
              #Specify local PV only when there is enough free space
              if [ $pv_size -gt $tplSize ]
              then
                  pv=$local_pv
              fi 
          fi
          echo $tpl: $tplSize $lvName $pv
	  echo lvcreate -L $tplSize"b" -n /dev/vg/$lvName".tmp" /dev/vg $pv
###
	  lvcreate -L $tplSize"b" -n /dev/vg/$lvName".tmp" /dev/vg $pv
     
	  ret=$? 

	  if [ $ret -eq 0 ]
	  then
	      echo dd if=$TPLDIR/$tpl of=/dev/vg/$lvName".tmp" bs=1M
###
	      dd if=$TPLDIR/$tpl of=/dev/vg/$lvName".tmp" bs=1M 
	  else
	      echo "Create LV $lvName error: "$ret
	      exit $ret 
	  fi
          echo lvrename /dev/vg/$lvName".tmp" /dev/vg/$lvName
###
          lvrename /dev/vg/$lvName".tmp" /dev/vg/$lvName 

	  if [ ! $ret -eq 0 ]
          then
              echo "Failed to rename LV:"$lvName.".tmp"
          fi
      fi
    done
   
    sleep 10
done

