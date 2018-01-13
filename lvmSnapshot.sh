#!/bin/sh

curDir=$(cd "$(dirname "$0")"; pwd)
section="vg";

key="origin"
originVG=`cat $curDir/config.ini | awk 'BEGIN{FS="=";OFS=":";}/\['$section'\]/,/\[.*[^('$section')].*\]/{gsub(/[[:blank:]]*/,"",$1);if(NF==2 && $1=="'$key'"){gsub(/^[[:blank:]]*/,"",$2);gsub(/[[:blank:]]*$/,"",$2);print $2;}}'`

key="snapdir"
snapshotDir=`cat $curDir/config.ini | awk 'BEGIN{FS="=";OFS=":";}/\['$section'\]/,/\[.*[^('$section')].*\]/{gsub(/[[:blank:]]*/,"",$1);if(NF==2 && $1=="'$key'"){gsub(/^[[:blank:]]*/,"",$2);gsub(/[[:blank:]]*$/,"",$2);print $2;}}'`

key="vmconfigdir"
vmconfigDir=`cat $curDir/config.ini | awk 'BEGIN{FS="=";OFS=":";}/\['$section'\]/,/\[.*[^('$section')].*\]/{gsub(/[[:blank:]]*/,"",$1);if(NF==2 && $1=="'$key'"){gsub(/^[[:blank:]]*/,"",$2);gsub(/[[:blank:]]*$/,"",$2);print $2;}}'`

key="snapshotNum"
snapNum=`cat $curDir/config.ini | awk 'BEGIN{FS="=";OFS=":";}/\['$section'\]/,/\[.*[^('$section')].*\]/{gsub(/[[:blank:]]*/,"",$1);if(NF==2 && $1=="'$key'"){gsub(/^[[:blank:]]*/,"",$2);gsub(/[[:blank:]]*$/,"",$2);print $2;}}'`

key="interval"
Interval=`cat $curDir/config.ini | awk 'BEGIN{FS="=";OFS=":";}/\['$section'\]/,/\[.*[^('$section')].*\]/{gsub(/[[:blank:]]*/,"",$1);if(NF==2 && $1=="'$key'"){gsub(/^[[:blank:]]*/,"",$2);gsub(/[[:blank:]]*$/,"",$2);print $2;}}'`

key="mail"
mailAddr=`cat $curDir/config.ini | awk 'BEGIN{FS="=";OFS=":";}/\['$section'\]/,/\[.*[^('$section')].*\]/{gsub(/[[:blank:]]*/,"",$1);if(NF==2 && $1=="'$key'"){gsub(/^[[:blank:]]*/,"",$2);gsub(/[[:blank:]]*$/,"",$2);print $2;}}'`

#create snapshot for each logical volume
create_snapshot()
{
   local oLV=$1
   local oVG=`dirname $oLV`
   local snaplinkDir=$2
   
   snapName="`basename $oLV`.snapshot.`date +%s`"
   snapSize=`/usr/sbin/lvs $oLV -o LV_SIZE --noheadings --units M --nosuffix|tr -d ' '`
   snapSize=`echo "$snapSize 10" | awk '{print int( ($1/10) + 1 )}'`
   originVGFree=`/usr/sbin/vgs $oVG -o VG_SIZE --noheadings --units M --nosuffix|tr -d ' '`
   
   #check space in VG
   if [ `echo "$originVGFree $snapSize" | awk '{print int( ($1-$2) )}'` -lt 10 ]
   then
       echo "Not enough space left in $originVG, no snapshot could be created"|mail -s "LVM Backup Error" $mailAddr
       return
   fi
   
   echo "About to create a snapshot for volume: $oLV" >> $curDir/backup.log
  #echo $snapName 
   /usr/sbin/lvcreate -L "$snapSize"M -s -n $snapName $oLV > /dev/null
   cret=$?
   
   #/usr/sbin/lvcreate command fail
   repeatNum=0
   while [ ! $cret -eq 0 ]
   do  
       if [ $repeatNum -gt 2 ] 
       then
	   break
       fi

       #snapshot exists, weird
       if [ -b "$oVG/$snapName" ]
       then 
	  break
       fi
  
       #Original volume has been removed
       if [ ! -b $oLV ]
       then
	  echo "Origin volume '$oLV' has been removed" >> $curDir/backup.log
	  break;
       fi

       echo "create snapshot for $oLV failed" >> $curDir/backup.log
       echo "create snapshot for $oLV failed"|mail -s "LVM Backup Error" $mailAddr
       
       sleep 5
       #try again on 5 secs' later
       /usr/sbin/lvcreate -L $snapSize -s -n $snapName $oLV > /dev/null
       cret=$?

       repeatNum=$(($repeatNum+1))
   done
  
   #/usr/sbin/lvcreate command succeed 
   if [ $cret -eq 0 ]
   then
       echo "Newly created snapshot is: $snapName" >> $curDir/backup.log
       ln -s "$oVG/$snapName" "$snaplinkDir/$snapName" 
   fi 
}

