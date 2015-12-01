#!/bin/bash

set -e

test -e System && exit 1
test "$UID" == "0" || exit 1

# ------------------------------------------------------------------------------
ROOT=$(mktemp -d /tmp/install-tmpXXX)
SYSTEM=$(mktemp -d system-tmpXXX)

for i in dev sys run proc; do
    mkdir $ROOT/$i
    mount --bind /$i $ROOT/$i
done

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
  xfsprogs \
  less \
  vim

# move $libdir to multilib tuple dir
echo "/usr/lib/x86_64-linux-gnu" > $ROOT/etc/ld.so.conf.d/x86_64-linux-gnu.conf
mv $ROOT/usr/lib64 $ROOT/usr/lib/x86_64-linux-gnu
ln -s lib/x86_64-linux-gnu $ROOT/usr/lib64
$ROOT/usr/sbin/ldconfig -r $ROOT

# copy usr (without the packages the kernel package pulls in)
cp -ax $ROOT/usr/* $SYSTEM
rm -f $SYSTEM/lib64

# copy etc into usr
cp -ax $ROOT/etc $SYSTEM

# merge sbin into bin
mv --no-clobber $SYSTEM/sbin/* $SYSTEM/bin
rm -rf $SYSTEM/sbin
ln -s bin $SYSTEM/sbin

# delete cruft
rm -rf $SYSTEM/{tmp,games,local}

# ------------------------------------------------------------------------------
# install kernel
dnf -y --nogpg \
  --installroot=$ROOT \
  --releasever=rawhide --disablerepo='*' \
  --enablerepo=fedora --enablerepo=fedora-rawhide-kernel-nodebug install \
  --exclude grubby \
  kernel

# copy kernel and firmware to usr
mv $ROOT/usr/lib/modules $SYSTEM/lib
mv $ROOT/usr/lib/firmware $SYSTEM/lib

# ------------------------------------------------------------------------------
for i in dev sys run proc; do
    umount $ROOT/$i
done

rm -rf $ROOT
rm -rf system
mv $SYSTEM system
