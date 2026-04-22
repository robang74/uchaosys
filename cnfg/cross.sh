#!/bin/sh

case "$ARCH" in
  mips*|ppc*|s390*) endian="big" ;;
  *)                endian="little" ;;
esac

LDFLAGS=${LDFLAGS:--g0}
CFLAGS=${CFLAGS:--O1}
LIBA=${LIBA:--s}

CFLAGS="$CFLAGS -I$PWD/obj_sysroot/include -I$PWD/../output/include"

M_LDFLAGS=$(echo $LDFLAGS | sed "s/ /', '/g; s/^/'/; s/$/'/")
M_CFLAGS=$( echo  $CFLAGS | sed "s/ /', '/g; s/^/'/; s/$/'/")
M_LIBA=$(   echo    $LIBA | sed "s/ /', '/g; s/^/'/; s/$/'/")

echo "meson: $MESON"

CC=${CC:-${PREFIX}cc}
AR=${AR:-${PREFIX}ar}
NM=${NM:-${PREFIX}nm}
LD=${LD:-${PREFIX}ld}
CPP=${CPP:-${PREFIX}g++}
STRIP=${STRIP:-${PREFIX}strip}
NINJA=${NINJA:-${PREFIX}ninja}
MESON=${MESON:-${PREFIX}meson}
PKGCFG=${PKGCFG:-${PREFIX}pkg-config}

cat <<EOF > ${1:-cross.ini}
[binaries]
c = '$CC'
ar = '$AR'
nm = '$NM'
ld = '$LD'
cpp = '$CPP'
strip = '$STRIP'
ninja = '$NINJA'
meson = '$MESON' # 'meson'
pkg-config = '$PKGCFG'

[built-in options]
c_args = [$M_CFLAGS]
cpp_args = [$M_CFLAGS]
c_link_args = [$M_LDFLAGS,$M_LIBA]
cpp_link_args = [$M_LDFLAGS,$M_LIBA]
default_library = 'static'
auto_features = 'disabled'
#c_std = 'c99'

[host_machine]
system = 'linux'
cpu_family = '$(echo $ARCH | sed 's/i.86/x86/')'
cpu = '$ARCH'
endian = '$endian'
EOF
