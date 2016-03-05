# ------------------------------------------------------------------------------
# autotools

SHELL = bash
ACLOCAL_AMFLAGS = -I build/m4 ${ACLOCAL_FLAGS}
AM_MAKEFLAGS = --no-print-directory
AUTOMAKE_OPTIONS = color-tests parallel-tests

GCC_COLORS ?= 'ooh, shiny!'
export GCC_COLORS

# remove targets if the command fails
.DELETE_ON_ERROR:

# keep intermediate files
.SECONDARY:

# keep the test-suite.log and Makefile around at all times
.PRECIOUS: $(TEST_SUITE_LOG) Makefile

CLEANFILES = $(BUILT_SOURCES)

# ------------------------------------------------------------------------------
VENDOR = org.example
DATA_FSTYPE = xfs
VERSION = $(shell date +%s)
RELEASE = $(shell cat system/usr/lib/org.bus1/release 2> /dev/null)

CLEANFILES += \
  system.img \
  $(RELEASE).img \
  initrd \
  efi-disk.img \
  rpi-disk.img

arch:
	src/system-install-archlinux.sh
.PHONY: arch

debian:
	src/system-install-debian.sh
.PHONY: debian

fedora:
	src/system-install-fedora.sh
.PHONY: fedora

rpi:
	src/system-install-raspberrypi.sh
.PHONY: rpi

system:
	src/system-install-$$(. /etc/os-release; echo $${ID_LIKE:-$$ID}).sh

system/usr/lib/org.bus1/release: system/usr/lib/os-release
	sed -i 's#root:\*:#root::#' system/usr/etc/shadow
	sed -i 's#:/root:#:/:#' system/usr/etc/passwd
	mkdir -p system/usr/lib/org.bus1
	echo $(VENDOR)-$(VERSION) > system/usr/lib/org.bus1/release
	echo $(DATA_FSTYPE) > system/usr/lib/org.bus1/data.fstype

system/usr/bin/org.bus1.rdinit: system/usr/lib/org.bus1/release ../base/org.bus1.rdinit ../base/org.bus1.init ../base/org.bus1.devices
	make install -C ../base DESTDIR=$$PWD/system

system/usr/bin/org.bus1.busctl: system/usr/lib/org.bus1/release ../libbus1/org.bus1.busctl
	make install -C ../libbus1 DESTDIR=$$PWD/system

KERN_VERSION = $(shell ls -1 system/usr/lib/modules 2>/dev/null | tail -1)
system/usr/lib/modules/$(KERN_VERSION)/kernel/ipc/bus1.ko: linux ../bus1/ipc/bus1/bus1.ko
	mkdir -p system/usr/lib/modules/$(KERN_VERSION)/kernel/ipc
	cp ../bus1/ipc/bus1/bus1.ko system/usr/lib/modules/$(KERN_VERSION)/kernel/ipc
	ln -sf usr/lib system/lib
	depmod -a -b system $(KERN_VERSION)

system.img: system/usr/lib/org.bus1/release system/usr/lib/modules/$(KERN_VERSION)/kernel/ipc/bus1.ko system/usr/bin/org.bus1.rdinit system/usr/bin/org.bus1.busctl
	rm -rf system/usr/include
	find system/usr -type f -name "*.la" -delete
	rm -f system.img
	mksquashfs system/usr system.img
.DELETE_ON_ERROR: system.img

$(RELEASE).img: system.img ../base/org.bus1.diskctl
	../base/org.bus1.diskctl sign org.bus1.system squashfs system.img $(RELEASE).img
.DELETE_ON_ERROR: $(RELEASE).img

initrd: system.img src/initrd-build.sh ../base/org.bus1.rdinit ../base/org.bus1.devices
	src/initrd-build.sh
.DELETE_ON_ERROR: initrd

efi-disk.img: $(stub) src/disk-build-efi.sh ../boot-efi/bootx64.efi ../boot-efi/stubx64.efi $(RELEASE).img initrd vmlinuz
	$(AM_V_GEN)src/disk-build-efi.sh
.DELETE_ON_ERROR: efi-disk.img

rpi-disk.img: $(RELEASE).img initrd src/disk-build-raspberrypi.sh
	$(AM_V_GEN)src/disk-build-raspberrypi.sh
.DELETE_ON_ERROR: rpi-disk.img

rpidd: rpi-disk.img
	if grep -q sda /proc/self/mountinfo; then false; fi
	dd if=rpi-disk.img of=/dev/sda bs=1MiB
.PHONY: rpidd

efi: efi-disk.img
	$(QEMU) -machine accel=kvm -m 1024 -bios $(QEMU_BIOS) -drive format=raw,file=efi-disk.img
.PHONY: efi

qemu: efi-disk.img
	$(QEMU) -machine accel=kvm -m 1024 -kernel vmlinuz -initrd initrd -serial stdio \
		-append "quiet disk=$$(blkid -p -s PTUUID -o value efi-disk.img) loader=/EFI/org.bus1/$$(cat system/usr/lib/org.bus1/release).efi console=ttyS0 console=tty0" \
		-drive format=raw,file=efi-disk.img
.PHONY: qemu

bpull:
	git pull --rebase
	(cd ../libbus1 && git pull --rebase)
	(cd ../base && git pull --rebase)
	(cd ../bus1 && git pull --rebase)
	[[ ! -e ../boot-efi ]] || (cd ../boot-efi && git pull --rebase)
.PHONY: bpull

bclean:
	git clean -x -d -f && rm -rf firmware linux
	(cd ../libbus1 && git clean -x -d -f)
	(cd ../base && git clean -x -d -f)
	(cd ../bus1 && git clean -x -d -f)
	[[ ! -e ../boot-efi ]] || (cd ../boot-efi && git clean -x -d -f)
.PHONY: bclean

bgen:
	(cd ../libbus1 && ./autogen.sh b)
	(cd ../base && ./autogen.sh b)
	[[ ! -e ../boot-efi ]] || (cd ../boot-efi && ./autogen.sh b)
.PHONY: bgen

bbuild: linux
	(cd ../libbus1 && make -j8)
	(cd ../base && make -j8)
	(cd ../bus1 && make b -j8)
	[[ ! -e ../boot-efi ]] || (cd ../boot-efi && make -j8)
.PHONY: bbuild
