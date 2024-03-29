# ------------------------------------------------------------------------------
# versions

AC_PREREQ([2.64])
AC_INIT([build],
        [1],
        [http://www.github.com/bus1/build],
        [build],
        [http://www.github.com/bus1/build])

# ------------------------------------------------------------------------------
# autotools

AC_CONFIG_SRCDIR([src/initrd-build.sh])
AC_CONFIG_MACRO_DIR([build/m4])
AC_CONFIG_HEADERS([build/config.h])
AC_CONFIG_AUX_DIR([build/build-aux])

AM_MAINTAINER_MODE([enable])
AM_INIT_AUTOMAKE([foreign 1.11 -Wall -Wno-portability silent-rules tar-pax no-dist-gzip dist-xz subdir-objects parallel-tests])
AM_SILENT_RULES([yes])
AC_CANONICAL_HOST
AC_DEFINE_UNQUOTED([CANONICAL_HOST], "$host", [Canonical host string.])

AS_IF([! ln --relative --help > /dev/null 2>&1], [AC_MSG_ERROR([*** ln doesn't support --relative ***])])
m4_pattern_forbid([^_?PKG_[A-Z_]+$],[*** pkg.m4 missing, please install pkg-config])

# ------------------------------------------------------------------------------
# QEMU and OVMF UEFI firmware
AS_IF([test x"$cross_compiling" = "xyes"], [], [
        AC_PATH_PROG([QEMU], [qemu-system-x86_64])
        AC_CHECK_FILE([/usr/share/qemu/OVMF.fd], [QEMU_BIOS=/usr/share/qemu/OVMF.fd])
        AC_CHECK_FILE([/usr/share/qemu/bios-ovmf.bin], [QEMU_BIOS=/usr/share/qemu/bios-ovmf.bin])
        AC_CHECK_FILE([/usr/share/edk2.git/ovmf-x64/OVMF-pure-efi.fd], [QEMU_BIOS=/usr/share/edk2.git/ovmf-x64/OVMF-pure-efi.fd])
        AC_SUBST([QEMU_BIOS])
])

# ------------------------------------------------------------------------------
# report

AC_CONFIG_FILES([Makefile])

AC_OUTPUT
AC_MSG_RESULT([
        $PACKAGE_NAME $VERSION
        prefix:                 ${prefix}
        QEMU:                   ${QEMU}
        QEMU OVMF:              ${QEMU_BIOS}

])
