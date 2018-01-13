#!/bin/sh
mkfs.ext3 -F /dev/sdb
mount /dev/sdb /tserver
cd /tserver
mkdir backup idc-template mdftp template customer-template publicftp www mdftp/smartclone mdftp/smartclone/status
chown nobody.nobody *
chown mdftp.nobody -R /tserver/mdftp
chmod 775 -R /tserver/mdftp
chown publicftp.nobody /tserver/publicftp
exportfs
