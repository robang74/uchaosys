#!/bin/sh

case "$ARCH" in
  mips*|ppc*|s390*) endian="big" ;;
  *)                endian="little" ;;
esac
M_LDFLAGS=$(echo $LDFLAGS | sed "s/ /', '/g; s/^/'/; s/$/'/")
M_CFLAGS=$( echo  $CFLAGS | sed "s/ /', '/g; s/^/'/; s/$/'/")
M_LIBA=$(   echo    $LIBA | sed "s/ /', '/g; s/^/'/; s/$/'/")
cat <<EOF > ${1:-cross.ini}
[binaries]
c = 'gcc' # '$CC'
ar = 'ar' # '$AR'
nm = 'nm' # '$NM'
ld = 'ld' # '$LD'
cpp = 'g++' # '$CPP'
strip = 'strip' # '$STRIP'
ninja = 'ninja' # '$NINJA'
meson = '$MESON' # 'meson'
pkg-config = 'pkg-config' # '$PKGCFG'

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
