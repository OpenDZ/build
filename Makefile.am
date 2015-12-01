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

system.img: system ../init/org.bus1.rdinit ../init/org.bus1.init ../init/org.bus1.devices
	cp ../init/org.bus1.rdinit system/bin
	cp ../init/org.bus1.init system/bin
	cp ../init/org.bus1.devices system/bin
	rm -f system.img
	mksquashfs system system.img
.DELETE_ON_ERROR: system.img

initrd: system.img src/build-initrd.sh ../init/org.bus1.rdinit ../init/org.bus1.devices
	src/build-initrd.sh
.DELETE_ON_ERROR: initrd

test-init: src/test-init.sh
	src/test-init.sh
.PHONY: test-init

efi-disk.img: $(stub) src/build-efi-disk.sh ../boot-efi/bootx64.efi system.img initrd
	$(AM_V_GEN)src/build-efi-disk.sh
.DELETE_ON_ERROR: efi-disk.img

test-efi: efi-disk.img
	$(QEMU) -machine accel=kvm -m 1024 -bios $(QEMU_BIOS) -drive format=raw,file=efi-disk.img
.PHONY: test-efi
