#!/bin/sh
#
# (c) 2026, Roberto A. Foglietta <roberto.foglietta@gmail.com>, MIT license
#
################################################################################

url_site="https://github.com/robang74/qemu"
url_path="/archive/refs/tags/"
url_name="v10.2.2.tar.gz"

dwnl_cmd="wget -c"
infl_cmd="tar -xzf"

bin_dir="bin"
src_dir="src"
dst_dir="../virt"

if [ "${1:-}" = "clean" ]; then
  rm -rf build/
elif [ "${1:-}" = "veryclean" ]; then
  rm -rf build/ src/
  test "${2:-}" = "" && exit
  shift
fi
# A recursive deletion upon a variable argument is risky, define it later
bld_dir="build"

################################################################################

if [ "${1:-}" = "sources" ]; then
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
EOF
fi
cp minikvm.mak $src_dir/configs/devices/x86_64-softmmu/

################################################################################

export ARCH="x86_64"
out_dir="$PWD/$bin_dir"

path="$PWD/../musl/output"
export PATH="$path/bin:$path/$ARCH/bin:$PATH"
CFLAGS="-O1 -march=x86-64-v3 -flto -fno-plt -falign-functions=32 -pipe"
export CFLAGS="$CFLAGS -fdata-sections -ffunction-sections -fno-stack-protector"
LDFLAGS="-no-pie -Wl,--allow-shlib-undefined -Wl,--copy-dt-needed-entries"
export LDFLAGS="-flto -fno-plt -Wl,--gc-sections -falign-functions=32 $LDFLAGS"

# slirp is for user-emulated network, while vhost is for the passtrough:
# - user-mode networking (stack TCP/IP emulated by QEMU)
# - kernel-level acceleration (passthrough-like via TAP)
# both should be available because they contributes jittering in different ways
mkdir -p $bld_dir; cd $bld_dir

#export CROSS_COMPILE=$path/bin/$ARCH-linux-musl-
#export CC="${CROSS_COMPILE}gcc"
#export LD="${CROSS_COMPILE}ld"
#export AR="${CROSS_COMPILE}ar"
#export NM="${CROSS_COMPILE}nm"

glib="/usr/lib/${ARCH}-linux-gnu"
mlib="/usr/lib/${ARCH}-linux-musl"
for i in pthread z m c_nonshared glib-2.0; do
  LIBA="$LIBA "$(find $glib/ -name lib$i.a | head -n1 )
done
printf "\nStatic libraries found:$LIBA\n\n"
CFLAGS="" LDFLAGS="" ../$src_dir/configure \
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
  --enable-lto \
  --enable-fdt \
  --disable-attr --disable-cap-ng \
  --disable-tcg-interpreter --disable-auth-pam \
  --disable-zstd --disable-lzo --disable-bzip2 \
  --disable-docs --disable-tools --disable-guest-agent \
  --extra-cflags="$CFLAGS -D_DISABLE_CXL -D_DISABLE_RUNAS" \
  --extra-ldflags="$LDFLAGS -no-pie -fPIC $PWD/libm_ifix.o $LIBA $(find $PWD -name libslirp.a) $(find /usr -name libpcre\*.a) -static" || exit $?

#   --extra-ldflags="$LDFLAGS -no-pie $PWD/libm_ifix.o $PWD/libslirp.a /usr/lib/x86_64-linux-gnu/libc_nonshared.a /usr/lib/x86_64-linux-gnu/libglib-2.0.a /usr/lib/x86_64-linux-gnu/libpcre2-8.a /usr/lib/x86_64-linux-gnu/libpcre.a  " \

################################################################################

shft() { sed -e "s/^/\t/"; }
roms="bios-256k.bin efi-virtio.rom kvmvapic.bin linuxboot_dma.bin qboot.rom"
qbin="qemu-system-$ARCH"
if ! make -j$(nproc) $qbin; then
  echo "Retry for static linking ... "
  sed -e "s,/[^ ]*/lib[^ ]*\.so,,g" -e "s/ -lutil//" -e "s/ -lm//" -i $qbin.rsp
  ${CC:-cc} -m64 @$qbin.rsp || exit $?
fi
echo "==============================="
echo
echo " Building path:\n\t$PWD"
cd ..
cp -f $bld_dir/$qbin $dst_dir
for i in $roms; do cp -f $src_dir/pc-bios/$i $dst_dir; done
cd $dst_dir
echo
echo " Dynamic libraries involved:"
ldd ./$qbin
echo
echo " Static  libraries involved:"
echo  $LIBA | tr ' ' \\n | shft
echo
strip -s $qbin
echo " Supported machines are:"
./$qbin -M help | grep -ve "^Supported" | shft
echo
echo " Hacked qemu footprint:"
printf "\t$(du -k $qbin)\n"
sze=$(( $(du -b $roms | cut -f1 | tr '\n' '+')0 ))
printf "\t%4d\troms files\n\n" $(( ($sze + (1<<9)) >> 10 ))

