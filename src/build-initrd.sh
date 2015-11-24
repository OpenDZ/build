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
  modprobe \
  lsmod \
  mount"

MODULES="\
  btrfs
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

exec /usr/bin/bash
EOF

chmod 0755 $ROOT/init

# ------------------------------------------------------------------------------
# resolve and install needed libraries
copy /lib64/ld-linux-x86-64.so.2 $ROOT/usr/lib/x86_64-linux-gnu

for i in $BINARIES; do
  copy $(which $i) $ROOT/bin

  ldd $(type -P $i) | ( while read line || [[ -n "$line" ]]; do
    set -- $line
    while (( $# > 0 )); do
      a=$1
      shift
      [[ $a == '=>' ]] || continue
      break
    done
    [[ ! -e "$1" ]] || copy "$1" $ROOT/usr/lib/x86_64-linux-gnu
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
rm -rf $ROOT
