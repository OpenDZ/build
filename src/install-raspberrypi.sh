#!/bin/bash

set -e

test "$UID" == "0" || exit 1

ROOT=$(mktemp -d /tmp/install-tmpXXX)

debootstrap --variant=minbase --include=kmod,strace,procps,less sid $ROOT

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

# download kernel and binaries for /boot
git clone --depth=1 https://github.com/raspberrypi/firmware.git
git clone --depth=1 https://github.com/raspberrypi/linux.git
make -C linux KERNEL=kernel7 bcm2709_defconfig
make -C linux modules_prepare headers_install
cp firmware/extra/Module7.symvers linux/Module.symvers

# install kernel modules
mkdir -p $SYSTEM/usr/lib/modules
cp -ax firmware/modules/$(ls -1v firmware/modules/ | tail -1) $SYSTEM/usr/lib/modules

# delete cruft
rm -rf $SYSTEM/usr/{tmp,games,local}

rm -rf $ROOT
rm -rf system
mv $SYSTEM system
