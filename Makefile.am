ACLOCAL_AMFLAGS = -I m4 ${ACLOCAL_FLAGS}
AM_MAKEFLAGS = --no-print-directory
AUTOMAKE_OPTIONS = color-tests parallel-tests

GCC_COLORS ?= 'ooh, shiny!'
export GCC_COLORS

CLEANFILES =

# ------------------------------------------------------------------------------
CLEANFILES += \
  system.img \
  initrd \
  efi-disk.img

all: test-efi

system:
	src/install-$$(. /etc/os-release; echo $$ID).sh
	echo bus1-$$(date +%s) > system/usr/etc/bus1-release

system/usr/bin/org.bus1.rdinit: system ../init/org.bus1.rdinit
	make install -C ../init DESTDIR=$$PWD/system

system/usr/bin/bus1ctl: system ../libbus1/bus1ctl
	make install -C ../libbus1 DESTDIR=$$PWD/system

system.img: system system/usr/bin/org.bus1.rdinit system/usr/bin/bus1ctl
	rm -rf system/usr/include
	find system/usr -type f -name "*.la" -delete
	rm -f system.img
	mksquashfs system/usr system.img
.DELETE_ON_ERROR: system.img

initrd: src/build-initrd.sh ../init/org.bus1.rdinit ../init/org.bus1.devices
	src/build-initrd.sh
.DELETE_ON_ERROR: initrd

efi-disk.img: $(stub) src/build-efi-disk.sh ../boot-efi/bootx64.efi ../boot-efi/stubx64.efi system.img initrd linux
	$(AM_V_GEN)src/build-efi-disk.sh
.DELETE_ON_ERROR: efi-disk.img

test-efi: efi-disk.img
	$(QEMU) -machine accel=kvm -m 1024 -bios $(QEMU_BIOS) -drive format=raw,file=efi-disk.img
.PHONY: test-efi

update:
	git pull --rebase
	(cd ../libbus1 && git pull --rebase && ./autogen.sh b && make)
	(cd ../init && git pull --rebase && ./autogen.sh b && make)
	(cd ../boot-efi && git pull --rebase && ./autogen.sh b && make)
.PHONY: update

test-init: src/test-init.sh
	src/test-init.sh
.PHONY: test-init
