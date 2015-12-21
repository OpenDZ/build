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
# Download Debian sid to the "system" directory. The
# entire system is contained in a single /usr directory:
# - move /etc to /usr/etc
# - merge /usr/bin and /usr/sbin
#
# The development headers of the installed kernel are stored in
# "linux". The kernel image is stored as "vmlinuz".

set -e

test "$UID" == "0" || exit 1

# ------------------------------------------------------------------------------
ROOT=$(mktemp -d /tmp/install-tmpXXX)

debootstrap --variant=minbase --include=linux-image-amd64,linux-headers-amd64,kmod,strace,less sid $ROOT

# copy usr
SYSTEM=$(mktemp -d system-tmpXXX)
cp -ax $ROOT/usr $SYSTEM

# copy etc into usr
cp -ax $ROOT/etc $SYSTEM/usr
rm -f $SYSTEM/usr/etc/{resolv.conf,machine-id,mtab,hostname,localtime}

# merge /bin, /sbin, /usr/sbin into /usr/bin
mkdir $SYSTEM/usr/bin.new
find $SYSTEM/usr/bin -type f -print0 | xargs -0 -r cp --no-clobber -t $SYSTEM/usr/bin.new --
find $SYSTEM/usr/sbin -type f -print0 | xargs -0 -r cp --no-clobber -t $SYSTEM/usr/bin.new --
find $ROOT/sbin -type f -print0 | xargs -0 -r cp --no-clobber -t $SYSTEM/usr/bin.new --
find $ROOT/bin -type f -print0 | xargs -0 -r cp --no-clobber -t $SYSTEM/usr/bin.new --
# symlinks
rsync -a --ignore-existing $SYSTEM/usr/bin/ $SYSTEM/usr/bin.new/
rsync -a --ignore-existing $SYSTEM/usr/sbin/ $SYSTEM/usr/bin.new/
rsync -a --ignore-existing $ROOT/sbin/ $SYSTEM/usr/bin.new/
rsync -a --ignore-existing $ROOT/bin/ $SYSTEM/usr/bin.new/
rm -rf $SYSTEM/usr/bin
mv $SYSTEM/usr/bin.new $SYSTEM/usr/bin
rm -rf $SYSTEM/usr/sbin
ln -s bin $SYSTEM/usr/sbin

# merge lib into /usr/lib
rsync -a --ignore-existing $ROOT/lib/ $SYSTEM/usr/lib/

rsync -a $SYSTEM/usr/lib/terminfo/ $SYSTEM/usr/share/terminfo/
rm -rf $SYSTEM/usr/lib/terminfo/

KVERSION=$(ls -1 $ROOT/lib/modules | tail -1)

# ------------------------------------------------------------------------------
# copy kernel
cp $ROOT/boot/vmlinuz-$KVERSION vmlinuz

# copy kernel headers
rm -rf linux
cp -ax --dereference $ROOT/usr/src/linux-headers-$KVERSION linux
rsync -a --exclude scripts $ROOT/usr/src/linux-headers-${KVERSION%-*}-common/ linux/

# ------------------------------------------------------------------------------
# delete cruft
rm -rf $SYSTEM/usr/{tmp,games,local}

rm -rf $ROOT
rm -rf system
mv $SYSTEM system
