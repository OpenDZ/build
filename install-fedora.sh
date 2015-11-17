#!/bin/bash

set -e

test -e System && exit 1
test "$UID" == "0" || exit 1

ROOT=$(mktemp $PWD/install-tmpXXX)

rm -rf $ROOT

# move etc into usr
mkdir -p $ROOT/usr/etc
ln -s usr/etc $ROOT/etc

# move $libdir to multilib tuple dir
mkdir -p $ROOT/usr/lib/x86_64-linux-gnu
ln -s lib/x86_64-linux-gnu $ROOT/usr/lib64
ln -s usr/lib/x86_64-linux-gnu $ROOT/lib64

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
  less \
  vim

# merge sbin into bin
mv --no-clobber $ROOT/usr/sbin/* $ROOT/usr/bin
rm -rf $ROOT/usr/sbin
ln -s bin $ROOT/usr/sbin

# delete cruft
rm -rf $ROOT/usr/{tmp,games,local}

# copy usr
mv $ROOT/usr System
rm -rf $ROOT
