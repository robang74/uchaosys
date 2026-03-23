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

test -r $url_name ||
  $dwnl_cmd -c $url_site/$url_path/$url_name
mkdir -p $src_dir $bin_dir
$infl_cmd $url_name -C $src_dir --strip-components=1

cd $src_dir
out_dir="$PWD/output"

path=$PWD/../musl/output
export PATH=$path/bin:$path/$ARCH/bin:$PATH

export ARCH=x86_64
export CFLAGS="-O1 -march=native -flto -fno-plt -fno-plt -fPIE -pipe -static"
export CFLAGS="$CFLAGS -fdata-sections -ffunction-sections -fno-stack-protector"
export LDFLAGS="--static -flto -fno-plt -Wl,--gc-sections"

CFLAGS="$CFLAGS" LDFLAGS="$LDFLAGS" ./configure \
  --static \
  --prefix=$out_dir \
  --target-list=x86_64-softmmu \
  --with-devices-x86_64=default \
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

if make -j$(nproc) qemu-system-x86_64; then
  cd .. 
  cp -f  $out_dir/bin/qemu-* $bin_dir
  du -k $bin_dir/qemu-*
fi

