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
# Download ARCH Linux to the "system" directory. The  entire system is
# contained in a single /usr directory. /etc moved to /usr/etc.
#
# The development headers of the installed kernel are stored in
# "linux". The kernel image is stored as "vmlinuz".

set -e

test "$UID" == "0" || exit 1

# ------------------------------------------------------------------------------
ROOT=$(mktemp -d /tmp/install-tmpXXX)

# this command might require setup with "sudo pacman-key --populate"
pacstrap -c -d $ROOT base linux-headers

# remove kernel modules magic
rm -rf $ROOT/usr/lib/modules/*extramodules*
rm -rf $ROOT/usr/lib/depmod.d/search.conf

# copy usr
SYSTEM=$(mktemp -d system-tmpXXX)
cp -ax $ROOT/usr $SYSTEM

# copy etc into usr
cp -ax $ROOT/etc $SYSTEM/usr
rm -f $SYSTEM/usr/etc/{resolv.conf,machine-id,mtab,hostname,localtime}

# unfortunately /usr/lib/<pkg> and $libdir/<library>.so files are dumped into
# the same directory and cannot be separated here
ln -s . $SYSTEM/usr/lib/x86_64-linux-gnu

# ------------------------------------------------------------------------------
# copy kernel
cp $ROOT/boot/vmlinuz-linux vmlinuz

# copy kernel headers
rm -rf linux
KVERSION=$(ls -1 $ROOT/usr/lib/modules | tail -1)
cp -ax --dereference $ROOT/usr/lib/modules/$KVERSION/build linux

# ------------------------------------------------------------------------------
# delete cruft
rm -rf $SYSTEM/usr/local

rm -rf $ROOT
rm -rf system
mv $SYSTEM system
chmod 0755 system
