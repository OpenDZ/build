#!/bin/bash

# This file is part of bus1. See COPYING for details.
#
# bus1 is free software; you can redistribute it and/or modify it
# under the terms of the GNU Lesser General Public License as published by
# the Free Software Foundation; either version 2.1 of the License, or
# (at your option) any later version.
#
# bus1 is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
# Lesser General Public License for more details.
#
# You should have received a copy of the GNU Lesser General Public License
# along with bus1; If not, see <http://www.gnu.org/licenses/>.
#
#
# Create a Raspberry Pi 2 bootable disk image "rpi-disk.img".

set -e

# ------------------------------------------------------------------------------
ROOT=$(mktemp -d /tmp/rpi-tmpXXX)

# create DOS partition table
rm -f rpi-disk.img
dd if=/dev/null of=rpi-disk.img bs=1MiB seek=1024 count=1

sfdisk rpi-disk.img << EOF
unit: sectors

rpi-disk.img1 : start=     2048, size=   262144, Id= c
rpi-disk.img2 : start=   264192, size=  1048576, Id=83
rpi-disk.img3 : start=        0, size=        0, Id= 0
rpi-disk.img4 : start=        0, size=        0, Id= 0
EOF

LOOP=$(losetup --show -f -P rpi-disk.img)

# ------------------------------------------------------------------------------
# Boot
mkfs.vfat -n BOOT -F 32 ${LOOP}p1
mkdir $ROOT/boot
mount ${LOOP}p1 $ROOT/boot

cp -ax firmware/boot/* $ROOT/boot
cp initrd $ROOT/boot

cat << EOF > $ROOT/boot/config.txt
dtparam=audio=on
disable_overscan=1
initramfs initrd followkernel
EOF

cat << EOF > $ROOT/boot/cmdline.txt
quiet boot=/dev/mmcblk0p1 data=/dev/mmcblk0p2
EOF

RELEASE=$(cat system/usr/lib/org.bus1/release)
cp $RELEASE.img $ROOT/boot/$RELEASE.img

umount $ROOT/boot

# ------------------------------------------------------------------------------
# Data
DATA_FSTYPE=$(cat system/usr/lib/org.bus1/data.fstype)
dmsetup remove org.bus1.data 2>/dev/null ||:
../base/org.bus1.diskctl encrypt org.bus1.data "$DATA_FSTYPE" ${LOOP}p2
../base/org.bus1.diskctl setup ${LOOP}p2
udevadm settle
mkfs.$DATA_FSTYPE -L bus1 -q /dev/mapper/org.bus1.data
udevadm settle
dmsetup remove org.bus1.data

# ------------------------------------------------------------------------------
sync
rm -rf $ROOT
losetup -d $LOOP
