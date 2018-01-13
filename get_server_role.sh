#!/bin/sh

install_uuid=$1
mac=$2

file_list=`ls -l $install_uuid/server_mac|awk 'NR>1{print $9}'`

if [ $? -eq 0 ]
then
    for fname in $(echo $file_list|awk '{print;}')
    do
        found=`cat $install_uuid/server_mac/$fname|grep -i $mac|wc -l`
        if [ ! $found -eq 0 ]
        then
            echo $fname
            break
        fi
    done
else
    exit $? 
fi 
