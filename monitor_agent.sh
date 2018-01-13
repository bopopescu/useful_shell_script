#!/bin/sh
tar zxvf ossec-binary-agent64.tgz
cd ossec-binary-agent64
server_ip=`python getParam.py $server_role monitor_server_ip`
./agent_install.sh $server_ip
cd -
