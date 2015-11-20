#!/bin/bash

set -x
set -e

# unshare the current directory and re-exec this script
test -z "$1" && exec unshare -m $0 init

# root is a tmpfs
mkdir -p sysroot
mount -t tmpfs tmpfs sysroot

# usr is read-only
mkdir -p sysroot/usr
mount --bind System sysroot/usr
mount -o remount,ro,bind sysroot/usr sysroot/usr

# top-level symlinks
ln -s usr/bin sysroot/bin
ln -s usr/etc sysroot/etc

# x86_64 dynloader ABI
mkdir -p sysroot/lib64
ln -s ../usr/lib/x86_64-linux-gnu/ld-linux-x86-64.so.2 sysroot/lib64/ld-linux-x86-64.so.2

# var is persistent
mkdir -p Data/var sysroot/var
mount --bind Data/var sysroot/var

# kernel API filesystems
mkdir -p sysroot/{proc,sys,dev}
mount -t proc proc sysroot/proc
mount -t sysfs sysfs sysroot/sys
mount -t devtmpfs devtmpfs sysroot/dev

exec chroot sysroot bash
