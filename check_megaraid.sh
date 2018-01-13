CONT="a0"
STATUS=0
#echo -n "Checking RAID status on "
#hostname
for a in $CONT
do
NAME=`/opt/MegaRAID/MegaCli/MegaCli64 -AdpAllInfo -$a |grep "Product Name" | cut -d: -f2`
#echo $NAME
noonline=`/opt/MegaRAID/MegaCli/MegaCli64 PDList -$a | grep Online | wc -l`
#echo "No of Physical disks online : $noonline"
DEGRADED=`/opt/MegaRAID/MegaCli/MegaCli64  -AdpAllInfo -a0 |grep "Degrade"`
#echo $DEGRADED
NUM_DEGRADED=`echo $DEGRADED |cut -d" " -f3`
[ "$NUM_DEGRADED" -ne 0 ] && STATUS=1
FAILED=`/opt/MegaRAID/MegaCli/MegaCli64 -AdpAllInfo -a0 |grep "Failed Disks"`
#echo $FAILED
NUM_FAILED=`echo $FAILED |cut -d" " -f4`
[ "$NUM_FAILED" -ne 0 ] && STATUS=1
echo $NAME,disks online:$noonline,$DEGRADED,$FAILED `/usr/local/nagios/libexec/check_megaraid_sas`> /usr/local/nagios/libexec/diskraid.txt
#[echo `cat  test.txt`]
done
