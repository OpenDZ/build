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
# Download Fedora rawhide to the "system" directory. The
# entire system is contained in a single /usr directory:
# - move /etc to /usr/etc
# - merge /usr/bin and /usr/sbin
# - $libdir is https://wiki.debian.org/Multiarch/Tuples
#
# The development headers of the installed kernel are stored in
# "linux". The kernel image is stored as "vmlinuz".

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
  elfutils-libs \
  less \
  vim

# move $libdir to multilib tuple dir
echo "/usr/lib/x86_64-linux-gnu" > $ROOT/etc/ld.so.conf.d/x86_64-linux-gnu.conf
mv $ROOT/usr/lib64 $ROOT/usr/lib/x86_64-linux-gnu
ln -s ../lib/x86_64-linux-gnu $ROOT/usr/lib64
$ROOT/usr/sbin/ldconfig -r $ROOT

# copy usr (without the packages the kernel package pulls in)
SYSTEM=$(mktemp -d system-tmpXXX)
cp -ax $ROOT/usr $SYSTEM

# copy etc into usr
cp -ax $ROOT/etc $SYSTEM/usr
rm -f $SYSTEM/usr/etc/{resolv.conf,machine-id,mtab,hostname,localtime}

# merge sbin into bin
mkdir $SYSTEM/usr/bin.new
find $SYSTEM/usr/bin -type f -print0 | xargs -0 -r cp --no-clobber -t $SYSTEM/usr/bin.new --
find $SYSTEM/usr/sbin -type f -print0 | xargs -0 -r cp --no-clobber -t $SYSTEM/usr/bin.new --
rsync -a --ignore-existing $SYSTEM/usr/bin/ $SYSTEM/usr/bin.new/
rsync -a --ignore-existing $SYSTEM/usr/sbin/ $SYSTEM/usr/bin.new/
rm -rf $SYSTEM/usr/bin
mv $SYSTEM/usr/bin.new $SYSTEM/usr/bin
rm -rf $SYSTEM/usr/sbin
ln -s bin $SYSTEM/usr/sbin

# delete cruft
rm -rf $SYSTEM/usr/{src,tmp,games,local}

# ------------------------------------------------------------------------------
# install kernel
dnf -y --nogpg \
  --installroot=$ROOT \
  --releasever=rawhide --disablerepo='*' \
  --enablerepo=fedora install \
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
rm -rf linux
cp -ax $ROOT/usr/src/kernels/$KVERSION linux

# ------------------------------------------------------------------------------
for i in dev sys run proc; do
    umount $ROOT/$i
done

rm -rf $ROOT
rm -rf system
mv $SYSTEM system
chmod 0755 system
