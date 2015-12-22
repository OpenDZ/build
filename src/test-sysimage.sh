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
# Setup a mount namespace with a temporary / on tmpfs, mount "systemd.img"
# at /usr and execute a shell inside that system.

set -x
set -e

# unshare the current directory and re-exec this script
test -z "$1" && exec unshare -m $0 init

# root is a tmpfs
mkdir -p sysroot
mount -t tmpfs tmpfs sysroot
cd sysroot

# usr is read-only
mkdir -p usr
mount -tsquashfs ../system.img usr

# top-level symlinks
ln -s usr/bin bin
ln -s usr/etc etc

# x86_64 dynloader ABI
if [[ "$HOSTTYPE" == "x86_64" ]] ; then
  mkdir -p lib64
  ln -s ../usr/lib/x86_64-linux-gnu/ld-linux-x86-64.so.2 lib64/ld-linux-x86-64.so.2
fi

# var is persistent
mkdir -p {../data,var}
mount --bind ../data var

# kernel API filesystems
mkdir -p {proc,sys,dev}
mount -t proc proc proc
mount -t sysfs sysfs sys
mount -t devtmpfs devtmpfs dev

exec chroot . bash
