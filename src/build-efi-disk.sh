#!/bin/bash

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
  --add-section .linux=linux --change-section-vma .linux=0x2000000 \
  --add-section .initrd=initrd --change-section-vma .initrd=0x3000000 \
  ../boot-efi/stubx64.efi $ROOT/boot/EFI/bus1/$(cat bus1-release).efi

umount $ROOT/boot

# ------------------------------------------------------------------------------
# System
mkdir $ROOT/system
mkfs.xfs -L bus1 -q ${LOOP}p2
mount ${LOOP}p2 $ROOT/system

mkdir -p $ROOT/system/{system,data}
cp system.img $ROOT/system/system/$(cat bus1-release).img

umount $ROOT/system

# ------------------------------------------------------------------------------
sync
rm -rf $ROOT
losetup -d $LOOP
