#!/bin/bash

# CCP Environment Setup Script, for CCP  v1.5, 14-May-2012 by Felix

# Syntax ./ccp-install.sh [cloud_center_id] [installation_mode]
# Installation mode "r" means remote install, "l" means local install, "d" means download only

#PREFIX="https://ccp.s.mygrid.asia"
PREFIX="http://$tftp_server_ip/yum_repo/images/os/CServer"
VER="v1.5"
CCP="ccp-v1.5-package.tar.gz"
CCP_FOLDER="ccp-v1.5-package"
CCP_URL=$PREFIX/$VER/$CCP

rm -f ./error.log >/dev/null 2>&1

if [ $# -ne 2 ]
then
        echo Syntax Error
	echo e.g. ./ccp-install.sh [cloud_center_id] [installation_mode]
	echo Installation Mode "r" means Remote Install, "l" means Local Install, "d" means Download Only
        echo
        exit
fi

if ( test "$2" != "r" && test "$2" != "R" && test "$2" != "l" && test "$2" != "L" && test "$2" != "d" && test "$2" != "D" )
then
	echo
	echo Invalid Installation Mode, either "r" or "l" or "d" is allowed
	echo
	exit
fi


if ( test "$2" = "d" || test "$2" = "D" )
then
	# Download
	rm -f ./$CCP >/dev/null 2>&1
	wget -N $CCP_URL
	exit
fi

if ( test "$2" = "r" || test "$2" = "R" )
then
        # Download
        rm -f ./$CCP >/dev/null 2>&1
        wget -N $CCP_URL
fi

# Extract and Install
rm -rf ./$CCP_FOLDER >/dev/null 2>&1
tar -zxf $CCP >/dev/null 2>>error.log
cd $CCP_FOLDER
./install.sh $1
cd ../
