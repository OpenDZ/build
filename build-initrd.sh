#!/bin/bash

set -e

test "$UID" == "0" || exit 1

ROOT=$(mktemp -d /tmp/initrd-tmpXXX)

mkdir -p $ROOT/{sys,proc,lib64}
mkdir -p $ROOT/usr/bin
mkdir -p $ROOT/usr/lib/x86_64-linux-gnu
ln -s usr/bin $ROOT/bin
ln -s ../usr/lib/x86_64-linux-gnu/ld-linux-x86-64.so.2 $ROOT/lib64/ld-linux-x86-64.so.2

mkdir -p $ROOT/etc/ld.so.conf.d/
echo "include ld.so.conf.d/*.conf" > $ROOT/etc/ld.so.conf
echo "/usr/lib/x86_64-linux-gnu" > $ROOT/etc/ld.so.conf.d/x86_64-linux-gnu.conf

cat > $ROOT/init << EOF
#!/bin/bash

mount -t proc proc /proc
mount -t sysfs sysfs /sys
mount -t devtmpfs devtmpfs /dev

echo -e "\nWelcome to bus1!\n"

exec /usr/bin/bash
EOF

chmod 0755 $ROOT/init

BINARIES="\
  bash \
  ls \
  cat \
  stat \
  mount"

# resolve and install needed libraries
cp --dereference --no-clobber /lib64/ld-linux-x86-64.so.2 $ROOT/usr/lib/x86_64-linux-gnu
for i in $BINARIES; do
  cp --dereference --no-clobber $(which $i) $ROOT/bin
  ldd $(which $i) | grep "=> /" | awk '{print $3}' | xargs -I '{}' cp --dereference --no-clobber '{}' $ROOT/usr/lib/x86_64-linux-gnu
done

ldconfig -r $ROOT

(cd $ROOT; find . | cpio --quiet -o -H newc | gzip) > initrd
rm -rf $ROOT
