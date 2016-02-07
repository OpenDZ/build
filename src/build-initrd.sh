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
# Extract binaries, libraries, kernel modules from "system.img"
# file and and create the initramfs image "initrd".

set -e
test "$UID" == "0" || exit 1

# https://wiki.debian.org/Multiarch/Tuples
if [[ "$HOSTTYPE" == "x86_64" ]] ; then
  DYNLOADER=ld-linux-x86-64.so.2
  DYNLOADER_ABI_DIR=lib64
  ARCHITECTURE_TUPLE=x86_64-linux-gnu
elif [[ "$HOSTTYPE" == "arm" ]] ; then
  DYNLOADER=ld-linux-armhf.so.3
  DYNLOADER_ABI_DIR=lib
  ARCHITECTURE_TUPLE=arm-linux-gnueabihf
else
  echo "Unknown HOSTTYPE"
  exit 1
fi

# ------------------------------------------------------------------------------
# modprobe is called by the kernel itself
BINARIES="\
  org.bus1.rdinit \
  org.bus1.activator \
  org.bus1.devices \
  org.bus1.init \
  modprobe"

# only needed for debugging
BINARIES="$BINARIES \
  bash \
  sh \
  ls \
  cat \
  ln \
  mkdir \
  ps \
  top \
  ldd \
  dmesg \
  lsmod \
  chroot \
  strace \
  df \
  stat \
  losetup \
  less \
  grep \
  mount \
  umount"

# xfs needs crc32c which is not pulled-in
MODULES="\
  bus1 \
  dm_mod \
  dm_verity \
  dm_crypt \
  xfs \
  btrfs \
  squashfs \
  vfat \
  loop \
  crc32c_generic \
  sd_mod \
  ata_piix \
  usb_storage"

DIRECTORIES="\
  /usr/share/terminfo/l"

# ------------------------------------------------------------------------------
copy() {
  local root=$1
  local from=$2
  local to=$3

  mkdir -p $(dirname "$to")
  cp --no-dereference --no-clobber "$root$from" "$to"
  [[ -L "$root$from" ]] && cp --no-clobber $root$(chroot "$root" readlink -e "$from") "$to"
  return 0
}

copy_libs() {
  local root=$1
  local binary=$2
  local to=$3

  (chroot "$root" ldd "$binary") | ( while read line || [[ -n "$line" ]]; do
    set -- $line
    while (( $# > 0 )); do
      a=$1
      shift
      [[ $a == '=>' ]] || continue
      break
    done
    [[ -z $1 ]] || copy "$root" "$1" "$to"
  done )
}

# ------------------------------------------------------------------------------
# mount system image to copy files from
mkdir -p sysroot
mount -ttmpfs tmpfs sysroot
mkdir -p sysroot/usr
mount -tsquashfs system.img sysroot/usr
ln -s usr/bin sysroot/bin
ln -s usr/etc sysroot/etc
ln -s usr/lib sysroot/lib
if [[ "$DYNLOADER_ABI_DIR" != "lib" ]]; then
  mkdir -p sysroot/$DYNLOADER_ABI_DIR
  ln -s ../usr/lib/$ARCHITECTURE_TUPLE/$DYNLOADER sysroot/$DYNLOADER_ABI_DIR/$DYNLOADER
fi

# ------------------------------------------------------------------------------
# base filesystem
ROOT=$(mktemp -d /tmp/initrd-tmpXXX)

mkdir -p $ROOT/usr/bin
ln -s usr/bin $ROOT/bin
ln -s usr/bin $ROOT/sbin
ln -s usr/lib $ROOT/lib
mkdir -p $ROOT/usr/lib/$ARCHITECTURE_TUPLE
if [[ "$DYNLOADER_ABI_DIR" != "lib" ]]; then
  mkdir -p $ROOT/$DYNLOADER_ABI_DIR
  ln -s ../usr/lib/$ARCHITECTURE_TUPLE/$DYNLOADER $ROOT/$DYNLOADER_ABI_DIR/$DYNLOADER
else
  ln -s $ARCHITECTURE_TUPLE/$DYNLOADER $ROOT/usr/lib/$DYNLOADER
fi

mkdir -m 01777 $ROOT/tmp
mkdir $ROOT/var

mkdir -p $ROOT/usr/etc/ld.so.conf.d/
echo "include ld.so.conf.d/*.conf" > $ROOT/usr/etc/ld.so.conf
echo "/usr/lib/$ARCHITECTURE_TUPLE" > $ROOT/usr/etc/ld.so.conf.d/$ARCHITECTURE_TUPLE.conf
ln -s usr/etc $ROOT/etc

# org.bus1.rdinit uses release string to find the corresponding system.img
mkdir -p $ROOT/usr/lib/org.bus1
cp sysroot/usr/lib/org.bus1/* $ROOT/usr/lib/org.bus1

# the kernel executes /init
ln -s usr/bin/org.bus1.rdinit $ROOT/init

# ------------------------------------------------------------------------------
# resolve and install needed libraries
copy sysroot /$DYNLOADER_ABI_DIR/$DYNLOADER $ROOT/usr/lib/$ARCHITECTURE_TUPLE

for i in $BINARIES; do
  copy sysroot /usr/bin/$i $ROOT/usr/bin
  copy_libs sysroot /usr/bin/$i $ROOT/usr/lib/$ARCHITECTURE_TUPLE
done

ldconfig -r $ROOT

# ------------------------------------------------------------------------------
# copy entire directories
for i in $DIRECTORIES; do
  mkdir -p $ROOT/$i
  cp -ax sysroot$i/* $ROOT$i
done

# ------------------------------------------------------------------------------
# copy kernel modules and their dependencies
KVERSION=$(ls -1 sysroot/usr/lib/modules | tail -1)

for i in $MODULES; do
  chroot sysroot modprobe --set-version=$KVERSION --show-depends --ignore-install $i | (while read cmd path options || [ -n "$cmd" ]; do
    [[ "$cmd" == 'insmod' ]] || continue
    copy sysroot "$path" "$ROOT$path"
  done )
done

cp sysroot/lib/modules/$KVERSION/modules.order $ROOT/lib/modules/$KVERSION
cp sysroot/lib/modules/$KVERSION/modules.builtin $ROOT/lib/modules/$KVERSION

depmod -a -b $ROOT $KVERSION

# ------------------------------------------------------------------------------
(cd $ROOT; find . | cpio --quiet -o -H newc | gzip) > initrd
[[ ! "$1" == "t" ]] || tree $ROOT

umount sysroot/usr
umount sysroot
rm -rf $ROOT
