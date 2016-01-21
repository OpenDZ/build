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
# Create UEFI bootable disk image "efi-disk.img". The disk image contains
# one EFI System Partition (ESP) and a bus1 data partition. The ESP carries
# an EFI boot manager, an EFI binary containing a Linux kernel and an initrd.
# and a disk image to be mounted at /usr.

set -e

# ------------------------------------------------------------------------------
ROOT=$(mktemp -d /tmp/efi-tmpXXX)

# create GPT table with EFI System Partition
rm -f efi-disk.img
dd if=/dev/null of=efi-disk.img bs=1MiB seek=1024 count=1

sfdisk efi-disk.img << EOF
label: gpt
start=1MiB, size=511MiB, type=c12a7328-f81f-11d2-ba4b-00a0c93ec93b, name="ESP"
            size=512MiB, type=e0243462-d2d0-4c3b-ad28-b365f2da3b4d, name="bus1"
EOF

LOOP=$(losetup --show -f -P efi-disk.img)
# ------------------------------------------------------------------------------
# ESP
mkfs.vfat -n ESP -F 32 ${LOOP}p1
mkdir $ROOT/boot
mount ${LOOP}p1 $ROOT/boot

mkdir -p $ROOT/boot/EFI/Boot
cp ../boot-efi/bootx64.efi $ROOT/boot/EFI/Boot/bootx64.efi

mkdir $ROOT/boot/EFI/bus1
echo -n $(cat bus1-release) | iconv -f UTF-8 -t UTF-16LE > $ROOT/release.txt
echo -n "foo=yes quiet" | iconv -f UTF-8 -t UTF-16LE > $ROOT/options.txt

objcopy \
  --add-section .release=$ROOT/release.txt --change-section-vma .release=0x20000 \
  --add-section .options=$ROOT/options.txt --change-section-vma .options=0x30000 \
  --add-section .splash=../boot-efi/test/bus1.bmp --change-section-vma .splash=0x40000 \
  --add-section .linux=vmlinuz --change-section-vma .linux=0x2000000 \
  --add-section .initrd=initrd --change-section-vma .initrd=0x3000000 \
  ../boot-efi/stubx64.efi $ROOT/boot/EFI/bus1/$(cat bus1-release).efi

cp system.img $ROOT/boot/EFI/bus1/$(cat bus1-release).img

KEY=$(dd if=/dev/urandom bs=32 count=1 status=none | xxd --plain -c32)
echo $KEY > $ROOT/boot/EFI/bus1/bus1-key.txt

umount $ROOT/boot

# ------------------------------------------------------------------------------
# Data
../base/org.bus1.diskctl encrypt ${LOOP}p2 org.bus1.data
dmsetup create org.bus1.data --table "0 $(($(blockdev --getsz ${LOOP}p2) - 8)) crypt aes-xts-plain64 ${KEY} 0 ${LOOP}p2 8"
mkfs.xfs -L bus1 -q /dev/mapper/org.bus1.data
udevadm settle
dmsetup remove org.bus1.data

# ------------------------------------------------------------------------------
sync
rm -rf $ROOT
losetup -d $LOOP
