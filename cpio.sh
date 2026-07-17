#!/bin/sh
#
# (c) 2026, Roberto A. Foglietta <roberto.foglietta@gmail.com>, MIT license
#

action=${1:-}
cpiofl=${2:-initramfs.cpio.gz}
tmpdir=${3:-cpio.tmp}
vrtdir=${4:-virt/}

zcmd=$(command -v zstd pigz gzip | head -n1)

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
    printf "\n%5d KB $cpiofl\n" $(du -ks $cpiofl | cut -f1) 
    test -d $vrtdir && mv -f $cpiofl $vrtdir
  else
    echo
    echo "Usage: cpio.sh -e|-c|-d [file [dir]]"
    echo
  fi
  break
done
