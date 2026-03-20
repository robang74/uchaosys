#!/bin/bash
#
# (c) 2026, Roberto A. Foglietta <roberto.foglietta@gmail.com>, MIT license
#

append_for_kernel_debug="earlyprintk=serial nokaslr -pidfile vm.pid -panic=1"

kimg="bzImage"
rfsimg="initramfs.cpio"
qemubin="qemu-system-x86_64"

test -r ${rfsimg}.gz && rfsimg="${rfsimg}.gz"
rfsdir=$(echo "$rfsimg" | sed 's/\.cpio\.gz//;s/\.cpio//')

chkmd5() { md5sum -c update/$rfsdir.md5 2>/dev/null; }

# Cope with the user's parametric input

test -r bzImage || ln -sf bzImage.orig bzImage

# Command line flags management

imgupdte=0
zerokelv=0
zerotest=0
quietrun=0

while [ $# -gt 0 ]; do
  case "x$1" in
    "x-u")
      imgupdte=1
      shift
      ;;
    "x-z")
      zerokelv=1
      shift
      ;;
    "x-Z")
      zerotest=1
      shift
      ;;
    "x-q")
      quietrun=1
      shift
      ;;
    *)
      echo "Unknown flag, ignored: $1"
      shift
      ;;
  esac
done

if [ $imgupdte -ne 0 ]; then
  sh -c "cd ..; ./cpio.sh -c"
  read -p ">>> Updated, press ENTER to continue " key
fi

if [ $quietrun -ne 0 ]; then
  cmdlnx="quiet"
else
  cmdlnx=""
fi

if [ $zerotest -ne 0 ]; then
  export QZERO=1 QMSZE=256M UCTEST=${UCTEST:-1}
  cmdlnx="UCTEST=${UCTEST:-1}"
elif [ $zerokelv -ne 0 ]; then
  export QZERO=1 QMSZE=256M UCTEST=${UCTEST:-0}
  cmdlnx="UCTEST=${UCTEST:-1}"
elif [ -n "$UCTEST" ]; then
  cmdlnx="UCTEST=$UCTEST"
fi

# Preparing the QEMU virtual machine configuration #############################

export QTTYUC=${QTTYUC:-console=ttyS0,115200n8}

cmdlnx="$cmdlnx HOST=x86_64 root=/dev/ram0 init=/init $QTTYUC net.ifnames=0 nokaslr"
nograp="-nographic -vga none -display none"

if [ "${QZERO:-0}" = "0" ]; then
  boxnme="-name tinylnx"
  qaccel="-enable-kvm -cpu host -machine accel=kvm"
  netisl="-netdev user,id=net0,restrict=yes -device virtio-net-pci,netdev=net0"
else
  echo
  echo "Zero Kelvin Linux mode"
  echo
  boxnme="-name zroklnx"
  qaccel="-accel tcg -cpu qemu64 -smp 1 -icount shift=0,sleep=off,align=off"
  qaccel="$qaccel -rtc base=2026-03-01,clock=vm,driftfix=none"
  cmdlnx="$cmdlnx deferred_probe_timeout=0 page_alloc.shuffle=0 memtest=0"
  cmdlnx="lpj=2000000 noapic nolapic clocksource=pit video=off nomodeset $cmdlnx"
  cmdlnx="$cmdlnx random.trust_cpu=off mitigations=off"
  netisl="-net none -serial mon:stdio -nodefaults"

  if [ "${ZWARM:-0}" = "1" ]; then
    qaccel="-cpu qemu64 -smp 1";
  fi
fi

cmdlnx="-append '$cmdlnx ${KARGS:-}'"

cmd="$qemubin -m ${QMSZE:-128M} -kernel ${kimg} -initrd ${rfsimg} ${nograp:-} \
              -no-reboot -boot order=dc ${boxnme:-} ${qaccel:-} ${netisl:-} \
              ${cmdlnx:-} ${QARGS:-}"

# Starting the QEMU configuraed virtual machine ################################

sh -xc "$cmd"; stty sane; printf '\e[?7h'
echo $cmd

