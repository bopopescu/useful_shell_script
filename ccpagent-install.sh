#!/bin/bash

# CCP Agent v1.5 Installation, 14-May-2012 by Felix

# Syntax ./ccpagent-install.sh [installation_mode] [cloud_center_id] [host number] [xen version]
# Installation mode "r" means remote install, "l" means local install, "d" means download only
# Example: ./ccpagent-install.sh r hk00002 1 3.4.4
# It means Remote Install for Center ID hk00002, host #1, xen version 3.4.4

WWW_FOLDER="/www"

CMS_FOLDERS="phpmyadmin zendframework"

#PREFIX="https://ccp.s.mygrid.asia"
PREFIX="http://$tftp_server_ip/yum_repo/images/os/CServer"
VER="v1.5"
CCP="ccpagent-1.5-bin.tar.gz"
CCP_FRAMEWORK="ccp-zendframework-phpmyadmin-bin.tar.gz"
CCP_POST="ccpagent-post-1.5.tar.gz"

CCP_URL=$PREFIX/$VER/$CCP
CCP_FRAMEWORK_URL=$PREFIX/$VER/$CCP_FRAMEWORK
CCP_POST_URL=$PREFIX/$VER/$CCP_POST

CCP_POST_FOLDER="ccpagent-post-1.5"

rm -f error.log >/dev/null 2>&1

if [ $# -ne 4 ]
then
	echo
        echo Syntax Error
	echo e.g. ./ccpagent-install.sh [installation_mode] [cloud_center_id] [host number] [xen version]
	echo Installation Mode "r" means Remote Install, "l" means Local Install, "d" means Download Only
        echo
	echo Example: ./ccpagent-install.sh r hk00002 1 3.4.4
	echo It means Remote Install for Center ID hk00002, host \#1, xen version 3.4.4
	echo
        exit
fi

if ( test "$1" != "r" && test "$1" != "R" && test "$1" != "l" && test "$1" != "L" && test "$1" != "d" && test "$1" != "D" )
then
	echo
	echo Invalid Installation Mode, either "r" or "l" or "d" is allowed
	echo
	exit
fi


if ( test "$1" = "d" || test "$1" = "D" )
then
	# Download
	rm -f ./$CCP >/dev/null 2>&1
	rm -f ./$CCP_FRAMEWORK >/dev/null 2>&1
	echo Downloading Software....
	wget -N $CCP_URL
	wget -N $CCP_FRAMEWORK_URL
	wget -N $CCP_POST_URL 
	exit
fi

if ( test "$1" = "r" || test "$1" = "R" )
then
        # Download
        rm -f ./$CCP >/dev/null 2>&1
        rm -f ./$CCP_FRAMEWORK >/dev/null 2>&1
	echo Downloading Software....
        wget -N $CCP_URL
        wget -N $CCP_FRAMEWORK_URL
	wget -N $CCP_POST_URL
fi

# Extract and Install
echo 
echo Installing CCP Agent....
rm -rf ./ccpagent ./$CCP_POST_FOLDER ./$CMS_FOLDERS >/dev/null 2>&1
mkdir ccpagent >/dev/null 2>&1
tar -zxf $CCP -C ./ccpagent >/dev/null 2>>error.log
tar -zxf $CCP_FRAMEWORK >/dev/null 2>>error.log
tar -zxf $CCP_POST >/dev/null 2>>error.log

mkdir -p $WWW_FOLDER/blank >/dev/null 2>&1
mkdir -p $WWW_FOLDER/production-$2/$2.cserver.mygrid.asia >/dev/null 2>>error.log
mv ./ccpagent/* $WWW_FOLDER/production-$2/$2.cserver.mygrid.asia/ >/dev/null 2>>error.log
rm -rf ./ccpagent >/dev/null 2>&1
rm -rf $WWW_FOLDER/blank/zendframework $WWW_FOLDER/blank/phpmyadmin >/dev/null 2>&1
mv $CMS_FOLDERS $WWW_FOLDER/blank >/dev/null 2>>error.log
chown -R nobody:nobody $WWW_FOLDER >/dev/null 2>&1
echo ...done

cd ./$CCP_POST_FOLDER
./post_config.sh $2 $3 $4

/usr/local/apache/bin/apachectl stop >/dev/null 2>&1
sleep 3
/usr/local/apache/bin/apachectl start 2>>error.log
