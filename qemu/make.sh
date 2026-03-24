#!/bin/sh
#
# (c) 2026, Roberto A. Foglietta <roberto.foglietta@gmail.com>, MIT license
#

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

if [ "${1:-}" = "sources" ]; then
  test -r $url_name ||
    $dwnl_cmd -c $url_site/$url_path/$url_name
  mkdir -p $src_dir $bin_dir
  $infl_cmd $url_name -C $src_dir --strip-components=1
  cp minikvm.mak $src_dir/configs/devices/x86_64-softmmu/
fi

#cd $src_dir
out_dir="$PWD/$bin_dir"

path=$PWD/musl/output
export PATH=$path/bin:$path/$ARCH/bin:$PATH
export ARCH=x86_64
#export CFLAGS="-O1 -march=native -flto -fno-plt -fPIE -pipe -static -s"
#export CFLAGS="$CFLAGS -fdata-sections -ffunction-sections -fno-stack-protector"
#export LDFLAGS="--static -flto -fno-plt -Wl,--gc-sections"

# slirp is for user-emulated network, while vhost is for the passtrough:
# - user-mode networking (stack TCP/IP emulated by QEMU)
# - kernel-level acceleration (passthrough-like via TAP)
# both should be available because they contributes jittering in different ways
mkdir -p build; cd build
CFLAGS="-O1 -march=native -pipe" ../$src_dir/configure \
  --enable-kvm \
  --enable-system \
  --enable-strip \
  --disable-werror \
  --disable-debug-info \
  --disable-debug-tcg \
  --disable-tcg-interpreter \
  --target-list=x86_64-softmmu \
  --enable-vhost-net \
  --enable-slirp \
  --disable-tools \
  --disable-docs \
  --extra-cflags="-s" || exit

if false ; then
  --disable-bsd-user \
  --disable-guest-agent \
  --enable-strip \
  --disable-werror \
  --disable-gcrypt \
  --disable-debug-info \
  --disable-debug-tcg \
  --disable-tcg-interpreter \
  --disable-attr \
  --disable-brlapi \
  --disable-linux-aio \
  --disable-bzip2 \
  --disable-cap-ng \
  --disable-curl \
  --enable-fdt \
  --disable-glusterfs \
  --disable-gnutls \
  --disable-nettle \
  --disable-gtk \
  --disable-rdma \
  --disable-libiscsi \
  --disable-vnc-jpeg \
  --disable-lzo \
  --disable-curses \
  --disable-libnfs \
  --disable-numa \
  --disable-opengl \
  --disable-rbd \
  --disable-vnc-sasl \
  --disable-sdl \
  --disable-seccomp \
  --disable-smartcard \
  --disable-snappy \
  --disable-spice \
  --disable-libusb \
  --disable-usb-redir \
  --disable-vde \
  --disable-vhost-net \
  --disable-virglrenderer \
  --disable-virtfs \
  --disable-vnc \
  --disable-vte \
  --disable-xen \
  --disable-xen-pci-passthrough \
  --enable-kvm \
  --enable-system \
  --target-list=x86_64-softmmu \
  --with-devices-x86_64=minikvm \
  --disable-tools \
  --disable-docs \
  --extra-cflags="-s" || exit
fi
if false; then
CFLAGS="$CFLAGS" LDFLAGS="$LDFLAGS" ./configure \
  --static \
  --prefix=$out_dir \
  --target-list=x86_64-softmmu \
  --with-devices-x86_64=minikvm \
  --without-default-devices \
  --enable-kvm \
  --enable-tcg \
  --enable-lto \
  --enable-strip \
  --enable-vhost-net \
  --audio-drv-list= \
  --disable-tcg-interpreter \
  --disable-tools \
  --disable-capstone \
  --disable-guest-agent \
  --disable-qom-cast-debug \
  --disable-stack-protector \
  --disable-gcrypt \
  --disable-gnutls \
  --disable-selinux \
  --disable-libudev \
  --disable-libssh \
  --disable-user \
  --disable-slirp \
  --disable-curl \
  --disable-vnc \
  --disable-vde \
  --disable-netmap \
  --disable-xen \
  --disable-brlapi \
  --disable-fdt \
  --disable-vhost-crypto \
  --disable-vhost-user \
  --disable-vhost-vdpa \
  --disable-sdl \
  --disable-gtk \
  --disable-opengl \
  --disable-spice \
  --disable-docs \
  --disable-gcrypt \
  --disable-nettle \
  --disable-gnutls \
  --disable-auth-pam \
  --disable-vhost-crypto \
  --disable-crypto-afalg \
  --disable-usb-redir \
  --disable-libusb
fi
if false; then
CFLAGS="$CFLAGS" LDFLAGS="$LDFLAGS" ./configure \
  --static \
  --prefix=$out_dir \
  --target-list=x86_64-softmmu \
  --with-devices-x86_64=minikvm \
  --enable-kvm \
  --enable-tcg \
  --enable-lto \
  --enable-strip \
  --audio-drv-list= \
  --disable-libudev       # ← new: kills -ludev
  --disable-curl \
  --disable-libssh \
  --disable-mpath \
  --disable-glusterfs \
  --disable-iscsi \
  --disable-rbd \
  --disable-numa \
  --disable-usb           # ← aggressive: no USB redirection/hotplug
  --disable-bpf \
  --disable-seccomp \
  --disable-replication \
  --disable-live-block-migration \
  --disable-migration \
  --disable-tcg-interpreter \
  --disable-tools \
  --disable-capstone \
  --disable-guest-agent \
  --disable-qom-cast-debug \
  --disable-stack-protector \
  --disable-gcrypt \
  --disable-gnutls \
  --disable-selinux \
  --disable-libudev       # duplicate ok, harmless
  --disable-libssh        # duplicate ok
  --disable-slirp \
  --disable-vde \
  --disable-netmap \
  --disable-xen \
  --disable-brlapi \
  --disable-vhost-crypto \
  --disable-vhost-user \
  --disable-vhost-vdpa \
  --disable-sdl \
  --disable-gtk \
  --disable-opengl \
  --disable-spice \
  --disable-docs \
  --disable-nettle \
  --disable-auth-pam \
  --disable-crypto-afalg \
  --disable-usb-redir \
  --disable-libusb \
  --enable-fdt            # for microvm (you already decided this)
fi
if make -j$(nproc) qemu-system-$ARCH; then
  cd ..
  cp -f build/qemu-system-$ARCH src/pc-bios/qboot.rom ../virt
  cd ..
  echo
  virt/qemu-system-x86_64 -M help
  strip -s virt/qemu-system-x86_64
  du -k virt/qemu-system-$ARCH virt/qboot.rom
fi

