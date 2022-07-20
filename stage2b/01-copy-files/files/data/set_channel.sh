#!/bin/bash
mount -o remount,rw /data
echo CHANNEL=$1 > /data/channel.conf
if [[ -n "$2" ]]
then
	echo KEY=$2 > /data/key.conf
fi
mount -o remount,ro /data
systemctl restart create_ap



