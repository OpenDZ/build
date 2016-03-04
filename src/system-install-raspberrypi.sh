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
# The Raspberry Pi 2 kernel sources are stored in "linux". The kernel and boot loader
# are stored in "firmware".

set -e

test "$UID" == "0" || exit 1

# ------------------------------------------------------------------------------
ROOT=$(mktemp -d /tmp/install-tmpXXX)

debootstrap --variant=minbase --include=usrmerge,kmod,strace,procps,less,vim,libdw1,libelf1 sid $ROOT

# copy usr
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

rsync -a $SYSTEM/usr/lib/terminfo/ $SYSTEM/usr/share/terminfo/
rm -rf $SYSTEM/usr/lib/terminfo/

# ------------------------------------------------------------------------------
# download kernel and binaries for /boot
git clone --depth=1 --branch=next https://github.com/raspberrypi/firmware.git
git clone --depth=1 --branch=rpi-4.4.y https://github.com/raspberrypi/linux.git
make -j4 -C linux KERNEL=kernel7 bcm2709_defconfig
make -j4 -C linux modules_prepare headers_install
cp firmware/extra/Module7.symvers linux/Module.symvers

# build the missing modules
sed -i 's/.*CONFIG_DM_VERITY.*/CONFIG_DM_VERITY=m/' linux/.config
make -C linux silentoldconfig
make -j4 -C linux M=drivers/md

KVERSION=$(ls -1v firmware/modules/ | tail -1)

# install kernel modules
mkdir -p $SYSTEM/usr/lib/modules
cp -ax firmware/modules/$KVERSION $SYSTEM/usr/lib/modules
cp linux/drivers/md/dm-{bufio,verity}.ko $SYSTEM/usr/lib/modules/$KVERSION/kernel/drivers/md

# ------------------------------------------------------------------------------
# delete cruft
rm -rf $SYSTEM/usr/{tmp,games,local}
rm -rf $SYSTEM/usr/{lib32,libx32,lib64}

rm -rf $ROOT
rm -rf system
mv $SYSTEM system
chmod 0755 system
