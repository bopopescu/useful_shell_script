#!/bin/sh

task_uuid=`python getParam.py $mac '' task_uuid`
CLUSTER_NAME=`python getParam.py '' $task_uuid cluster_name`

poolNAME=$CLUSTER_NAME

#for cls_name in $(echo $CLUSTER_NAMES | awk '{print;}')
#do
#     poolNAME=$cls_name
#     if [ 1$poolNAME != 1 ]
#     then
#         break
#     fi
#done

echo "pool name is: "$poolNAME

poolUUID=`xe pool-list|grep uuid|awk '{print $5}'`

xe pool-param-set name-label=$poolNAME uuid=$poolUUID

if [ ! $? -eq 0 ]
then
   echo "Create resource pool ""$CLUSTER_NAME failed"
   exit
fi
