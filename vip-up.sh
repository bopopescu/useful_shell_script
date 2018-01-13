
#HOSTS
#for ((i=1; i<=$CSERVER_NUM; i++))
#do
#    EXT_IP_CS=EXT_IP_CSERVER$i
    #ifconfig bond0:$i ${!EXT_IP_CS}/23
#done

echo "config host nat" >> /var/log/messages

#VIP for VM
#for ((j=1; j<=$CSERVER_NUM; j++))
#do
#   for ((m=0; m<=$((WAN_END$j-WAN_START$j)); m++))
#   do
#      EXT_IP_CS=EXT_IP_CSERVER$j$m;
#      ifconfig bond0:$j$m ${!EXT_IP_CS}/23
#   done
#done

#echo "config vm nat" >> /var/log/messages

#Manager IP
ifconfig bond0:111 $MANAGEMENT_IP 
