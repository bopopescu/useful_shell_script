#!/bin/sh

if [ "$1" = "" ]; then
   echo "IP address is needed"
   exit 1
else
   ip=$1
fi

if [ "$2" = "" ]; then
   echo "User name is needed"
   exit 1
else
   user=$2
fi

if [ "$3" = "" ]; then
   echo "Password is needed"
   exit 1
else
   password=$3
fi

/usr/local/bin/sshpass -p $password ssh -o ConnectTimeout=90 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=quiet $user@$ip racadm serveraction powerup >> /var/log/sshpass.log
exit $?

