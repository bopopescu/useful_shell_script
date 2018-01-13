#!/bin/bash 
if [ $# -eq 0 ]
then
    echo "Please specify an id of VM to restore!"
    exit 1
fi

vmid=$1
section="vg";

key="snapdir"
snapshotDir=`cat config.ini | awk 'BEGIN{FS="=";OFS=":";}/\['$section'\]/,/\[.*[^('$section')].*\]/{gsub(/[[:blank:]]*/,"",$1);if(NF==2 && $1=="'$key'"){gsub(/^[[:blank:]]*/,"",$2);gsub(/[[:blank:]]*$/,"",$2);print $2;}}'`

key="mail"
mailAddr=`cat config.ini | awk 'BEGIN{FS="=";OFS=":";}/\['$section'\]/,/\[.*[^('$section')].*\]/{gsub(/[[:blank:]]*/,"",$1);if(NF==2 && $1=="'$key'"){gsub(/^[[:blank:]]*/,"",$2);gsub(/[[:blank:]]*$/,"",$2);print $2;}}'`

select_snapshot()
{
    sList=`ls "$snapshotDir/$vmid"`
    if [ -z "$sList" ]
    then
       echo "No backup for VM:$vmid exists!"
       return 
    fi

    for s in $sList
    do
        timeStamp=`echo $s|awk '{split($1, c, ".");print c[3]}'`
        timeStamp=`date -s "@$timeStamp" "+%F__%H:%M:%S"`
        echo "$timeStamp [Recover?]" >> /tmp/snapList.$$
    done	
    
    dialog --backtitle "System Recovery" --title "Available Recovery Point"\
           --menu "Select point of time to restore to:"\
           20 60 12 `cat /tmp/snapList.$$` 2>/tmp/snapSelected.$$

    rtval=$? 
    
    snapTime=`cat /tmp/snapSelected.$$|sed 's/__/ /g'`
    timeStamp=`date -d "$snapTime" +%s`
 
    snap2Merge=`ls "$snapshotDir/$vmid"|grep $timeStamp|awk 'NR==1{print $1;}'`
 
    VG=`lvs |grep $snap2Merge|awk 'NR==1{print $2}'`
    
    case $rtval in 
     0) dialog --backtitle "System Recovery" --title "Confirmation"\
               --yesno "\n\nDo you want to recover to this time? : $snapTime" 10 65
      
        if [ $? -eq 0 ] 
        then
          dialog --backtitle "System Recovery" --title "Information: Recovery" --infobox "Recovery is in progress, please wait..." 3 55
          lvconvert --merge /dev/$VG/$snap2Merge 1>/dev/null 2>/dev/null
          if [ $? -eq 0 ]
          then
            dialog --backtitle "System Recovery" --title "Information: Recovery" --infobox "System recover finished, press any key to return" 3 55
            read
            clear
	  else
            dialog --backtitle "System Recovery" --title "Error: Recovery" --infobox "Error recovering system, press any key to return" 3 60
            read 
            clear      
          fi
	else
           dialog --backtitle "System Recovery" --title "Information: Recover Command" --infobox "System does not recover by user's action, press any key to return" 3 70
           read
           clear
	fi
        ;;
    1)  rm -f /tmp/snapList.$$; 
        rm -f /tmp/snapSelected.$$; clear;return;;
    255) rm -f /tmp/snapList.$$
         rm -f /tmp/snapSelected.$$; clear;return;;
    esac
    
    rm -f /tmp/snapList.$$;
    rm -f /tmp/snapSelected.$$; 
    clear
    return
}
select_snapshot
