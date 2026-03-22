#!/bin/sh
#
# (c) 2026, Roberto A. Foglietta <roberto.foglietta@gmail.com>, MIT license
#

action=${1:-}
cpiofl=${2:-initramfs.cpio.gz}
tmpdir=${3:-cpio.tmp}

zcmd="gzip"; which pigz >/dev/null && zcmd="pigz"

while true; do
  if [ "x$action" = "x-e" ]; then
      mkdir -p $tmpdir
      zcat $cpiofl | cpio -idmv -D $tmpdir
  elif [ "x$action" = "x-d" ]; then
      rm -rf $tmpdir
  elif [ "x$action" = "x-c" ]; then
      rm -f $cpiofl
      test -d $tmpdir || break
      cd $tmpdir
      chmod -c +x init bin/sh bin/*ybox
      find . -exec touch -h -t 202601010000 {} +
      find . -mindepth 1 -printf "%P\n" | sort | cpio -o -H newc \
        --reproducible --owner 0:0 | tee ../cpio.cpio | $zcmd -9nc > ../$cpiofl
      cd - >/dev/null
      du -ks $cpiofl | sed -e "s/\t/ KB /" -e "s/^/ /"
      test -d qemu/ && mv -f $cpiofl qemu/
  else
      echo
      echo "Usage: cpio.sh -e|-c|-d [file [dir]]"
      echo
  fi
  break
done
