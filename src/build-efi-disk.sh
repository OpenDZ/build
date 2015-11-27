#!/bin/bash

set -e

# ------------------------------------------------------------------------------
ROOT=$(mktemp -d /tmp/efi-tmpXXX)

# create GPT table with EFI System Partition
rm -f efi-disk.img
dd if=/dev/null of=efi-disk.img bs=1M seek=1024 count=1
parted --script efi-disk.img \
  "mklabel gpt" \
  "mkpart ESP fat32 1MiB 511MiB" \
  "set 1 boot on" \
  "mkpart bus1 ext4 512MiB 1023MiB"

LOOP=$(losetup --show -f -P efi-disk.img)
# ------------------------------------------------------------------------------
# ESP
mkfs.vfat -F32 ${LOOP}p1
mkdir $ROOT/boot
mount ${LOOP}p1 $ROOT/boot

mkdir -p $ROOT/boot/EFI/Boot
cp ../boot-efi/bootx64.efi $ROOT/boot/EFI/Boot/bootx64.efi

mkdir $ROOT/boot/EFI/bus1
echo -n "bus1-0815" | iconv -f UTF-8 -t UTF-16LE > $ROOT/release.txt
echo -n "foo=yes quiet" | iconv -f UTF-8 -t UTF-16LE > $ROOT/options.txt

linux=linux
test -e "$linux" || linux=/boot/$(cat /etc/machine-id)/$(uname -r)/linux
test -e "$linux" || linux=/vmlinuz
test -e "$linux" || exit 1

objcopy \
  --add-section .release=$ROOT/release.txt --change-section-vma .release=0x20000 \
  --add-section .options=$ROOT/options.txt --change-section-vma .options=0x30000 \
  --add-section .splash=../boot-efi/test/bus1.bmp --change-section-vma .splash=0x40000 \
  --add-section .linux=$linux --change-section-vma .linux=0x2000000 \
  --add-section .initrd=initrd --change-section-vma .initrd=0x3000000 \
  ../boot-efi/stubx64.efi $ROOT/boot/EFI/bus1/bus1.efi

umount $ROOT/boot

# ------------------------------------------------------------------------------
# System
mkdir $ROOT/system
mkfs.xfs -q ${LOOP}p2
mount ${LOOP}p2 $ROOT/system

mkdir -p $ROOT/system/{system,data}
cp system.img $ROOT/system/system

umount $ROOT/system

# ------------------------------------------------------------------------------
sync
rm -rf $ROOT
losetup -d $LOOP
