#!/bin/bash

if [[ ! -b /dev/mmcblk0p4 ]]
then
	echo "create partition..."
	NEWSTART=$(fdisk -l /dev/mmcblk0 |grep mmcblk0p3|awk '{print $3+1}')
	NEWEND=$(fdisk -l /dev/mmcblk0 |head -2|tail -1|awk '{print $7}')
	echo -e "n\np\n4130816\n\nw\n" | fdisk /dev/mmcblk0
	partprobe
	mkfs.ext4 -q -F /dev/mmcblk0p4
fi

mount /dev/mmcblk0p4 /video
cp /root/WiFree/index.html /video/

exit 0

