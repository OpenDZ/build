#!/bin/bash

set -e

test -e System && exit 1
test "$UID" == "0" || exit 1

# ------------------------------------------------------------------------------
ROOT=$(mktemp -d /tmp/install-tmpXXX)

# install rawhide packages
dnf -y --nogpg \
  --installroot=$ROOT \
  --releasever=rawhide --disablerepo='*' --enablerepo=fedora install \
  util-linux \
  coreutils \
  findutils \
  tree \
  strace \
  procps-ng \
  kmod \
  less \
  vim

# move $libdir to multilib tuple dir
echo "/usr/lib/x86_64-linux-gnu" > $ROOT/etc/ld.so.conf.d/x86_64-linux-gnu.conf
mv $ROOT/usr/lib64 $ROOT/usr/lib/x86_64-linux-gnu
ln -s lib/x86_64-linux-gnu $ROOT/usr/lib64
$ROOT/usr/sbin/ldconfig -r $ROOT

# copy usr (without the packages the kernel package pulls in)
cp -axl $ROOT/usr $ROOT/system
rm -f $ROOT/system/lib64

# copy etc into usr
cp -axl $ROOT/etc $ROOT/system/

# merge sbin into bin
mv --no-clobber $ROOT/system/sbin/* $ROOT/system/bin
rm -rf $ROOT/system/sbin
ln -s bin $ROOT/system/sbin

# delete cruft
rm -rf $ROOT/system/{tmp,games,local}

# ------------------------------------------------------------------------------
# install kernel
dnf -y --nogpg \
  --installroot=$ROOT \
  --releasever=rawhide --disablerepo='*' \
  --enablerepo=fedora --enablerepo=fedora-rawhide-kernel-nodebug install \
  kernel

# copy kernel and firmware to usr
mv $ROOT/usr/lib/modules $ROOT/system/lib
mv $ROOT/usr/lib/firmware $ROOT/system/lib

# ------------------------------------------------------------------------------
rm -f system.img
mksquashfs $ROOT/system system.img
rm -rf $ROOT
