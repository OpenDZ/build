#!/bin/bash

set -e

test -e System && exit 1
test "$UID" == "0" || exit 1

ROOT=$(mktemp /tmp/install-tmpXXX)

rm -rf $ROOT

# move etc into usr
mkdir -p $ROOT/usr/etc
ln -s usr/etc $ROOT/etc

# move $libdir to multilib tuple dir
mkdir -p $ROOT/usr/lib/x86_64-linux-gnu
ln -s lib/x86_64-linux-gnu $ROOT/usr/lib64
ln -s usr/lib/x86_64-linux-gnu $ROOT/lib64

debootstrap --variant=minbase sid $ROOT

# merge sbin into bin
find $ROOT/usr/sbin -type f | xargs mv --no-clobber -t $ROOT/usr/bin
find $ROOT/sbin -type f | xargs mv --no-clobber -t $ROOT/usr/bin
find $ROOT/bin -type f | xargs mv --no-clobber -t $ROOT/usr/bin
rsync -a --ignore-existing $ROOT/lib/ $ROOT/usr/lib/

rm -rf $ROOT/usr/sbin
ln -s bin $ROOT/usr/sbin

# delete cruft
rm -rf $ROOT/usr/{tmp,games,local}

# copy usr
mv $ROOT/usr System
rm -rf $ROOT
