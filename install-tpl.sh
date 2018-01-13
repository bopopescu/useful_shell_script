#!/bin/bash

# CCP/ICP VM Template Auto Install Script v1.0, 30-Nov-2011 by Felix

# Syntax ./install-tpl.sh [Cloud Center Mode, -ccp | -icp] [Installation Mode, -r | -l | -d] [Template Name]
# Installation mode "-r" means remote install, "-l" means local install, "-d" means download only
# Example: ./install-tpl.sh -ccp -r centos57-64
# it means Remote Install a template named 

rm -f ./error.log >/dev/null 2>&1

# ----------------------------
# Template Info
# ----------------------------
# Edit following variables
# Size Unit in GB
TPL_SIZE="10"
VG="vg"


if [ $# -ne 3 ]
then
        echo Syntax Error
	echo Syntax: ./install-tpl.sh [Cloud Center Mode, -ccp \| -icp] [Installation Mode, -r \| -l \| -d] [Template Name]
	echo Installation Mode "r" means Remote Install, "l" means Local Install, "d" means Download Only
	echo e.g. ./install-tpl.sh -ccp -r centos57-64
        echo
        exit
fi

if ( test "$1" != "-ccp" && test "$1" != "-icp" )
then
	echo
	echo Invalid Cloud Center Mode, either "-ccp" or "-icp" is allowed
	echo
	exit
elif ( test "$1" = "-ccp" )
then
	#PREFIX="https://ccp.s.mygrid.asia/template"
	PREFIX="http://$tftp_server_ip/yum_repo/images/os/CServer/template"
else
	#PREFIX="https://icp.s.mygrid.asia/template"
	PREFIX="http://$tftp_server_ip/yum_repo/images/os/CServer/template"
fi

# DONT'T edit following variables
TPL_FILE=$3.tgz
TPL_MBR=$3.mbr
TPL_FILE_URL=$PREFIX/$3/$TPL_FILE
TPL_MBR_URL=$PREFIX/$3/$TPL_MBR
TPL_FOLDER=$3
TPL_IMAGE=$3.img


if ( test "$2" != "-r" && test "$2" != "-R" && test "$2" != "-l" && test "$2" != "-L" && test "$2" != "-d" && test "$2" != "-D" )
then
	echo
	echo Invalid Installation Mode, either "-r" or "-l" or "-d" is allowed
	echo
	exit
fi


if ( test "$2" = "-d" || test "$2" = "-D" )
then
	# Download
	rm -f ./$TPL_FILE >/dev/null 2>&1
	wget -N $TPL_FILE_URL
	rm -f ./$TPL_MBR >/dev/null 2>&1
	wget -N $TPL_MBR_URL
	exit
fi

if ( test "$2" = "-r" || test "$2" = "-R" )
then
        # Download
        rm -f ./$TPL_FILE >/dev/null 2>&1
        wget -N $TPL_FILE_URL
	rm -f ./$TPL_MBR >/dev/null 2>&1
	wget -N $TPL_MBR_URL
fi

if [ ! -f $TPL_FILE ]
then
	echo $TPL_FILE does not exist, please retry.
	echo
	exit
elif [ ! -f $TPL_MBR ]
then
	echo $TPL_MBR does not exist, please retry.
	echo
	exit
fi

# Extract and Install
umount -f ./$TPL_FOLDER >/dev/null 2>&1
rm -rf ./$TPL_FOLDER >/dev/null 2>&1
mkdir ./$TPL_FOLDER >/dev/null 2>&1
rm -f ./$TPL_IMAGE >/dev/null 2>&1
echo Creating Image File...
IMGSIZE=0
IMGSIZE=`expr 1024 \* $TPL_SIZE` >/dev/null 2>>error.log
/bin/dd bs=1M if=/dev/zero of=./$TPL_IMAGE count=0 seek=$IMGSIZE >/dev/null 2>&1
#/bin/dd bs=1M if=/dev/zero of=./$TPL_IMAGE count=$IMGSIZE >/dev/null 2>&1
echo ...done
echo
LOOPDRIVE=`losetup -f` >/dev/null 2>>error.log
LOOPNAME=${LOOPDRIVE#*/dev/}
losetup $LOOPDRIVE ./$TPL_IMAGE
echo Partitioning Image File...
echo "n
p
2
1
+1G
t
82
n
p
1


t
1
83
w
" | fdisk $LOOPDRIVE >/dev/null 2>&1
echo ...done
echo
kpartx -a $LOOPDRIVE >/dev/null 2>>error.log
echo Formatting Image File...
mkfs.ext3 "/dev/mapper/"$LOOPNAME"p1" >/dev/null 2>&1
echo ...done
echo
tune2fs -c 0 -i 0 "/dev/mapper/"$LOOPNAME"p1" >/dev/null 2>>error.log
mount "/dev/mapper/"$LOOPNAME"p1" ./$TPL_FOLDER >/dev/null 2>>error.log
echo Extracting Template to Image...

tar -xpzf ./$TPL_FILE -C ./$TPL_FOLDER/ >/dev/null 2>>error.log

# To do: Request server for tserver ip and set to network-scripts 

mkdir ./$TPL_FOLDER/proc ./$TPL_FOLDER/lost+found ./$TPL_FOLDER/dev ./$TPL_FOLDER/sys >/dev/null 2>&1
echo ...done
echo
umount -f ./$TPL_FOLDER >/dev/null 2>&1
echo Installing MBR...
dd if=./$TPL_MBR of=$LOOPDRIVE bs=446 count=1 >/dev/null 2>&1
e2label "/dev/mapper/"$LOOPNAME"p1" /
mkswap "/dev/mapper/"$LOOPNAME"p2" >/dev/null 2>>error.log
kpartx -d $LOOPDRIVE >/dev/null 2>>error.log
echo ...done
echo
losetup -d $LOOPDRIVE >/dev/null 2>>error.log
rm -rf ./$TPL_FOLDER >/dev/null 2>&1
echo Template has been created. Filename: $TPL_IMAGE
echo
echo Notes: Run "losetup -a" to make sure there is no loopback device locked.
echo
