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

system.img:
	src/install-$$(. /etc/os-release; echo $$ID).sh
.DELETE_ON_ERROR: system.img

initrd: src/build-initrd.sh
	src/build-initrd.sh
.DELETE_ON_ERROR: initrd

test-init:
	src/test-init.sh
.PHONY: test-init

efi-disk.img: $(stub) src/build-efi-disk.sh ../boot-efi/bootx64.efi system.img initrd
	$(AM_V_GEN)src/build-efi-disk.sh
.DELETE_ON_ERROR: efi-disk.img

test-efi: efi-disk.img
	$(QEMU) -machine accel=kvm -m 1024 -bios $(QEMU_BIOS) -snapshot efi-disk.img
.PHONY: test-efi
