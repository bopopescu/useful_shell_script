#!/bin/sh

old_ip=$1
user=$2
password=$3
new_ip=$4
new_netmask=$5
new_gateway=$6

/usr/bin/sshpass -p $password ssh -o ConnectTimeout=10 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=quiet $user@$old_ip racadm setniccfg -s $new_ip $new_netmask $new_gateway
exit $?
