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
# Setup a mount namespace with a temporary / on tmpfs, extract "initrd",
# chroot to it and execute a shell inside that system.

set -x
set -e

# unshare the current directory and re-exec this script
[[ "$1" != "--init" ]] && exec unshare -m $0 --init "$1"

INITRD=$(realpath ${2:-initrd})

# root is a tmpfs
mkdir -p sysroot
mount -t tmpfs tmpfs sysroot
cd sysroot

# extract initramfs image to tmpfs
gzip -d -c < "$INITRD" | cpio -i

# kernel API filesystems
mkdir {dev,proc,sys}
mount -t devtmpfs devtmpfs dev
mount -t proc proc proc
mount -t sysfs sysfs sys

exec chroot . bash
