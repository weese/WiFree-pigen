#!/bin/bash -e

mkdir -p "${ROOTFS_DIR}/data"

# copy WiFree config
install -m 644 files/data/channel.conf   "${ROOTFS_DIR}/data/"
install -m 644 files/data/key.conf       "${ROOTFS_DIR}/data/"
install -m 644 files/data/params.json    "${ROOTFS_DIR}/data/"
install -m 755 files/data/set_channel.sh "${ROOTFS_DIR}/data/"
install -m 644 files/data/ssid.conf      "${ROOTFS_DIR}/data/"
install -m 755 files/data/start_ap.sh    "${ROOTFS_DIR}/data/"

# enable Create AP service
install -m 755 files/usr/bin/create_ap "${ROOTFS_DIR}/usr/bin/"
install -m 755 files/lib/systemd/system/create_ap.service "${ROOTFS_DIR}/lib/systemd/system/"
ln -sv "/lib/systemd/system/create_ap.service" "$ROOTFS_DIR/etc/systemd/system/multi-user.target.wants/create_ap.service"

# enable WiFree service
install -m 755 files/lib/systemd/system/wifree.service "${ROOTFS_DIR}/lib/systemd/system/"
ln -sv "/lib/systemd/system/wifree.service" "$ROOTFS_DIR/etc/systemd/system/multi-user.target.wants/wifree.service"

# copy WiFree tools
mkdir -p "${ROOTFS_DIR}/root/WiFree/"
install -m 755 files/root/WiFree/create_partition.sh "${ROOTFS_DIR}/root/WiFree/"
install -m 644 files/root/WiFree/index.html          "${ROOTFS_DIR}/root/WiFree/"
install -m 644 files/root/WiFree/msp.rb              "${ROOTFS_DIR}/root/WiFree/"
install -m 755 files/root/WiFree/wfpicam.py          "${ROOTFS_DIR}/root/WiFree/"
install -m 755 files/root/WiFree/wifree-msp.rb       "${ROOTFS_DIR}/root/WiFree/"

mkdir -p "${ROOTFS_DIR}/video"

# boot config
cat << EOF >> ${ROOTFS_DIR}/boot/config.txt
start_x=1
enable_uart=1
dtoverlay=disable-bt
dtoverlay=pi3-disable-bt
dtoverlay=miniuart-bt
EOF

# disable terminal on serial
sed -i 's/console=serial0,115200//' $DESTBOOT/cmdline.txt"