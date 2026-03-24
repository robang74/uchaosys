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

if [ "${1:-}" = "clean" ]; then
  rm -rf build/
elif [ "${1:-}" = "veryclean" ]; then
  rm -rf build/ src/
  test "${2:-}" = "" && exit
  shift
fi

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
@@ -839,7 +839,8 @@ static void build_acpi0017(Aml *table)
     method = aml_method("_STA", 0, AML_NOTSERIALIZED);
     aml_append(method, aml_return(aml_int(0x0B)));
     aml_append(dev, method);
-    build_cxl_dsm_method(dev);
+    //RAF: disabled for minimal build
+    //build_cxl_dsm_method(dev);
 
     aml_append(scope, dev);
     aml_append(table, scope);
@@ -1014,7 +1015,8 @@ build_dsdt(GArray *table_data, BIOSLinke
                 aml_append(aml_pkg, aml_eisaid("PNP0A08"));
                 aml_append(aml_pkg, aml_eisaid("PNP0A03"));
                 aml_append(dev, aml_name_decl("_CID", aml_pkg));
-                build_cxl_osc_method(dev);
+                //RAF: disabled for minimal build
+                //build_cxl_osc_method(dev);
             } else if (pci_bus_is_express(bus)) {
                 aml_append(dev, aml_name_decl("_HID", aml_eisaid("PNP0A08")));
                 aml_append(dev, aml_name_decl("_CID", aml_eisaid("PNP0A03")));
@@ -2072,8 +2074,9 @@ void acpi_build(AcpiBuildTables *tables,
                           x86ms->oem_id, x86ms->oem_table_id);
     }
     if (pcms->cxl_devices_state.is_enabled) {
-        cxl_build_cedt(table_offsets, tables_blob, tables->linker,
-                       x86ms->oem_id, x86ms->oem_table_id, &pcms->cxl_devices_state);
+        //RAF: disabled for minimal build
+        //cxl_build_cedt(table_offsets, tables_blob, tables->linker,
+        //               x86ms->oem_id, x86ms->oem_table_id, &pcms->cxl_devices_state);
     }
 
     acpi_add_table(table_offsets, tables_blob);
--- a/$src_dir/hw/pci-host/gpex-acpi.c	2026-03-24 14:57:57.740528905 +0100
+++ b/$src_dir/hw/pci-host/gpex-acpi.c	2026-03-24 14:58:50.833630475 +0100
@@ -149,7 +149,8 @@ void acpi_dsdt_add_gpex(Aml *scope, stru
             aml_append(dev, aml_name_decl("_CRS", crs));
 
             if (is_cxl) {
-                build_cxl_osc_method(dev);
+                //RAF: disabled for minimal build
+                //build_cxl_osc_method(dev);
             } else {
                 /* pxb bridges do not have ACPI PCI Hot-plug enabled */
                 acpi_dsdt_add_host_bridge_methods(dev, true);
EOF
fi
cp minikvm.mak $src_dir/configs/devices/x86_64-softmmu/

################################################################################

out_dir="$PWD/$bin_dir"

path=$PWD/musl/output
export PATH=$path/bin:$path/$ARCH/bin:$PATH
export ARCH=x86_64
#export CFLAGS="-O1 -march=native -flto -fno-plt -fPIE -falign-functions -pipe -static -s"
#export CFLAGS="$CFLAGS -fdata-sections -ffunction-sections -fno-stack-protector"
#export LDFLAGS="--static -flto -fno-plt -Wl,--gc-sections -falign-functions"

# slirp is for user-emulated network, while vhost is for the passtrough:
# - user-mode networking (stack TCP/IP emulated by QEMU)
# - kernel-level acceleration (passthrough-like via TAP)
# both should be available because they contributes jittering in different ways
mkdir -p build; cd build
CFLAGS="-O1 -march=native -pipe -falign-functions=32" ../$src_dir/configure \
  --audio-drv-list= \
  --without-default-devices \
  --without-default-features \
  --target-list=x86_64-softmmu \
  --with-devices-x86_64=minikvm \
  --enable-kvm \
  --enable-tcg \
  --enable-system \
  --enable-vhost-net \
  --enable-slirp \
  --enable-strip \
  --disable-lto \
  --enable-fdt \
  --extra-cflags="-s" || exit
# --extra-cflags="-s -static -fno-semantic-interposition"
# --extra-ldflags="--static"

################################################################################

if make -j$(nproc) qemu-system-$ARCH; then
  cd ..
  cp -f build/qemu-system-$ARCH src/pc-bios/qboot.rom ../virt
  cd ..
  echo
  virt/qemu-system-x86_64 -M help
  strip -s virt/qemu-system-x86_64
  du -k virt/qemu-system-$ARCH virt/qboot.rom
fi

