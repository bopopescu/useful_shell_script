#!/bin/bash 

curDir=$(cd "$(dirname "$0")"; pwd)
section="vg";

key="deldir";
delDir=`cat $curDir/config.ini | awk 'BEGIN{FS="=";OFS=":";}/\['$section'\]/,/\[.*[^('$section')].*\]/{gsub(/[[:blank:]]*/,"",$1);if(NF==2 && $1=="'$key'"){gsub(/^[[:blank:]]*/,"",$2);gsub(/[[:blank:]]*$/,"",$2);print $2;}}'`

key="deltime";
delTime=`cat $curDir/config.ini | awk 'BEGIN{FS="=";OFS=":";}/\['$section'\]/,/\[.*[^('$section')].*\]/{gsub(/[[:blank:]]*/,"",$1);if(NF==2 && $1=="'$key'"){gsub(/^[[:blank:]]*/,"",$2);gsub(/[[:blank:]]*$/,"",$2);print $2;}}'`


if [ ! -d "$delDir" ]
then
    mkdir "$delDir"
fi

/bin/echo "Removing Deleted LVs and XML..."

for file in $(/usr/sbin/lvdisplay | /bin/grep .deleted)
do
    if [ $file != "LV" -a $file != "Name" ]
    then
       bFound=false
       prefix=`/bin/echo $file|awk '{split($1, pre, ".");print pre[1]}'`
       prefix=`/bin/basename $prefix` 
       
       files=`ls "$delDir"|grep $prefix`
       for f in $files
       do
          cTime=`/bin/echo $f|awk '{split($1, fn, ".");print fn[2]}'`
          bFound=true
          break
       done
       
       if $bFound
       then
           tNow=`/bin/date +%s`
           if [ `echo "$tNow $cTime"|awk '{print ( ($1-$2) )}'` -ge $delTime ]
           then
               /usr/sbin/lvremove -f $file
               rm -f /vm/etc/${file:8:36}.xml
               rm -f /tmp/lvmDelete/$f
           fi 
       else
           touch /tmp/lvmDelete/$prefix.`date +%s`  
       fi 
    fi
done

/bin/echo "Removing Deleted IDC Templates..."

for file in $(/bin/ls /vm/idc-template | /bin/grep ".deleted")
do
    /bin/echo /vm/idc-template/$file
    /bin/rm -Rf /vm/idc-template/$file
done

/bin/echo "Removing Deleted Custom Templates..."

for file in $(/bin/ls /vm/customer-template | /bin/grep ".deleted")
do
    /bin/echo /vm/customer-template/$file
    /bin/rm -Rf /vm/customer-template/$file
done

