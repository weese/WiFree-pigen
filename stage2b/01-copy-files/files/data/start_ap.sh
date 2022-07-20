#!/bin/bash

source /data/channel.conf
source /data/ssid.conf
source /data/key.conf

/sbin/ifdown $DEV
/usr/bin/create_ap --no-virt -c $CHANNEL -n $DEV $SSID $KEY