#maintain a specific number of snapshots for each LV
check_snapshot_number()
{
   local oLV=$1
   local oVG=`dirname $oLV`
   local snapNum=$2
   local snaplinkDir=$3
    
   local lvName=`basename $oLV`
 
   snapshotCount=`/usr/sbin/lvs|grep "$lvName.snapshot"|wc -l`

   while [ $snapshotCount -gt $snapNum ]
   do
         delTime=0
         
         Snapshots=`/usr/sbin/lvs|grep "$lvName.snapshot"|awk '{print $1}'`
         for snap in $Snapshots
         do
              cTime=`echo "$snap"|awk '{split($1, c, ".");print c[3]}'`
              if [ 1"$delTime" -eq 1"0" ]
              then
                   delTime=$cTime
              else
                   if [ "$delTime"0 -gt "$cTime"0 ]
                   then
                       delTime=$cTime
                   fi
              fi
         done

         echo "Delete time: $delTime-------------" >> $curDir/backup.log         

	 snapDel=`/usr/sbin/lvs|grep "$lvName.snapshot.$delTime"|awk 'NR==1{print $1;}'`
	 snapDel="$oVG/$snapDel"
	 
	 /usr/sbin/lvremove -f $snapDel > /dev/null
	
	 rret=$?
	 repeatNum=0
	 while [ ! $rret -eq 0 ]
	 do
	     if [ "$repeatNum" -gt "2" ]
	     then  
		 break
	     fi
	     
	     #the specific snapshot has been removed accidentally
	     if [ ! -b $snapDel ]
	     then
		 echo "snapshot '$snapDel' has been removed" >> $curDir/backup.log
                 unlink "$snaplinkDir/`basename $snapDel`" >> $curDir/backup.log
                 echo "unlink and remove $snaplinkDir/`basename $snapDel`" >> $curDir/backup.log
                 rm -f "$snaplinkDir/`basename $snapDel`" >> $curDir/backup.log
		 break;
	     fi

	     echo "remove $snapDel failed" >> $curDir/backup.log
	     echo "remove $snapDel failed"|mail -s "LVM Backup Error" $mailAddr
	     
	     sleep 5 
	     umount -f $oVG/$snapDel
	     /usr/sbin/lvremove -f $snapDel > /dev/null          
	     rret=$?
             
             repeatNum=$(($repeatNum+1))
	 done
    
         if [ $rret -eq 0 ]
         then
	      echo "Remove the oldest snapshot: $snapDel" >> $curDir/backup.log
              unlink "$snaplinkDir/`basename $snapDel`" >> $curDir/backup.log
              echo "unlink and remove $snaplinkDir/`basename $snapDel`" >> $curDir/backup.log
              rm -f "$snaplinkDir/`basename $snapDel`" >> $curDir/backup.log
         fi
   
         snapshotCount=`/usr/sbin/lvs|grep "$lvName.snapshot"|wc -l`
   done 
}

exec 9>/tmp/snapshot.lock

if ! flock -n 9 
then
    echo "There is another backup process running, exit"
    echo "There is another backup process running, exit" >> $curDir/backup.log
    exit 1
else
    trap 'rm -rf /tmp/snapshot.lock' 0
fi

for vmid in `/usr/sbin/xm list|awk '$1 ~/\w*-\w*-\w*-\w*-\w*/{print $1}'`
do
    if [ ! -d "$snapshotDir/$vmid" ]
    then
	mkdir "$snapshotDir/$vmid"
    fi
 
    if [ -f "$vmconfigDir/$vmid.xml" ] 
    then
	for vmlv in `cat $vmconfigDir/$vmid.xml | grep $originVG|awk -F\' '{print $2}'`
	do
	    create_snapshot $vmlv "$snapshotDir/$vmid"
	    check_snapshot_number $vmlv $snapNum "$snapshotDir/$vmid"
	done
    fi
done  
