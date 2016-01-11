SHELL=bash
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
  efi-disk.img \
  rpi-disk.img

debian:
	src/install-debian.sh
.PHONY: debian

fedora:
	src/install-fedora.sh
.PHONY: fedora

rpi:
	src/install-raspberrypi.sh
.PHONY: rpi

system:
	src/install-$$(. /etc/os-release; echo $${ID_LIKE:-$$ID}).sh

system/usr/lib/bus1-release: system/usr/lib/os-release
	sed -i 's#root:\*:#root::#' system/usr/etc/shadow
	sed -i 's#:/root:#:/:#' system/usr/etc/passwd
	echo bus1-$$(date +%s) > system/usr/lib/bus1-release

system/usr/bin/org.bus1.rdinit: system/usr/lib/bus1-release ../base/org.bus1.rdinit ../base/org.bus1.init ../base/org.bus1.devices
	make install -C ../base DESTDIR=$$PWD/system

system/usr/bin/bus1ctl: system/usr/lib/bus1-release ../libbus1/bus1ctl
	make install -C ../libbus1 DESTDIR=$$PWD/system

KVERSION = $(shell ls -1 system/usr/lib/modules | tail -1)
system/usr/lib/modules/$(KVERSION)/kernel/ipc/bus1.ko: linux ../bus1/ipc/bus1/bus1.ko
	mkdir -p system/usr/lib/modules/$(KVERSION)/kernel/ipc
	cp ../bus1/ipc/bus1/bus1.ko system/usr/lib/modules/$(KVERSION)/kernel/ipc
	ln -sf usr/lib system/lib
	depmod -a -b system $(KVERSION)

system.img: system/usr/lib/bus1-release system/usr/lib/modules/$(KVERSION)/kernel/ipc/bus1.ko system/usr/bin/org.bus1.rdinit system/usr/bin/bus1ctl
	rm -rf system/usr/include
	find system/usr -type f -name "*.la" -delete
	rm -f system.img
	mksquashfs system/usr system.img
.DELETE_ON_ERROR: system.img

initrd: system.img src/build-initrd.sh ../base/org.bus1.rdinit ../base/org.bus1.devices
	src/build-initrd.sh
.DELETE_ON_ERROR: initrd

efi-disk.img: $(stub) src/build-efi-disk.sh ../boot-efi/bootx64.efi ../boot-efi/stubx64.efi system.img initrd vmlinuz
	$(AM_V_GEN)src/build-efi-disk.sh
.DELETE_ON_ERROR: efi-disk.img

rpi-disk.img: system.img initrd
	$(AM_V_GEN)src/build-raspberrypi-disk.sh
.DELETE_ON_ERROR: rpi-disk.img

efi: efi-disk.img
	$(QEMU) -machine accel=kvm -m 1024 -bios $(QEMU_BIOS) -drive format=raw,file=efi-disk.img
.PHONY: efi

qemu: efi-disk.img
	$(QEMU) -machine accel=kvm -m 1024 -kernel vmlinuz -initrd initrd -serial stdio \
		-append "quiet disk=$$(blkid -p -s PTUUID -o value efi-disk.img) loader=/EFI/bus1/bus1-$$(cat system/usr/lib/bus1-release).efi console=ttyS0 console=tty0" \
		-drive format=raw,file=efi-disk.img
.PHONY: qemu

update:
	git pull --rebase
	(cd ../libbus1 && git pull --rebase)
	(cd ../base && git pull --rebase)
	(cd ../bus1 && git pull --rebase)
	[[ ! -e ../boot-efi ]] || (cd ../boot-efi && git pull --rebase)
.PHONY: update

build: linux
	(cd ../libbus1 && ./autogen.sh b && make clean && make -j8)
	(cd ../base && ./autogen.sh b && make clean && make -j8)
	(cd ../bus1 && make clean && make b -j8)
	[[ ! -e ../boot-efi ]] || (cd ../boot-efi && ./autogen.sh b && make clean && make -j8)
