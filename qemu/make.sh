#!/bin/sh
#
# (c) 2026, Roberto A. Foglietta <roberto.foglietta@gmail.com>, MIT license
#
################################################################################

shft() { eval sed -e 's/^/\\t/' -e \"s,$top_dir/,local::qemu/,\"; }
prnt() { echo "$@" | tr ' ' '\n' | sort | shft; }

url_site="https://github.com/robang74/qemu"
url_path="/archive/refs/tags/"
url_name="v10.2.3.tar.gz"

dwnl_cmd="wget -c"
infl_cmd="tar -xzf"

bin_dir="bin"
src_dir="src"
top_dir=$PWD
dst_dir=$(realpath $PWD/output)

export ARCH="${ARCH:-x86_64}"
out_dir="$PWD/$bin_dir"
qbin="qemu-system-$ARCH"

# PARAMETRIC BUILDING # ====================================================== #
#
# ld_libz="z"                  # set ot "z" for libz, or "" to use miniz
  ld_glib="glib-2.0"           # unset to have a glib-2.0 dynamic binary (TODO)
  ncpu=$(nproc)                # number of pipelines for parallel compilation
  xppe="-pipe"                 # usually faster in compiling  but not always
  xlto="-flto=$ncpu -fno-plt"  # set for profuction, unset for faster devolpment
  fixo="glibc-musl-fix"        # unset to not use the "frankenstein" approach
  ldck="ies"                   # set to "yes" for the option of check @.rbs
# ============================================================================ #

to_clean="build/ slirp/libslirp.a slirp/build minz/miniz.o cpio.tmp/"
if [ "${1:-}" = "clean" ]; then
  rm -rf $to_clean
  test "${2:-}" = "" && exit
  shift
fi
if [ "${1:-}" = "veryclean" ]; then
  rm -rf $to_clean src/
  test "${2:-}" = "" && exit
  shift
fi
if [ "${1:-}" = "deepclean" ]; then
  rm -rf $to_clean src/
  rm -f $qbin $qbin.???
  test "${2:-}" = "" && exit
  shift
fi
if [ "${1:-}" = "distclean" ]; then
  rm -rf $to_clean src/
  rm -f $qbin $qbin.??? $url_name
  test "${2:-}" = "" && exit
  shift
fi
# A recursive deletion upon a variable argument is risky, define it later
bld_dir="build"

################################################################################

if [ "${1:-}" = "sources" -o ! -e src/.done ]; then
  echo
  echo "Preparing sources ... "
  echo
  set -e
  git submodule update --init --recursive --jobs $ncpu \
    --depth 32 --single-branch slirp
  test -r $url_name ||
    $dwnl_cmd -c $url_site/$url_path/$url_name
  mkdir -p $src_dir $bin_dir
  cd $src_dir
  cdr="../../cnfg/"
  $infl_cmd ../$url_name --strip-components=1
  sed -e '/cxl\.c/d' -e '/cxl-stub/d' -i hw/acpi/meson.build
  patch -p1 < $cdr/qemu-q35-remove-old-machines-v4-patch
  patch -p1 < $cdr/qemu-user-max-pauth-impdef-on-v1.patch
  touch .done
  cd ..
  set +e
  exit 0
fi
#test "${1:-}" = "sources" && shift
cp -af minikvm.mak $src_dir/configs/devices/x86_64-softmmu/ || exit 1

################################################################################

path="$(realpath $PWD/../musl/output)"
export PATH="$path/bin:$path/$ARCH/bin:$PATH"
CFLAGS="-O1 -march=x86-64-v3 -falign-functions=32 $xppe $EXTRA_CFLAGS"
export CFLAGS="$CFLAGS -fdata-sections -ffunction-sections -fno-stack-protector"
LDFLAGS="-Wl,--allow-shlib-undefined -Wl,--copy-dt-needed-entries $xppe"
export LDFLAGS="$LDFLAGS -Wl,--gc-sections -falign-functions=32"

export CROSS_COMPILE=$path/bin/$ARCH-linux-musl-
export    CPP="${CROSS_COMPILE}g++"
export     CC="${CROSS_COMPILE}gcc"
export     LD="${CROSS_COMPILE}ld"
export     AR="${CROSS_COMPILE}ar"
export     NM="${CROSS_COMPILE}nm"
export  STRIP="${CROSS_COMPILE}strip"
export  MESON="$path/bin/meson.pyz"
export PKGCFG="$(realpath $PWD/../ucfg/pkg-config)"

mkdir -p $bld_dir

################################################################################

LIBA=""
glib="/usr/lib/${ARCH}-linux-gnu"
mlib="/usr/lib/${ARCH}-linux-musl"
for i in $ld_libz $ld_glib; do # util pthread pcre2-8
  LIBA="$LIBA "$(find $glib/ -name lib$i.a | head -n1)
done

if [ ! -n "$ld_libz" ]; then
  luz="minz/miniz"
  if [ ! -r $luz.o ]; then
    echo
    echo "Compiling libminiz ... "
    set -e
    ${CC:-cc} $CFLAGS -c $luz.c -o $luz.o
    set +e
  fi
  OBJS="$OBJS $top_dir/$luz.o"
else
  rm -f minz/miniz.o
fi

if [ -r "$fixo.c" ]; then
  echo "Compiling libifixo ... "
  set -e
  ${CC:-cc} $CFLAGS -c $fixo.c -o $bld_dir/$fixo.o || exit $?
  CFLAGS="$CFLAGS -Dclose_range(a,b,c)=syscall(SYS_close_range,a,b,c)"
  OBJS="$OBJS $top_dir/$bld_dir/$fixo.o"
  set +e
fi

# slirp is for user-emulated network, while vhost is for the passtrough:
# - user-mode networking (stack TCP/IP emulated by QEMU)
# - kernel-level acceleration (passthrough-like via TAP)
# both should be available because they contributes jittering in different ways

list_slirp_objs() { command ls -1 --color=never \
  slirp/$bld_dir/libslirp.a.p/*.o 2>/dev/null | tr '\n' ' '; }

if ! list_slirp_objs | grep -qe "\.o$"; then
  echo "Compiling libslirp ... "
  echo
  set -e
  cd slirp
  case "$ARCH" in
    mips*|ppc*|s390*) endian="big" ;;
    *)                endian="little" ;;
  esac
  M_LDFLAGS=$(echo $LDFLAGS | sed "s/ /', '/g; s/^/'/; s/$/'/")
  M_CFLAGS=$( echo  $CFLAGS | sed "s/ /', '/g; s/^/'/; s/$/'/")
  M_LIBA=$(   echo    $LIBA | sed "s/ /', '/g; s/^/'/; s/$/'/")
  cat <<EOF > cross.txt
[binaries]
c = 'gcc' # '$CC'
cpp = 'g++' # '$CPP'
ar = 'ar' # '$AR'
nm = 'nm' # '$NM'
strip = 'strip' # '$STRIP'
pkgconfig = 'pkg-config' # '$PKGCFG'

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
  rm -rf $bld_dir; mkdir -p $bld_dir
  meson setup $bld_dir --prefix=$PWD/$bld_dir --cross-file cross.txt
  ninja -j$ncpu -C $bld_dir
  cd ..
  set +e
fi
OBJS="$OBJS $(list_slirp_objs)"

luc="libucustom"
if [ ! -r "$luc.a" ]; then
  echo
  echo "Preparting libucustom ... "
  ${AR:-ar} rcs $bld_dir/$luc.a $OBJS
  set +e
fi
LIBA="$LIBA $top_dir/$bld_dir/$luc.a"

################################################################################

cd $bld_dir
CFLAGS="$CFLAGS -I$PWD $xlto -no-pie"
hd="/usr/include"; cp $hd/zlib.h $hd/zconf.h . || exit 1

printf "\nStatic libraries found:\n"
prnt $LIBA #read -p "param 1: $1" key
echo
if [ "$ld_glib" = "" ]; then
  LDFLAGS="$LDFLAGS -L$glib/libc.so.6 -Wl,-rpath,$glib -Wl,-Bdynamic -lglib-2.0"
fi
LDFLAGS="$LDFLAGS $xlto -Wl,-Bstatic -no-pie $LIBA"

if [ "${1:-}" != "noconfig" ]; then
  CFLAGS="" LDFLAGS="" time -p ../$src_dir/configure -j$ncpu \
    --gdb= \
    --audio-drv-list= \
    --without-default-devices \
    --without-default-features \
    --target-list=$ARCH-softmmu,aarch64-linux-user \
    --with-devices-$ARCH=minikvm \
    --enable-kvm \
    --enable-tcg \
    --enable-system \
    --enable-vhost-net \
    --enable-slirp \
    --enable-fdt \
    --enable-linux-user \
    --disable-attr --disable-cap-ng \
    --disable-tcg-interpreter --disable-auth-pam \
    --disable-zstd --disable-lzo --disable-bzip2 \
    --disable-docs --disable-tools --disable-guest-agent \
    --extra-cflags="$CFLAGS -D_DISABLE_CXL -D_DISABLE_RUNAS" \
    --extra-ldflags="$LDFLAGS -static" || exit $?
fi

################################################################################

roms="bios-microvm.bin efi-virtio.rom kvmvapic.bin linuxboot_dma.bin qboot.rom"

rm -f $qbin ../$qbin.nma ../$qbin.rsp ../$qbin.ldc ../$qbin
time -p make -j$ncpu $qbin

if [ ! -x $qbin ] ; then
  [ "$ldck" = "yes" ] && read -p "Press ENTER to continue: " pkey
  rm -f $qbin; cp -f $qbin.rsp $qbin.rsp.bak
  echo
  echo "==============================="
  echo
  echo "Fix the linking stage and repeat ..."
  echo
  CFLAGS="-s"
  LDFLAGS="-no-pie"
  for i in open stat; do
    LDFLAGS="$LDFLAGS -Wl,--defsym,${i}64=$i -Wl,--defsym,f${i}64=f$i"
  done
  for i in lseek mmap fstatat ftello fseeko fcntl ftell fseek \
           creat readdir lstat fallocate setrlimit freopen mkostemp; do
    LDFLAGS="$LDFLAGS -Wl,--defsym,${i}64=$i"
  done
  if [ ! -n "$ld_libz" ]; then
    for i in deflate inflate deflateInit inflateInit deflateEnd inflateEnd\
             compressBound compress2 inflateInit2 deflateInit2; do
      LDFLAGS="$LDFLAGS -Wl,--defsym,$i=mz_$i"
    done
    for i in deflateInit inflateInit; do for j in "" 2; do
      LDFLAGS="$LDFLAGS -Wl,--defsym=${i}${j}_=mz_${i}${j}"
    done; done
  fi
  sed -e "s,/[^ ]*/lib[^ ]*\.so,,g" -e "s, -lutil,," -e "s, -lm,," \
      -e "s, -pthread,," -e "s, -lz,," -i $qbin.rsp
  cmd="${CC:-cc} $CFLAGS $LDFLAGS @$qbin.rsp"
  echo $cmd | tee ../$qbin.ldc; time -p $cmd || exit $?
fi

cp -f $qbin.rsp ../$qbin.rsp
${NM:-nm} -a $qbin >../$qbin.nma
cd ..

# target: install ##############################################################
#function target_install() {
mkdir -p $dst_dir
cd $bld_dir
#opts="--strip-all --remove-section=.comment --remove-section=.note"
${STRIP:-strip} ${opt:--s} $qbin -o $dst_dir/$qbin
( cd ../$src_dir/pc-bios && cp -alf $roms $dst_dir )
ln -sf bios-microvm.bin $dst_dir/bios-256k.bin 
chmod -x $dst_dir/*.rom

echo
echo "==============================="
echo
echo " Building path:\n\t$PWD"
echo
echo " Dynamic libraries involved:"

cd $dst_dir
ldd ./$qbin 2>&1
echo
if [ -n "$LIBA" ]; then
  echo " Static  libraries involved:"
  prnt $LIBA
  echo
fi
echo " Supported machines are:"
./$qbin -M help | grep -ve "^Supported" | shft
echo

echo " Hacked qemu footprint:"
printf "\t$(du -k $qbin)\n"
sze=$(( $(du -b $roms | cut -f1 | tr '\n' '+')0 ))
printf "\t%4d\troms files\n\n" $(( ($sze + (1<<9)) >> 10 ))
#}
