#!/bin/sh 

curDir=$(cd "$(dirname "$0")"; pwd)

section="vg"

key="threshold"
Threshold=`cat $curDir/config.ini | awk 'BEGIN{FS="=";OFS=":";}/\['$section'\]/,/\[.*[^('$section')].*\]/{gsub(/[[:blank:]]*/,"",$1);if(NF==2 && $1=="'$key'"){gsub(/^[[:blank:]]*/,"",$2);gsub(/[[:blank:]]*$/,"",$2);print $2;}}'`

key="resizerate"
resizeRate=`cat $curDir/config.ini | awk 'BEGIN{FS="=";OFS=":";}/\['$section'\]/,/\[.*[^('$section')].*\]/{gsub(/[[:blank:]]*/,"",$1);if(NF==2 && $1=="'$key'"){gsub(/^[[:blank:]]*/,"",$2);gsub(/[[:blank:]]*$/,"",$2);print $2;}}'`

snapList=`/usr/sbin/lvs|grep snapshot|awk '{print $1}'`

for s in $snapList
do
     VG=`/usr/sbin/lvs |grep $s|awk 'NR==1{print $2}'`
     sPercent=`/usr/sbin/lvs -o snap_percent --noheadings /dev/$VG/$s|tr -d ' '`
     oLV=`echo $s|awk '{split($1, c, ".");print c[1]}'`
     oSize=`/usr/sbin/lvs -o LV_SIZE --noheadings /dev/$VG/$oLV --units M --nosuffix|tr -d ' '`
     sSize=`/usr/sbin/lvs -o LV_SIZE --noheadings /dev/$VG/$s --units M --nosuffix|tr -d ' '`
     bLarger=$(/bin/echo "$sPercent > $Threshold" | /usr/bin/bc)
     bToDelete=$(/bin/echo "$sPercent > 98" | /usr/bin/bc)
     VGFree=`/usr/sbin/vgs /dev/$VG -o VG_SIZE --noheadings --units M --nosuffix|tr -d ' '`
     
     if [ "$bToDelete"0 -eq 10 ]
     then
         lvremove -f /dev/$VG/$s
         echo "Remove snapshot: /dev/$VG/$s">> $curDir/backup.log
     elif [ "$bLarger"0 -eq 10 ]
     then
          rSize=`/bin/echo $sSize $resizeRate|awk '{printf( ($1+$1*$2/100) )}'`
     
          bLarger=$(/bin/echo "$rSize > $oSize" | /usr/bin/bc)
     
          if [ "$bLarger"0 -eq 10 ]
          then
               lvremove -f /dev/$VG/$s
          #check space in VG
          elif [ `echo "$VGFree $rSize $sSize" | awk '{print int( ($1-$2+$3) )}'` -lt 10 ]
          then
               echo "Not enough space left in $VG, could not resize snapshot" >> $curDir/backup.log
          else
               echo "/dev/$VG/$s need resizing, new size: $rSize"M >> $curDir/backup.log
               /usr/sbin/lvresize -L "$rSize"M "/dev/$VG/$s"
          fi
     else
          echo "use rate of /dev/$VG/$s is: $sPercent%, Total size: $sSize"M
          echo "use rate of /dev/$VG/$s is: $sPercent%, Total size: $sSize"M >> backup.log
     fi
done
