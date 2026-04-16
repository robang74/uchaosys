#!/bin/sh
#
# (c) 2026, Roberto A. Foglietta <roberto.foglietta@gmail.com>, MIT license
#
################################################################################

shft() { eval sed -e 's/^/\\t/' -e \"s,$top_dir/,local::qemu/,\"; }
prnt() { echo "$@" | tr ' ' '\n' | sort | shft; }

url_site="https://github.com/robang74/qemu"
url_path="/archive/refs/tags/"
url_name="v10.2.2.tar.gz"

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

if [ "${1:-}" = "sources" -o ! -d src/ ]; then
  echo
  echo "Preparing sources ... "
  echo
  git submodule update --init --recursive --jobs $ncpu \
    --depth 32 --single-branch slirp
  test -r $url_name ||
    $dwnl_cmd -c $url_site/$url_path/$url_name
  mkdir -p $src_dir $bin_dir
  $infl_cmd $url_name -C $src_dir --strip-components=1
  sed -e '/cxl\.c/d' -e '/cxl-stub/d' -i $src_dir/hw/acpi/meson.build
  patch -p1 << EOF
--- a/$src_dir/hw/i386/acpi-build.c	2026-03-24 14:23:37.852944753 +0100
+++ b/$src_dir/hw/i386/acpi-build.c	2026-03-24 14:26:02.097386643 +0100
@@ -839,7 +839,9 @@ static void build_acpi0017(Aml *table)
     method = aml_method("_STA", 0, AML_NOTSERIALIZED);
     aml_append(method, aml_return(aml_int(0x0B)));
     aml_append(dev, method);
-    build_cxl_dsm_method(dev);
+ #ifndef _DISABLE_CXL //RAF: disable for a minimal build
+    build_cxl_dsm_method(dev);
+ #endif

     aml_append(scope, dev);
     aml_append(table, scope);
@@ -1014,7 +1015,9 @@ build_dsdt(GArray *table_data, BIOSLinke
                 aml_append(aml_pkg, aml_eisaid("PNP0A08"));
                 aml_append(aml_pkg, aml_eisaid("PNP0A03"));
                 aml_append(dev, aml_name_decl("_CID", aml_pkg));
-                build_cxl_osc_method(dev);
+ #ifndef _DISABLE_CXL //RAF: disable for a minimal build
+                build_cxl_osc_method(dev);
+ #endif
             } else if (pci_bus_is_express(bus)) {
                 aml_append(dev, aml_name_decl("_HID", aml_eisaid("PNP0A08")));
                 aml_append(dev, aml_name_decl("_CID", aml_eisaid("PNP0A03")));
@@ -2072,8 +2074,10 @@ void acpi_build(AcpiBuildTables *tables,
                           x86ms->oem_id, x86ms->oem_table_id);
     }
     if (pcms->cxl_devices_state.is_enabled) {
-        cxl_build_cedt(table_offsets, tables_blob, tables->linker,
-                       x86ms->oem_id, x86ms->oem_table_id, &pcms->cxl_devices_state);
+ #ifndef _DISABLE_CXL //RAF: disable for a minimal build
+        cxl_build_cedt(table_offsets, tables_blob, tables->linker,
+                       x86ms->oem_id, x86ms->oem_table_id, &pcms->cxl_devices_state);
+ #endif
     }

     acpi_add_table(table_offsets, tables_blob);
--- a/$src_dir/hw/pci-host/gpex-acpi.c	2026-03-24 14:57:57.740528905 +0100
+++ b/$src_dir/hw/pci-host/gpex-acpi.c	2026-03-24 14:58:50.833630475 +0100
@@ -149,7 +119,9 @@ void acpi_dsdt_add_gpex(Aml *scope, stru
             aml_append(dev, aml_name_decl("_CRS", crs));

             if (is_cxl) {
-                build_cxl_osc_method(dev);
+ #ifndef _DISABLE_CXL //RAF: disable for a minimal build
+                build_cxl_osc_method(dev);
+ #endif
             } else {
                 /* pxb bridges do not have ACPI PCI Hot-plug enabled */
                 acpi_dsdt_add_host_bridge_methods(dev, true);
--- a/$src_dir/hw/i386/pc_q35.c	2026-03-31 19:10:11.650911367 +0200
+++ b/$src_dir/hw/i386/pc_q35.c	2026-03-31 19:11:06.445131700 +0200
@@ -381,6 +381,7 @@ static void pc_q35_machine_10_2_options(
 
 DEFINE_Q35_MACHINE_AS_LATEST(10, 2);
 
+#if 0
 static void pc_q35_machine_10_1_options(MachineClass *m)
 {
     pc_q35_machine_10_2_options(m);
@@ -695,3 +696,4 @@ static void pc_q35_machine_2_6_options(M
 }
 
 DEFINE_Q35_MACHINE(2, 6);
+#endif
--- a/$src_dir/hw/core/machine.c	2026-03-31 07:04:12.848337933 +0200
+++ b/$src_dir/hw/core/machine.c	2026-03-31 07:06:08.752070371 +0200
@@ -47,6 +47,7 @@ GlobalProperty hw_compat_10_1[] = {
 };
 const size_t hw_compat_10_1_len = G_N_ELEMENTS(hw_compat_10_1);
 
+#if 0
 GlobalProperty hw_compat_10_0[] = {
     { "scsi-hd", "dpofua", "off" },
     { "vfio-pci", "x-migration-load-config-after-iter", "off" },
@@ -297,6 +298,7 @@ GlobalProperty hw_compat_2_6[] = {
     { "virtio-pci", "disable-legacy", "off", .optional = true },
 };
 const size_t hw_compat_2_6_len = G_N_ELEMENTS(hw_compat_2_6);
+#endif
 
 MachineState *current_machine;
EOF
fi
test "${1:-}" = "sources" && shift
cp -af minikvm.mak $src_dir/configs/devices/x86_64-softmmu/ || exit 1

################################################################################

path="$(realpath $PWD/../musl/output)"
export PATH="$path/bin:$path/$ARCH/bin:$PATH"
CFLAGS="-O1 -march=x86-64-v3 $xlto -falign-functions=32 $xppe $EXTRA_CFLAGS"
export CFLAGS="$CFLAGS -fdata-sections -ffunction-sections -fno-stack-protector"
LDFLAGS="-Wl,--allow-shlib-undefined -Wl,--copy-dt-needed-entries $xppe"
export LDFLAGS="$LDFLAGS $xlto -Wl,--gc-sections -falign-functions=32"

export CROSS_COMPILE=$path/bin/$ARCH-linux-musl-
export    CC="${CROSS_COMPILE}gcc"
export    LD="${CROSS_COMPILE}ld"
export    AR="${CROSS_COMPILE}ar"
export    NM="${CROSS_COMPILE}nm"
export STRIP="${CROSS_COMPILE}strip"

mkdir -p $bld_dir

################################################################################

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

if ! ls -1 slirp/libslirp*.p/*.o 2>/dev/null | grep -q \.o ; then
  echo "Compiling libslirp ... "
  echo
  set -e
  cd slirp
  rm -rf $bld_dir; mkdir -p $bld_dir
# meson --reconfigure $bld_dir
  meson build --prefix=$PWD/$bld_dir
  ninja -j$ncpu -C $bld_dir
  cd ..
  set +e
fi

luc="libucustom"
if [ ! -r "$luc.a" ]; then
  OBJS="$OBJS "$(find slirp/$bld_dir/libslirp*.p/ -name \*.o)
  echo
  echo "Preparting libucustom ... "
  ${AR:-ar} rcs $bld_dir/$luc.a $OBJS
  set +e
fi
LIBA="$LIBA $top_dir/$bld_dir/$luc.a"

################################################################################

cd $bld_dir
CFLAGS="$CFLAGS -I$PWD"
hd="/usr/include"; cp $hd/zlib.h $hd/zconf.h . || exit 1

glib="/usr/lib/${ARCH}-linux-gnu"
mlib="/usr/lib/${ARCH}-linux-musl"
for i in $ld_libz $ld_glib; do # util pthread pcre2-8
  LIBA="$LIBA "$(find $glib/ -name lib$i.a | head -n1 )
done

printf "\nStatic libraries found:\n"
prnt $LIBA #read -p "param 1: $1" key
echo
if [ "$ld_glib" = "" ]; then
  LDFLAGS="$LDFLAGS -L$glib/libc.so.6 -Wl,-rpath,$glib -Wl,-Bdynamic -lglib-2.0"
fi
LDFLAGS="$LDFLAGS -Wl,-Bstatic $LIBA"

if [ "${1:-}" != "noconfig" ]; then
  CFLAGS="" LDFLAGS="" time -p ../$src_dir/configure -j$ncpu \
    --gdb= \
    --audio-drv-list= \
    --without-default-devices \
    --without-default-features \
    --target-list=$ARCH-softmmu \
    --with-devices-$ARCH=minikvm \
    --enable-kvm \
    --enable-tcg \
    --enable-system \
    --enable-vhost-net \
    --enable-slirp \
    --enable-fdt \
    --disable-attr --disable-cap-ng \
    --disable-tcg-interpreter --disable-auth-pam \
    --disable-zstd --disable-lzo --disable-bzip2 \
    --disable-docs --disable-tools --disable-guest-agent \
    --extra-cflags="$CFLAGS -D_DISABLE_CXL -D_DISABLE_RUNAS" \
    --extra-ldflags="$LDFLAGS -static" || exit $?
fi

################################################################################

roms="bios-256k.bin efi-virtio.rom kvmvapic.bin linuxboot_dma.bin qboot.rom"

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
  CFLAGS=""
  LDFLAGS=""
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
( cd ../$src_dir/pc-bios && cp -f $roms $dst_dir )
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
