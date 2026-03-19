#!/bin/bash
# (c) 2026, Roberto A. Foglietta <roberto.foglietta@gmail.com>, MIT license

qemubin="qemu-system-x86_64"
append_for_kernel_debug="earlyprintk=serial nokaslr -pidfile vm.pid -panic=1"

# Cope with the user's parametric input

test -r bzImage || ln -sf bzImage.orig bzImage

docpio=1
update=0
tstimg=0

cmdlnx=
if [ "x${1:-}" = "x-z" ]; then
  export QZERO=1 QMSZE=256M UCTEST=${UCTEST:-0}
  cmdlnx="UCTEST=$UCTEST"
  shift
elif [ "x${1:-}" = "x-Z" ]; then
  export QZERO=1 QMSZE=256M UCTEST=${UCTEST:-1}
  cmdlnx="UCTEST=${UCTEST:-1}"
  shift
else
  test -n "$UCTEST" && cmdlnx="UCTEST=$UCTEST"
fi

if [ "x${1:-}" = "x-t" ]; then
  tstimg=1
  shift;
elif [ "x${1:-}" = "x-u" ]; then
  update=1
  tstimg=1
  shift;
fi

if [ "x${1:-}" = "x-T" ]; then
  docpio=0
  shift;
elif [ "x${1:-}" = "x-U" ]; then
  {
    echo | sh $0 -t; echo | sh $0 -t -r
    echo | sh $0 -u; echo | sh $0 -u -r
  } >/dev/null
  echo
  for f in update/initr*md5; do
    sed -e "s/.*uchaos.gz.sh$//" -e "s/.*RNG_.*static$//" -i $f
    echo "$f:"; cat $f | grep .
    echo
  done
  exit
fi

if [ "x${1:-}" = "x-r" ]; then
  rfsimg="initrobfs.cpio"
  shift; set -- "$rfsimg" "$@"
else
  rfsimg="${1:-initramfs.cpio}"
fi
test -r ${rfsimg}.gz && rfsimg="${rfsimg}.gz"

if [ -n "$UCTEST" -a "${2:-}" = "" ]; then
  kimg="bzImage.515x"
else
  kimg="${2:-bzImage}"
  
fi

if [ "$kimg" != "bzImage.515x" ]; then
  KARGS="quiet ${KARGS:-}"
fi

tmpdir=${3:-}
if [ ! -n "$tmpdir" ]; then
  tmpdir="cpio.tmp/"
  trap "rm -rf $tmpdir; return 1" EXIT INT TERM
  rm -rf $tmpdir
fi

# PractRand requires a quite large memory buffer to allocate
test "$kimg" = "bzImage.515x" && QMSZE=${QMSZE:-512M}

# Updating the image before start it

rfsdir=$(echo "$rfsimg" | sed 's/\.cpio\.gz//;s/\.cpio//')
chkmd5() { md5sum -c update/$rfsdir.md5 2>/dev/null; }

if [ -d update/$rfsdir/ ]; then
  printf "Checking is ramfs update "
  if ! chkmd5 || [ $docpio -ne 0 ]; then
    sh cpio.sh -e $rfsimg $tmpdir 2>&1 | grep -E "cpio: | blocks"
    cp -arf -pd update/common/* update/$rfsdir/* $tmpdir/ 2>&1
    sh cpio.sh -c $rfsimg.new $tmpdir 2>&1
    rfsimg="$rfsimg.new"
    if ! chkmd5; then
      echo "ERROR: ramfs updated doesn't match md5 checksum"
      echo "       press ENTER to start the QEMU VM anyway."
      test $update -eq 0 && read x
    fi
    rm -rf $tmpdir
  fi
fi

test -r $rfsimg.new && rfsimg="$rfsimg.new"

if [ $update -ne 0 ]; then
  md5sum $(find $rfsimg update/common/ update/$rfsdir/ ! -type d) > update/$rfsdir.md5
fi

test $tstimg -eq 0 || exit

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

