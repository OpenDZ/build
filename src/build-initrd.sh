#!/bin/bash

set -e
test "$UID" == "0" || exit 1

# ------------------------------------------------------------------------------
BINARIES="\
  org.bus1.rdinit \
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
  losetup \
  less \
  grep \
  mount"

MODULES="\
  bus1 \
  xfs \
  squashfs \
  vfat \
  loop \
  usb_storage"

DIRECTORIES="\
  /usr/share/terminfo/l"

# ------------------------------------------------------------------------------
copy() {
  local from=$1
  local to=$2

  mkdir -p $(dirname "$to")
  cp --no-dereference --no-clobber "$from" "$to"
  test -L "$from" && cp --no-clobber $(readlink -f "$from") "$to"
  return 0
}

copy_libs() {
  local binary=$1
  local root=$2

  ( if [[ -n "$root" ]]; then
    chroot "$root" ldd "$binary"
  else
    ldd "$binary"
  fi ) | ( while read line || [[ -n "$line" ]]; do
    set -- $line
    while (( $# > 0 )); do
      a=$1
      shift
      [[ $a == '=>' ]] || continue
      break
    done
    [[ -z $1 ]] || copy "$root/$1" $ROOT/usr/lib/x86_64-linux-gnu
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
mkdir -p sysroot/lib64
ln -s ../usr/lib/x86_64-linux-gnu/ld-linux-x86-64.so.2 sysroot/lib64/ld-linux-x86-64.so.2

# ------------------------------------------------------------------------------
ROOT=$(mktemp -d /tmp/initrd-tmpXXX)

mkdir -p $ROOT/usr/bin
ln -s usr/bin $ROOT/bin
ln -s usr/bin $ROOT/sbin
ln -s usr/lib $ROOT/lib
mkdir -p $ROOT/usr/lib/x86_64-linux-gnu
mkdir -p $ROOT/lib64
ln -s ../usr/lib/x86_64-linux-gnu/ld-linux-x86-64.so.2 $ROOT/lib64/ld-linux-x86-64.so.2

mkdir -p $ROOT/etc/ld.so.conf.d/
echo "include ld.so.conf.d/*.conf" > $ROOT/etc/ld.so.conf
echo "/usr/lib/x86_64-linux-gnu" > $ROOT/etc/ld.so.conf.d/x86_64-linux-gnu.conf

cp sysroot/usr/etc/bus1-release $ROOT/etc/bus1-release
cp sysroot/usr/etc/bus1-release bus1-release

# ------------------------------------------------------------------------------
# the kernel executes /init
ln -s usr/bin/org.bus1.rdinit $ROOT/init

# ------------------------------------------------------------------------------
# resolve and install needed libraries
copy sysroot/lib64/ld-linux-x86-64.so.2 $ROOT/usr/lib/x86_64-linux-gnu

for i in $BINARIES; do
  copy sysroot/usr/bin/$i $ROOT/usr/bin
  copy_libs /usr/bin/$i sysroot
done

ldconfig -r $ROOT

# ------------------------------------------------------------------------------
# copy entire directories
for i in $DIRECTORIES; do
  mkdir -p $ROOT/$i
  cp -ax $i/* $ROOT$i
done

# ------------------------------------------------------------------------------
# copy kernel modules and their dependencies
KVERSION=$(ls -1 sysroot/usr/lib/modules | tail -1)

for i in $MODULES; do
  chroot sysroot modprobe --set-version=$KVERSION --show-depends --ignore-install $i | (while read cmd path options || [ -n "$cmd" ]; do
    copy sysroot$path "$ROOT$path"
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
