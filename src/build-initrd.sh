#!/bin/bash

set -e
test "$UID" == "0" || exit 1

# ------------------------------------------------------------------------------
BINARIES="\
  bash \
  sh \
  ls \
  cat \
  stat \
  ln \
  mkdir \
  ldd \
  dmesg \
  modprobe \
  lsmod \
  chroot \
  strace \
  setsid \
  losetup \
  mount"

MODULES="\
  xfs
  squashfs \
  vfat \
  loop"

# ------------------------------------------------------------------------------
copy() {
  mkdir -p "$2"
  cp --no-dereference --no-clobber "$1" "$2"
  test -L "$1" && cp --no-clobber $(readlink -f "$1") "$2"
  return 0
}

# ------------------------------------------------------------------------------
mkdir -p sysroot
mount -ttmpfs tmpfs sysroot
mkdir -p sysroot/usr
mount -tsquashfs system.img sysroot/usr
ln -s usr/bin sysroot/bin
ln -s usr/etc sysroot/etc
mkdir -p sysroot/lib64
ln -s ../usr/lib/x86_64-linux-gnu/ld-linux-x86-64.so.2 sysroot/lib64/ld-linux-x86-64.so.2

# ------------------------------------------------------------------------------
ROOT=$(mktemp -d /tmp/initrd-tmpXXX)

mkdir -p $ROOT/{sys,proc,lib64}
mkdir -p $ROOT/usr/bin
mkdir -p $ROOT/usr/lib/x86_64-linux-gnu
ln -s usr/bin $ROOT/bin
ln -s usr/bin $ROOT/sbin
ln -s ../usr/lib/x86_64-linux-gnu/ld-linux-x86-64.so.2 $ROOT/lib64/ld-linux-x86-64.so.2

mkdir -p $ROOT/etc/ld.so.conf.d/
echo "include ld.so.conf.d/*.conf" > $ROOT/etc/ld.so.conf
echo "/usr/lib/x86_64-linux-gnu" > $ROOT/etc/ld.so.conf.d/x86_64-linux-gnu.conf

# ------------------------------------------------------------------------------
cat > $ROOT/init << EOF
#!/bin/bash

set -e

mount -t proc -o nosuid,noexec,nodev proc /proc
mount -t sysfs -o nosuid,noexec,nodev sysfs /sys
mount -t devtmpfs -o mode=0755,noexec,nosuid,strictatime devtmpfs /dev
ln -s /proc/self/fd /dev/fd
ln -s /proc/self/fd/0 /dev/stdin
ln -s /proc/self/fd/1 /dev/stdout
ln -s /proc/self/fd/2 /dev/stderr
mkdir -m 0755 /dev/pts
mount -t devpts -o gid=5,mode=620,noexec,nosuid devpts /dev/pts
mkdir -m 0755 /dev/shm
mount -t tmpfs -o mode=1777,noexec,nosuid,nodev,strictatime tmpfs /dev/shm
mkdir -m 0755 /run
mount -t tmpfs -o mode=0755,noexec,nosuid,nodev,strictatime tmpfs /run

echo -e "\nWelcome to bus1!\n"

modprobe loop
mkdir -p /mnt
mount /dev/sda2 /mnt

mkdir -p /sysroot/{usr,dev,proc,sys,run,var}
mount -tsquashfs /mnt/System/system.img sysroot/usr

ln -s usr/etc sysroot/etc
ln -s usr/bin sysroot/bin
ln -s usr/bin sysroot/sbin
mkdir -p sysroot/lib64
ln -s ../usr/lib/x86_64-linux-gnu/ld-linux-x86-64.so.2 sysroot/lib64/ld-linux-x86-64.so.2

mount --bind /mnt/Data sysroot/var

mount --move /dev sysroot/dev
mount --move /sys sysroot/sys
mount --move /run sysroot/run
mount --move /proc sysroot/proc

exec chroot sysroot /usr/bin/setsid -c /usr/bin/bash -i
EOF

chmod 0755 $ROOT/init

# ------------------------------------------------------------------------------
# resolve and install needed libraries
copy sysroot/lib64/ld-linux-x86-64.so.2 $ROOT/usr/lib/x86_64-linux-gnu

for i in $BINARIES; do
  copy sysroot/usr/bin/$i $ROOT/usr/bin

  chroot sysroot ldd /usr/bin/$i | ( while read line || [[ -n "$line" ]]; do
    set -- $line
    while (( $# > 0 )); do
      a=$1
      shift
      [[ $a == '=>' ]] || continue
      break
    done
    [[ -z $1 ]] || copy sysroot/$1 $ROOT/usr/lib/x86_64-linux-gnu
  done )
done

ldconfig -r $ROOT

# ------------------------------------------------------------------------------
for i in $MODULES; do
  modprobe --show-depends --ignore-install $i | (while read cmd path options || [ -n "$cmd" ]; do
    copy "$path" "$ROOT$path"
  done )
done

copy /lib/modules/$(uname -r)/modules.order $ROOT/lib/modules/$(uname -r)
copy /lib/modules/$(uname -r)/modules.builtin $ROOT/lib/modules/$(uname -r)

depmod -a -b $ROOT

# ------------------------------------------------------------------------------
(cd $ROOT; find . | cpio --quiet -o -H newc | gzip) > initrd
[[ ! "$1" == "t" ]] || tree $ROOT

umount sysroot/usr
umount sysroot
rm -rf $ROOT
