AC_INIT([build],
        [1],
        [http://www.github.com/bus1/build],
        [boot-efi],
        [http://www.github.com/bus1/build])

AC_CONFIG_SRCDIR([src/build-efi-disk.sh])
AC_CONFIG_MACRO_DIR([m4])
AC_CONFIG_HEADERS([config.h])
AC_CONFIG_AUX_DIR([build-aux])

AM_INIT_AUTOMAKE([foreign 1.11 -Wall -Wno-portability silent-rules tar-pax no-dist-gzip dist-xz subdir-objects])
AM_SILENT_RULES([yes])

AC_CANONICAL_HOST
AC_SYS_LARGEFILE

AC_PROG_CC

AC_PROG_CC_C99
AM_PROG_CC_C_O
AC_PROG_GCC_TRADITIONAL

AC_PROG_MKDIR_P
AC_CHECK_TOOL(OBJCOPY, objcopy)

# ------------------------------------------------------------------------------
# arguments

AC_ARG_ENABLE(debug, AS_HELP_STRING([--enable-debug], [enable debug options]))

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
AC_CONFIG_FILES([
        Makefile
])

AC_OUTPUT
AC_MSG_RESULT([
        $PACKAGE_NAME $VERSION

        prefix:                  ${prefix}

        QEMU:                    ${QEMU}
        QEMU OVMF:               ${QEMU_BIOS}
])
