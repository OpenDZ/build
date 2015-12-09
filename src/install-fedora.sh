#!/bin/bash

set -e

test "$UID" == "0" || exit 1

# ------------------------------------------------------------------------------
ROOT=$(mktemp -d /tmp/install-tmpXXX)

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
SYSTEM=$(mktemp -d system-tmpXXX)
cp -ax $ROOT/usr $SYSTEM
rm -f $SYSTEM/usr/lib64

# copy etc into usr
cp -ax $ROOT/etc $SYSTEM/usr
rm -f $SYSTEM/usr/etc/{resolv.conf,machine-id,mtab,hostname,localtime}

# merge sbin into bin
mv --no-clobber $SYSTEM/usr/sbin/* $SYSTEM/usr/bin
rm -rf $SYSTEM/usr/sbin
ln -s bin $SYSTEM/usr/sbin

# delete cruft
rm -rf $SYSTEM/usr/{src,tmp,games,local}

# ------------------------------------------------------------------------------
# install kernel
dnf -y --nogpg \
  --installroot=$ROOT \
  --releasever=rawhide --disablerepo='*' \
  --enablerepo=fedora --enablerepo=fedora-rawhide-kernel-nodebug install \
  --exclude grubby \
  kernel kernel-devel

KVERSION=$(ls -1 $ROOT/usr/lib/modules | tail -1)

# copy kernel
mv $ROOT/usr/lib/modules/$KVERSION/vmlinuz vmlinuz

# copy kernel modules and firmware to usr
mkdir -p $SYSTEM/usr/lib/modules/
mv $ROOT/usr/lib/modules/$KVERSION $SYSTEM/usr/lib/modules/$KVERSION
mv $ROOT/usr/lib/firmware $SYSTEM/usr/lib/firmware

# copy kernel headers
rm -rf kernel-headers
cp -ax $ROOT/usr/src/kernels/$KVERSION kernel-headers

# ------------------------------------------------------------------------------
for i in dev sys run proc; do
    umount $ROOT/$i
done

rm -rf $ROOT
rm -rf system
mv $SYSTEM system
